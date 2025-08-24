import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:jwlife/core/utils/utils.dart';

class GZipOptimizer {

  // Cache pour éviter de re-parser les mêmes JSONs
  static final Map<String, Map<String, dynamic>> _jsonCache = {};

  // Décompression optimisée pour catalog.db (55MB → 204MB)
  static Future<void> decompressCatalogDb(List<int> gzipBytes, File file) async {
    try {
      // Décompression dans un isolate
      final Uint8List decompressed = await compute(_decompressInIsolate, gzipBytes);

      // Écriture optimisée sur le thread principal
      await file.writeAsBytes(decompressed, flush: true);

      printTime('Catalog.db décompressé avec succès');

    }
    catch (e) {
      printTime('Erreur optimisation avec compute: $e');
      // Fallback sur méthode standard
      await _fallbackDecompression(gzipBytes, file);
    }
  }

    // Fonction exécutée dans un isolate
  static Uint8List _decompressInIsolate(List<int> bytes) {
    final archive = GZipDecoder().decodeBytes(bytes, verify: true);
    return Uint8List.fromList(archive);
  }

  // Décompression JSON simple (retourne le JSON complet)
  static Future<Map<String, dynamic>> decompressJSONResponse(List<int> gzipBytes) async {
    final stopwatch = Stopwatch()..start();
    final sizeInMB = (gzipBytes.length / 1024 / 1024);

    // Vérifier le cache d'abord
    final key = _generateCacheKey(gzipBytes);
    if (_jsonCache.containsKey(key)) {
      return _jsonCache[key]!;
    }

    try {
      Map<String, dynamic> result;

      if (sizeInMB < 2) {
        // Petits JSONs : traitement synchrone ultra-rapide
        result = _fastSyncJSONDecompression(gzipBytes);
      } else {
        // JSONs moyens/gros : optimisation avec isolate
        result = await _optimizedAsyncJSONDecompression(gzipBytes);
      }

      // Mise en cache des JSONs < 20MB décompressés
      final jsonSize = _estimateJsonSize(result);
      if (jsonSize < 20 * 1024 * 1024) {
        _jsonCache[key] = result;
        printTime('JSON mis en cache');
      }

      final totalTime = stopwatch.elapsedMilliseconds;
      printTime('JSON décompressé en ${totalTime}ms');

      return result;

    } catch (e) {
      printTime('Erreur décompression JSON: $e');
      rethrow;
    }
  }

  // Benchmark pour catalog.db
  static Future<void> benchmarkDecompression(List<int> gzipBytes, File file) async {
    printTime('=== BENCHMARK DECOMPRESSION ===');
    printTime('Taille fichier compressé: ${gzipBytes.length} bytes (${(gzipBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

    // Test 1: Décompression seule
    final stopwatch1 = Stopwatch()..start();
    final decompressed = GZipDecoder().decodeBytes(gzipBytes);
    stopwatch1.stop();

    printTime('Test 1 - Décompression seule: ${stopwatch1.elapsedMilliseconds}ms');
    printTime('Taille décompressée: ${decompressed.length} bytes (${(decompressed.length / 1024 / 1024).toStringAsFixed(2)} MB)');
    printTime('Ratio compression: ${(gzipBytes.length / decompressed.length * 100).toStringAsFixed(1)}%');

    // Test 2: Écriture seule
    final stopwatch2 = Stopwatch()..start();
    await file.writeAsBytes(decompressed);
    stopwatch2.stop();

    printTime('Test 2 - Écriture seule: ${stopwatch2.elapsedMilliseconds}ms');

    // Test 3: Décompression + écriture en isolate
    final stopwatch3 = Stopwatch()..start();
    final decompressed2 = await compute(_isolateDecompress, gzipBytes);
    await file.writeAsBytes(decompressed2);
    stopwatch3.stop();

    printTime('Test 3 - Isolate + écriture: ${stopwatch3.elapsedMilliseconds}ms');

    printTime('=== FIN BENCHMARK ===');
  }

  // === FONCTIONS PRIVÉES CATALOG.DB ===

  // Version optimisée main thread (plus rapide que isolate pour ce cas)
  static Future<void> _fastMainThreadDecompression(List<int> gzipBytes, File file) async {
    // Décompression directe (plus rapide que isolate : 927ms vs 1294ms)
    final decoder = GZipDecoder();
    final decompressed = decoder.decodeBytes(gzipBytes);

    // Écriture ultra-optimisée avec pré-allocation
    final writeStopwatch = Stopwatch()..start();
    await _ultraFastWrite(file, decompressed);
  }

  // Écriture ultra-optimisée avec buffer pré-alloué
  static Future<void> _ultraFastWrite(File file, List<int> data) async {
    final sink = file.openWrite();

    try {
      // Écriture par gros chunks pour minimiser les appels système
      const chunkSize = 2 * 1024 * 1024; // 2MB chunks (optimal pour 204MB)

      for (int i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;

        // Utilisation de sublist view (pas de copie)
        final chunk = Uint8List.sublistView(data as Uint8List, i, end);
        sink.add(chunk);

        // Pause micro uniquement tous les 10MB pour ne pas ralentir
        if (i % (chunkSize * 5) == 0 && i > 0) {
          await Future.delayed(Duration.zero);
        }
      }

      await sink.flush(); // Force l'écriture
    } finally {
      await sink.close();
    }
  }

  static List<int> _isolateDecompress(List<int> gzipBytes) {
    final stopwatch = Stopwatch()..start();
    final result = GZipDecoder().decodeBytes(gzipBytes);
    print('Isolate décompression: ${stopwatch.elapsedMilliseconds}ms');
    return result;
  }

  // Fallback si problème
  static Future<void> _fallbackDecompression(List<int> gzipBytes, File file) async {
    printTime('Utilisation méthode fallback');
    final decompressed = await compute(_isolateDecompress, gzipBytes);
    await file.writeAsBytes(decompressed);
  }

  // === FONCTIONS PRIVÉES JSON ===

  // Décompression synchrone ultra-rapide pour petits fichiers
  static Map<String, dynamic> _fastSyncJSONDecompression(List<int> gzipBytes) {
    final stopwatch = Stopwatch()..start();

    // Décompression directe
    final decompressed = GZipDecoder().decodeBytes(gzipBytes);
    final decompressTime = stopwatch.elapsedMilliseconds;

    // Parsing JSON optimisé
    stopwatch.reset();
    final jsonString = utf8.decode(decompressed);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    final parseTime = stopwatch.elapsedMilliseconds;
    print('Sync - Décompression: ${decompressTime}ms, Parse: ${parseTime}ms');

    return json;
  }

  // Décompression asynchrone optimisée pour JSONs moyens
  static Future<Map<String, dynamic>> _optimizedAsyncJSONDecompression(List<int> gzipBytes) async {
    final stopwatch = Stopwatch()..start();

    // Décompression avec compute pour ne pas bloquer l'UI
    final result = await compute(_isolateJSONDecompression, gzipBytes);

    final totalTime = stopwatch.elapsedMilliseconds;
    print('Async optimisé: ${totalTime}ms');

    return result;
  }

  // Fonction isolate optimisée pour JSON
  static Map<String, dynamic> _isolateJSONDecompression(List<int> gzipBytes) {
    final stopwatch = Stopwatch()..start();

    try {
      // Décompression
      final decompressed = GZipDecoder().decodeBytes(gzipBytes);
      final decompressTime = stopwatch.elapsedMilliseconds;

      // Parsing JSON avec gestion optimisée de la mémoire
      stopwatch.reset();
      final jsonString = utf8.decode(decompressed, allowMalformed: false);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final parseTime = stopwatch.elapsedMilliseconds;

      print('Isolate - Décompression: ${decompressTime}ms, Parse: ${parseTime}ms');
      return json;

    } catch (e) {
      print('Erreur isolate JSON: $e');
      rethrow;
    }
  }

  // === UTILITAIRES ===

  // Génération de clé de cache
  static String _generateCacheKey(List<int> gzipBytes) {
    final size = gzipBytes.length;
    final start = gzipBytes.take(8).join('');
    final end = gzipBytes.skip(size - 8).join('');
    return '${size}_${start}_$end';
  }

  // Estimation taille JSON
  static int _estimateJsonSize(Map<String, dynamic> json) {
    final jsonString = jsonEncode(json);
    return utf8.encode(jsonString).length;
  }

  // Pré-chauffage du décodeur (une seule fois au démarrage app)
  static void warmupDecoder() {
    final testData = GZipEncoder().encode([1, 2, 3, 4, 5]);
    GZipDecoder().decodeBytes(testData);
    printTime('Décodeur GZip pré-chauffé');
  }

  // Nettoyage du cache
  static void clearCache() {
    _jsonCache.clear();
    printTime('Cache JSON vidé');
  }

  // Information sur le cache
  static void printCacheInfo() {
    final count = _jsonCache.length;
    var totalSize = 0;

    for (final json in _jsonCache.values) {
      totalSize += _estimateJsonSize(json);
    }

    printTime('Cache JSON: $count entrées, ~${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB');
  }
}
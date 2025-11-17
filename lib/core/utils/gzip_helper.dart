import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Classe utilitaire simple pour décompresser des fichiers ou des réponses GZip.
class GZipHelper {
  /// Décompresse un fichier GZip et écrit le contenu dans [outputFile].
  static Future<void> decompressToFile(Uint8List gzipBytes, File outputFile) async {
    try {
      final decompressedData = GZipDecoder().decodeBytes(gzipBytes);
      await outputFile.writeAsBytes(decompressedData, flush: true);
      print('✅ Fichier décompressé : ${outputFile.path}');
    } catch (e) {
      print('❌ Erreur lors de la décompression : $e');
      rethrow;
    }
  }

  /// Décompresse une réponse GZip contenant du JSON et renvoie le contenu sous forme de Map.
  static Future<Map<String, dynamic>> decompressJson(List<int> gzipBytes) async {
    try {
      final decompressedData = GZipDecoder().decodeBytes(gzipBytes);
      final jsonString = utf8.decode(decompressedData);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Erreur lors de la décompression JSON : $e');
      rethrow;
    }
  }

  /// Décompresse simplement et retourne les octets non compressés.
  static Uint8List decompressToBytes(List<int> gzipBytes) {
    try {
      final data = GZipDecoder().decodeBytes(gzipBytes);
      return Uint8List.fromList(data);
    } catch (e) {
      print('❌ Erreur de décompression : $e');
      rethrow;
    }
  }
}

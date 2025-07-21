import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:flutter/foundation.dart';
import 'package:jwlife/core/utils/utils.dart';

List<int> decompressGZip(List<int> gzipBytes) {
  return GZipDecoder().decodeBytes(gzipBytes);
}

Future<void> decompressGZipDb(List<int> gzipBytes, File file) async {
  final decompressed = await compute(decompressGZip, gzipBytes);
  await file.writeAsBytes(decompressed);
}

Future<Map<String, dynamic>> decompressJSONGZip(List<int> gzipBytes) async {
  // Décompresser le fichier
  final decompressedBytes = GZipDecoder().decodeBytes(gzipBytes);

  // Convertir les octets en chaîne de caractères JSON
  final jsonString = utf8.decode(decompressedBytes);

  // Parser le JSON en Map<String, dynamic>
  final jsonData = jsonDecode(jsonString);

  printTime('Extraction et parsing JSON terminés');
  return jsonData;
}

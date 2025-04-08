import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

Future<void> decompressGZipDb(List<int> gzipBytes, File file) async {
  // Décompresser le fichier
  final decompressed = GZipDecoder().decodeBytes(gzipBytes);

  // Sauvegarder le fichier extrait
  file.writeAsBytesSync(decompressed);
}

Future<Map<String, dynamic>> decompressJSONGZip(List<int> gzipBytes) async {
  // Décompresser le fichier
  final decompressedBytes = GZipDecoder().decodeBytes(gzipBytes);

  // Convertir les octets en chaîne de caractères JSON
  final jsonString = utf8.decode(decompressedBytes);

  // Parser le JSON en Map<String, dynamic>
  final jsonData = jsonDecode(jsonString);

  print('Extraction et parsing JSON terminés');
  return jsonData;
}

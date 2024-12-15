import 'dart:convert';
import 'dart:io';

decompressGZipDb(List<int> gzipBytes, File file) async {
  try {
    // Decode gzip content
    final decodedData = GZipCodec().decode(gzipBytes);
    file.writeAsBytes(decodedData);
  } catch (e) {
    print('Error decompressing gzip: $e');
    return null;
  }
}

Future<String?> decompressGZip(List<int> gzipBytes) async {
  try {
    // Decode gzip content
    final decodedData = GZipCodec().decode(gzipBytes);

    // Convert decoded bytes to string
    return utf8.decode(decodedData, allowMalformed: true);
  }
  catch (e) {
    print('Error decompressing gzip: $e');
    return null;
  }
}

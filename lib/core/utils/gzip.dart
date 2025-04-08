import 'dart:convert';
import 'dart:io';

Future<File?> decompressGZipDb(List<int> gzipBytes, File file) async {
  try {
    return await file.writeAsBytes(GZipCodec().decode(gzipBytes));
  }
  catch (e) {
    print('Error decompressing gzip: $e');
    return null;
  }
}

Future<String?> decompressGZip(List<int> gzipBytes) async {
  try {
    // Convert decoded bytes to string
    return utf8.decode(GZipCodec().decode(gzipBytes), allowMalformed: true);
  }
  catch (e) {
    print('Error decompressing gzip: $e');
    return null;
  }
}

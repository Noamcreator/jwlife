import 'dart:convert';
import 'dart:io';

Future<void> downloadFileFromUrlToFile(String body, File file) async {
  var bytes = utf8.encode(body);
  await file.writeAsBytes(bytes);
}
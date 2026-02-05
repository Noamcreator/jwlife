import 'dart:convert';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/services/settings_service.dart';

Future<Map<String, dynamic>> fetchTranslation(String text, {String? sourceLang, String? targetLang}) async {
  targetLang ??= JwLifeSettings.instance.libraryLanguage.value.primaryIetfCode;
  
  // Si sourceLang est 'auto', on ne passe pas de paramètre sl
  String urlStr = 'https://ftapi.pythonanywhere.com/translate?dl=$targetLang&text=${Uri.encodeComponent(text)}';
  if (sourceLang != 'auto') {
    urlStr += '&sl=$sourceLang';
  }
  
  final response = await http.get(Uri.parse(urlStr));
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Erreur de réseau');
  }
}

Future<String> translateHtml(String htmlInput, String sourceLang, String targetLang) async {
  var document = parse(htmlInput);
  var pidElements = document.querySelectorAll('[data-pid]');
  
  // Extraire tous les innerHtml
  List<String> htmlToTranslate = [];
  for (var element in pidElements) {
    String innerHtml = element.innerHtml.trim();
    if (innerHtml.isNotEmpty) {
      htmlToTranslate.add(innerHtml);
    }
  }
  
  String separator = '|||JWSEP|||';
  int maxLength = 4000; // Limite de caractères par requête
  List<String> allTranslated = [];
  List<String> batch = [];
  int currentLength = 0;
  
  // Grouper en batches
  for (var html in htmlToTranslate) {
    int htmlLength = html.length + separator.length;
    
    if (currentLength + htmlLength > maxLength && batch.isNotEmpty) {
      // Traduire le batch actuel
      String combinedHtml = batch.join(separator);
      var result = await fetchTranslation(
        combinedHtml, 
        sourceLang: sourceLang, 
        targetLang: targetLang
      );
      String translatedHtml = result['destination-text'] ?? '';
      allTranslated.addAll(translatedHtml.split(separator));
      
      // Réinitialiser
      batch = [html];
      currentLength = htmlLength;
    } else {
      batch.add(html);
      currentLength += htmlLength;
    }
  }
  
  // Traduire le dernier batch
  if (batch.isNotEmpty) {
    String combinedHtml = batch.join(separator);
    var result = await fetchTranslation(
      combinedHtml, 
      sourceLang: sourceLang, 
      targetLang: targetLang
    );
    String translatedHtml = result['destination-text'] ?? '';
    allTranslated.addAll(translatedHtml.split(separator));
  }
  
  // Remplacer les innerHtml
  int index = 0;
  for (var element in pidElements) {
    if (element.innerHtml.trim().isNotEmpty && index < allTranslated.length) {
      element.innerHtml = allTranslated[index].trim();
      index++;
    }
  }
  
  return document.outerHtml;
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/utils/shared_preferences_helper.dart';
import 'package:jwlife/widgets/WebViewData.dart';

import '../jwlife.dart';

String createHtmlBaseContent(BuildContext context) {
  final backgroundColor = Theme.of(context).brightness == Brightness.dark ? '#111111' : '#ffffff';

  return '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden;">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="initial-scale=1.0, user-scalable=no, maximum-scale=1.0, minimum-scale=1.0">
    </head>
    <body>
    <style> 
    body {
       font-size: 24px;
       background-color: $backgroundColor;
    }
    </style>
    </body>
    </html>
    ''';
}

Future<String> createHtmlContent(String html, String articleClasses) async {
  WebViewData webViewData = JwLifeApp.webviewData;
  final fontSize = await getFontSize();

  String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden;">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="initial-scale=1.0, user-scalable=no, maximum-scale=1.0, minimum-scale=1.0">
    </head>
    <body>
    <style>
    ${webViewData.cssCode}
    body {
       font-size: ${fontSize}px;
       background-color: ${webViewData.backgroundColor};
       padding-bottom: 50px;
    }
    </style>
    <div class="$articleClasses ${webViewData.theme}">
    $html
    </div>
    </body>
    </html>
    ''';

  return htmlContent;
}

Future<void> showFontSizeDialog(BuildContext context, InAppWebViewController controller) async {
  double fontSize = await getFontSize();
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder( // Utilisation de StatefulBuilder pour mettre à jour l'interface en temps réel
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text('Taille de la police'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: fontSize,
                  min: 11.0,
                  max: 28.0,
                  divisions: 17,
                  label: "${fontSize.toInt()} px",
                  onChanged: (value) {
                    setState(() {
                      fontSize = value;
                    });

                    // Mise à jour en temps réel dans la WebView
                    controller.evaluateJavascript(source: "document.body.style.fontSize = '${fontSize}px';");
                    setFontSize(fontSize);
                    //_controller.injectCSSCode(source: "body {font-size: ${fontSize}px !important;}");
                  },
                ),
                Text(
                  'Taille : ${fontSize.toInt()} px',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Annuler'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Fermer'),
                onPressed: () {
                  Navigator.of(context).pop(fontSize); // Retourne la taille si nécessaire
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> updateFieldValue(dynamic updatedField, dynamic publication, int docId) async {
  try {
    // Extraire le tag et la valeur
    final String tag = updatedField['tag']?.toString() ?? '';
    final String value = updatedField['value']?.toString() ?? '';

    // Appel à la mise à jour ou insertion
    await JwLifeApp.userdata.updateOrInsertInputField(publication, tag, docId, value);
  }
  catch (e, stacktrace) {
    // Log l'erreur pour le debug
    print('Error in _updateFieldValue: $e');
    print('Stacktrace: $stacktrace');
  }
}
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/modules/library/views/publication/local/page_local_document.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/jwlife_app.dart';

void showDocumentView(BuildContext context, int mepsDocId) async {
  File pubCollectionsDbFile = await getPubCollectionsFile();
  final db = await openDatabase(pubCollectionsDbFile.path, readOnly: true, version: 1);
  List<Map<String, dynamic>> result = await db.rawQuery('''
  SELECT DISTINCT *
  FROM Publication
  JOIN Document ON Publication.PublicationId = Document.PublicationId
  WHERE MepsDocumentId = ? AND LanguageIndex = ?
  ''', [mepsDocId, JwLifeApp.currentLanguage.id]);

  await db.close();

  if (result.isNotEmpty) {
    showPage(context, PageLocalDocumentView(publication: result.first, mepsDocumentId: mepsDocId));
  }
  else {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
      //showPage(context, PublicationMenu(publication: publication));
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

Future<String> createHtmlContent(String html, String articleClasses) async {
  WebViewData webViewData = JwLifeApp.webviewData;
  final fontSize = await getFontSize();

  String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
      </head>
      <body class="$articleClasses ${webViewData.theme}">
        <style>
          body {
            font-size: ${fontSize}px;
            background-color: ${webViewData.backgroundColor};
            -webkit-user-select: none;
            user-select: none;
            -webkit-touch-callout: none;
            -webkit-tap-highlight-color: rgba(0, 0, 0, 0);
            -webkit-overflow-scrolling: touch;
            -webkit-font-smoothing: antialiased;
          }

          .content-wrapper {
            padding-top: 90px;
            padding-bottom: 50px;
          }
          
          textarea {
            box-sizing: content-box; /* Important pour éviter les conflits */
            overflow: hidden; /* Cache les barres de défilement */
            resize: none; /* Empêche le redimensionnement manuel */
            min-height: 1.5em; /* Hauteur correspondant à une seule ligne (ajustez selon vos besoins) */
            line-height: 1.5; /* Hauteur de ligne pour correspondre visuellement */
            padding: 0.5em; /* Pour éviter que le texte colle aux bords */
          }
          
          .noscroll { 
            overflow: hidden; 
          }
          
          /* Définir les classes de surlignage */
.highlight-yellow {
  background-color: #86761d;
}

.highlight-green {
  background-color: #4a6831;
}

.highlight-blue {
  background-color: #3a6381;
}

.highlight-purple {
  background-color: #524169;
}

.highlight-pink {
  background-color: #783750;
}

.highlight-orange {
  background-color: #894c1f;
}

.highlight-transparent {
  background-color: transparent;
}
        </style>
        <div class="content-wrapper">
          $html
        </div>
      </body>
    </html>
  ''';

  return htmlContent;
}

Future<String> createHtmlVerseContent(String html, String articleClasses) async {
  WebViewData webViewData = JwLifeApp.webviewData;
  final fontSize = await getFontSize();

  String htmlContent = '''
    <!DOCTYPE html>
    <html style="overflow-x: hidden; height: 100%;">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="jw-styles.css" />
      </head>
      <body class="$articleClasses ${webViewData.theme}">
        <style>
          body {
            font-size: ${fontSize}px;
            background-color: ${webViewData.backgroundColor};
          }
        </style>
        <div>
          $html
        </div>
      </body>
    </html>
  ''';

  return htmlContent;
}

Future<void> showFontSizeDialog(BuildContext context, InAppWebViewController? controller) async {
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
                    controller!.evaluateJavascript(source: "document.body.style.fontSize = '${fontSize}px';");
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
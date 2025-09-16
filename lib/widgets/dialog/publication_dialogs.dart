import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_media.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/api/api.dart';
import '../../core/utils/utils_video.dart';
import '../../data/models/media.dart';
import '../../data/models/video.dart';

// Fonction pour afficher le dialogue de téléchargement
Future<String?> showVideoDialog(BuildContext context, Video video) async {
  File mediaCollectionFile = await getMediaCollectionsDatabaseFile();
  Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);

  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

  if (video.isDownloadedNotifier.value) {
    return _showLocalVideoDialog(context, video, connectivityResult);
  }
  else {
    if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${video.mepsLanguage}/${video.naturalKey}';
      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return _showOnlineVideoDialog(context, video, data);
        }
        else {
          printTime('Loading error: ${response.statusCode}');
        }
      }
      catch (e) {
        printTime('An exception occurred: $e');
      }
    }
    else {
      showNoConnectionDialog(context);
    }
  }
  return null; // Retourne null en cas d'échec
}

Future<String?> _showLocalVideoDialog(BuildContext context, Video video, List<ConnectivityResult> connectivityResult) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8, // Largeur personnalisée
          padding: EdgeInsets.all(20.0), // Ajouter un padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Pour ne pas remplir tout l'espace
            children: [
              Text(
                "VIDÉO: ${video.title}",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  ImageCachedWidget(
                      imageUrl: video.networkImageSqr,
                      pathNoImage: 'pub_type_video',
                      width: 100,
                      height: 100
                  ),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Durée: ${formatDuration(video.duration)}"),
                      Text("Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(video.lastModified!))}"),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Fermer le dialogue sans valeur
                    },
                    child: Text('ANNULER'),
                  ),
                  if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet))
                    TextButton(
                      onPressed: () async {
                        /*
                        final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${video.mepsLanguage}/${video.naturalKey}';
                        try {
                          final response = await http.get(Uri.parse(apiUrl));

                          if (response.statusCode == 200) {
                            final data = json.decode(response.body);
                            showVideoDownloadDialog(context, data['media'][0]['files']).then((value) {
                              if (value != null) {
                                downloadMedia(context, video, data['media'][0], file: value);
                              }
                            });
                          }
                          else {
                            printTime('Loading error: ${response.statusCode}');
                          }
                        }
                        catch (e) {
                          printTime('An exception occurred: $e');
                        }

                         */
                      },
                      child: Text('TÉLÉCHARGER'),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop('play'); // Retourner 'play'
                    },
                    child: Text('LIRE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> _showOnlineVideoDialog(BuildContext context, Video video, dynamic data) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8, // Largeur personnalisée
          padding: EdgeInsets.all(18.0), // Ajouter un padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Pour ne pas remplir tout l'espace
            children: [
              Text(
                "VIDÉO: " + data['media'][0]['title'],
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Durée: " + data['media'][0]['durationFormattedMinSec']),
                  Text("Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data['media'][0]['firstPublished']))}"),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Fermer le dialogue sans valeur
                    },
                    child: Text(
                      'ANNULER',
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      /*
                      showVideoDownloadDialog(context, data['media'][0]['files']).then((value) {
                        if (value != null) {
                          downloadMedia(context, video, data['media'][0], file: value);
                        }
                      });

                       */
                    },
                    child: Text(
                      'TÉLÉCHARGER',
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop('play'); // Retourner 'play'
                    },
                    child: Text(
                      'LIRE',
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Fonction pour afficher le dialogue de téléchargement
Future<String?> showDocumentDialog(BuildContext context, String? pub, String? docId, String? track, String langwritten, String fileformat) async {
  final connectivityResult = await (Connectivity().checkConnectivity());

  final queryParams = <String, String>{
    if (pub != null) 'pub': pub,
    if (docId != null) 'docid': docId,
    'fileformat': fileformat,
    if (track != null) 'track': track,
    'langwritten': langwritten,
    'output': 'json',
    'alllangs': '0',
  };

  printTime("queryParams: $queryParams");

  // Construire l'URL avec Uri.https
  final url = Uri.https('b.jw-cdn.org', '/apis/pub-media/GETPUBMEDIALINKS', queryParams);

  printTime("url: $url");

  try {
    // Effectuer la requête HTTP
    final response = await Api.httpGetWithHeadersUri(url);

    // Vérifier si la requête a réussi (code 200)
    if (response.statusCode == 200) {
      // Si la requête est réussie, analyser le JSON
      final jsonData = jsonDecode(response.body);

      _showPdfDialog(context, connectivityResult, jsonData, langwritten);
    }
    else {
      // Si la requête échoue, afficher un message d'erreur
      printTime("Erreur lors de la récupération des données: ${response.statusCode}");
    }
  }
  catch (e) {
    // Gérer les erreurs liées à la requête HTTP
    printTime("Erreur de connexion ou de requête: $e");
    // Vous pouvez afficher un message d'erreur ou de débogage
  }

  return '';
}

Future<String?> _showPdfDialog(BuildContext context, List<ConnectivityResult> connectivityResult, dynamic jsonData, String langwritten) async {
  dynamic file = jsonData['files'][langwritten]['PDF'][0];

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8, // Largeur personnalisée
          padding: EdgeInsets.all(20.0), // Ajouter un padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Pour ne pas remplir tout l'espace
            children: [
              Text(
                file['title'],
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Afficher les informations importantes ici
                      Text("Nom du fichier: ${file['file']['url'].split('/').last ?? ''}"),
                      Text("Taille: ${formatFileSize(file['filesize'])}"),
                      Text("Format(s): ${jsonData['fileformat'].join(', ')}"),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Fermer le dialogue sans valeur
                    },
                    child: Text('ANNULER'),
                  ),
                  if (connectivityResult.contains(ConnectivityResult.wifi) ||
                      connectivityResult.contains(ConnectivityResult.mobile) ||
                      connectivityResult.contains(ConnectivityResult.ethernet))
                    TextButton(
                      onPressed: () async {
                        await _downloadAndOpenPdf(file['file']['url']);
                      },
                      child: Text('TÉLÉCHARGER'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _downloadAndOpenPdf(String fileUrl) async {
  printTime('fileUrl: $fileUrl');
  try {
    // Utiliser Dio pour télécharger le fichier PDF
    Directory downloadDir = await getExternalStorageDirectory() ?? Directory('/storage/emulated/0/Download');
    String filePath = '${downloadDir.path}/${fileUrl.split('/').last}';

    // Télécharger le fichier
    await Api.dio.download(fileUrl, filePath);

    // Ouvrir le fichier après le téléchargement
    OpenFile.open(filePath);
  }
  catch (e) {
    printTime("Erreur lors du téléchargement ou de l'ouverture du fichier: $e");
  }
}

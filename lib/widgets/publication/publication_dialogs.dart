import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_media.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:realm/realm.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Fonction pour afficher le dialogue de téléchargement
Future<String?> showVideoDialog(BuildContext context, String lank, String wtlocale) async {
  File mediaCollectionFile = await getMediaCollectionsFile();
  Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);

  MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("languageAgnosticNaturalKey == '$lank'").query("languageSymbol == '$wtlocale'").first;

  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

  dynamic media = await getMediaIfDownload(db, mediaItem);

  if (media != null) {
    return _showLocalVideoDialog(context, mediaItem, connectivityResult);
  }
  else {
    if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$wtlocale/$lank';
      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return _showOnlineVideoDialog(context, mediaItem, data);
        }
        else {
          print('Loading error: ${response.statusCode}');
        }
      }
      catch (e) {
        print('An exception occurred: $e');
      }
    }
    else {
      showNoConnectionDialog(context);
    }
  }
  return null; // Retourne null en cas d'échec
}

Future<String?> _showLocalVideoDialog(BuildContext context, MediaItem mediaItem, List<ConnectivityResult> connectivityResult) {
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
                "VIDÉO: ${mediaItem.title!}",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  ImageCachedWidget(
                      imageUrl: mediaItem.realmImages!.squareImageUrl!,
                      pathNoImage: 'pub_type_video',
                      width: 100,
                      height: 100
                  ),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Durée: ${formatDuration(mediaItem.duration!)}"),
                      Text("Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(mediaItem.firstPublished!))}"),
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
                        final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${mediaItem.languageSymbol}/${mediaItem.languageAgnosticNaturalKey}';
                        try {
                          final response = await http.get(Uri.parse(apiUrl));

                          if (response.statusCode == 200) {
                            final data = json.decode(response.body);
                            showVideoDownloadDialog(context, data['media'][0]['files']).then((value) {
                              if (value != null) {
                                downloadVideoFile(mediaItem, data['media'][0], value, context);
                              }
                            });
                          }
                          else {
                            print('Loading error: ${response.statusCode}');
                          }
                        }
                        catch (e) {
                          print('An exception occurred: $e');
                        }
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

Future<String?> _showOnlineVideoDialog(BuildContext context, MediaItem mediaItem, dynamic data) {
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
                "VIDÉO: " + data['media'][0]['title'],
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  ImageCachedWidget(
                    imageUrl: data['media'][0]['images']['sqr']['md'],
                    pathNoImage: 'pub_type_video',
                    width: 100,
                    height: 100
                  ),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Durée: " + data['media'][0]['durationFormattedMinSec']),
                      Text("Date: " + DateFormat('dd/MM/yyyy').format(DateTime.parse(data['media'][0]['firstPublished']))),
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
                  TextButton(
                    onPressed: () {
                      showVideoDownloadDialog(context, data['media'][0]['files']).then((value) {
                        if (value != null) {
                          downloadVideoFile(mediaItem, data['media'][0], value, context);
                        }
                      });
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

// Fonction pour afficher le dialogue de téléchargement
Future<String?> showDocumentDialog(BuildContext context, String docId, String track, String langwritten, String fileformat) async {
  final connectivityResult = await (Connectivity().checkConnectivity());

  // Définir les paramètres de requête
  final queryParams = {
    'docid': docId,  // Ajoutez le docId
    'output': 'json',
    'fileformat': fileformat,  // Utilisation du paramètre fileformat
    'alllangs': '0',
    'track': track,  // Ajoutez le track
    'langwritten': langwritten,  // Utiliser langwritten (maintenant défini)
  };

  print("queryParams: $queryParams");

  // Construire l'URL avec Uri.https
  final url = Uri.https('b.jw-cdn.org', '/apis/pub-media/GETPUBMEDIALINKS', queryParams);

  print("url: $url");

  try {
    // Effectuer la requête HTTP
    final response = await http.get(url);

    // Vérifier si la requête a réussi (code 200)
    if (response.statusCode == 200) {
      // Si la requête est réussie, analyser le JSON
      final jsonData = jsonDecode(response.body);

      _showPdfDialog(context, connectivityResult, jsonData, langwritten);
    }
    else {
      // Si la requête échoue, afficher un message d'erreur
      print("Erreur lors de la récupération des données: ${response.statusCode}");
      // Vous pouvez également afficher un message d'erreur dans l'interface utilisateur
    }
  }
  catch (e) {
    // Gérer les erreurs liées à la requête HTTP
    print("Erreur de connexion ou de requête: $e");
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
                "Document",
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
                      Text("Nom: ${file['title'] ?? ''}"),
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
  print('fileUrl: $fileUrl');
  try {
    // Utiliser Dio pour télécharger le fichier PDF
    Dio dio = Dio();
    Directory downloadDir = await getExternalStorageDirectory() ?? Directory('/storage/emulated/0/Download');
    String filePath = '${downloadDir.path}/${fileUrl.split('/').last}';

    // Télécharger le fichier
    await dio.download(fileUrl, filePath);

    // Ouvrir le fichier après le téléchargement
    OpenFile.open(filePath);
  }
  catch (e) {
    print("Erreur lors du téléchargement ou de l'ouverture du fichier: $e");
  }
}

// Fonction pour afficher le dialogue de téléchargement
Future<int?> showVideoDownloadDialog(BuildContext context, List<dynamic> files) async {
  // Trier les fichiers par taille décroissante
  files.sort((a, b) => b['filesize'].compareTo(a['filesize']));

  return showDialog<int>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8, // Largeur personnalisée
          padding: EdgeInsets.all(20.0), // Ajouter un padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Pour ne pas remplir tout l'espace
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Résolution",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: files.map<Widget>((file) {
                  // Convertir la taille en Mo ou Go
                  double fileSize = file['filesize'] / (1024 * 1024); // Taille en Mo
                  String sizeText = fileSize < 1024
                      ? "${fileSize.toStringAsFixed(2)} Mo"
                      : "${(fileSize / 1024).toStringAsFixed(2)} Go"; // Si la taille est plus grande que 1 Go

                  return ListTile(
                    title: Text("Télécharger ${file['label']} ($sizeText)"),
                    onTap: () {
                      // Gérer le téléchargement ici
                      print("Télécharger: ${file['progressiveDownloadURL']}");

                      Navigator.of(context).pop(files.indexOf(file)); // Retourner l'index du fichier sélectionné
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Fermer le dialogue et retourner -1 en cas d'annulation
                  },
                  child: Text('ANNULER'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

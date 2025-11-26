import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api.dart';
import '../../data/models/video.dart';
import '../../i18n/i18n.dart';

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
                      icon: JwIcons.video,
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
                "VIDÉO: ${data['media'][0]['title']}",
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Durée: ${data['media'][0]['durationFormattedMinSec']}"),
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
    final response = await Api.httpGetWithHeadersUri(url, responseType: ResponseType.json);

    // Vérifier si la requête a réussi (code 200)
    if (response.statusCode == 200) {
      _showPdfDialog(context, connectivityResult, response.data, langwritten);
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

  return showJwDialog<String>(
    context: context,
    titleText: file['title'],
    content: Padding(
      padding: EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Afficher les informations importantes ici
          Text("Nom du fichier: ${file['file']['url'].split('/').last ?? ''}"),
          Text("Taille: ${formatFileSize(file['filesize'])}"),
          Text("Format(s): ${jsonData['fileformat'].join(', ')}"),
        ],
      ),
    ),
    buttons: [
      JwDialogButton(label: i18n().action_cancel_uppercase),
      JwDialogButton(
          label: i18n().label_downloaded_uppercase,
          closeDialog: false,
          onPressed: (context) async {
            await _downloadAndOpenPdf(file['file']['url']);
          })
      ]
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

/// Affiche le dialogue pour personnaliser et réordonner les versions de la Bible.
Future<bool> showCustomizeVersesDialog(BuildContext context) async {
  List<Publication> allBibles = PublicationRepository().getAllBibles();
  List<Publication> initialOrderedBibles = PublicationRepository().getOrderBibles();

  // On crée une copie immédiate des clés initiales pour la comparaison finale.
  final List<String> initialKeys = initialOrderedBibles.map((p) => p.getKey()).toList();

  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  final result = await showDialog<List<Publication>>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          // currentOrderedBibles est l'état courant DANS le dialogue.
          // Il est initialisé avec la version la plus récente de initialOrderedBibles,
          // qui est mise à jour après chaque action dans le dialogue (ajout/suppression/réordre)
          // pour maintenir la persistance de l'état au sein du StatefulBuilder.
          List<Publication> currentOrderedBibles = List.from(initialOrderedBibles);
          Set<String> orderedBibleCodes = currentOrderedBibles.map((p) => p.getKey()).toSet();

          // Liste des autres bibles disponibles, non encore dans la liste ordonnée
          List<Publication> otherBibles = allBibles
              .where((p) => !orderedBibleCodes.contains(p.getKey()))
              .toList()
            ..sort((a, b) {
              int langCompare = a.mepsLanguage.symbol.compareTo(b.mepsLanguage.symbol);
              if (langCompare != 0) return langCompare;
              return a.shortTitle.compareTo(b.shortTitle); // Changement de 'symbol' à 'shortTitle' pour la version
            });

          // CORRECTION 1 : La fonction retourne la liste des widgets (ListTile) pour la section AUTRES
          List<Widget> buildOtherBiblesList() {
            return otherBibles.map((bible) {
              return ListTile(
                key: ValueKey(bible.getKey()),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10), // Ajouté pour uniformité avec ReorderableListView
                leading: const CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.green,
                  child: Icon(JwIcons.plus, color: Colors.white, size: 20),
                ),
                title: Text(
                  bible.mepsLanguage.vernacular,
                  style: const TextStyle(fontSize: 15),
                ),
                subtitle: Text(
                  bible.shortTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? Color(0xFFc0c0c0)
                        : Color(0xFF5a5a5a),
                  ),
                ),
                onTap: () {
                  // Action pour ajouter une Bible à la liste ordonnée
                  setState(() {
                    currentOrderedBibles.add(bible);
                    // Mettre à jour l'état de la liste pour la prochaine construction
                    initialOrderedBibles = List.from(currentOrderedBibles);
                  });
                },
              );
            }).toList();
          }

          // Stocker la liste des widgets pour une utilisation unique
          final otherBiblesWidgets = buildOtherBiblesList();

          return Dialog(
            insetPadding: const EdgeInsets.all(30),
            child: Container(
              // Suppression du padding horizontal pour que les ListTiles gèrent leur propre padding
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      i18n().label_icon_parallel_translations,
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),

                  Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1), height: 0),

                  const SizedBox(height: 30),

                  Text(
                    i18n().messages_help_download_bibles,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // Liste des Bibles sélectionnées
                  Expanded(
                    child: currentOrderedBibles.isEmpty
                        ? const Center(child: Text('Aucune version sélectionnée.'))
                        : ReorderableListView(
                      shrinkWrap: true,
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final Publication item = currentOrderedBibles.removeAt(oldIndex);
                          currentOrderedBibles.insert(newIndex, item);
                          // Met à jour la référence pour les prochains builds (si setState est appelé ailleurs)
                          initialOrderedBibles = List.from(currentOrderedBibles);
                        });
                      },
                      children: currentOrderedBibles.map((bible) {
                        final bool isLastBible = currentOrderedBibles.length == 1;
                        return ListTile(
                          key: ValueKey(bible.getKey()),
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: isLastBible ? Colors.grey[300] : Colors.red,
                            child: Icon(JwIcons.minus, color: isLastBible ? Colors.grey : Colors.white, size: 20),
                          ),
                          title: Text(
                            bible.mepsLanguage.vernacular,
                            style: const TextStyle(fontSize: 15),
                          ),
                          subtitle: Text(
                            bible.shortTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? Color(0xFFc0c0c0)
                                  : Color(0xFF5a5a5a),
                            ),
                          ),
                          trailing: Icon(Icons.drag_handle, color: isDarkMode
                              ? Color(0xFFc0c0c0)
                              : Color(0xFF5a5a5a),
                          ), // Icône de réorganisation
                          onTap: () {
                            // Action pour retirer une Bible de la liste ordonnée
                            if (!isLastBible) {
                              setState(() {
                                currentOrderedBibles.removeWhere((p) => p.getKey() == bible.getKey());
                                // Met à jour la référence pour les prochains builds
                                initialOrderedBibles = List.from(currentOrderedBibles);
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  // 2. Séparateur et titre "Autres"
                  if (otherBibles.isNotEmpty) ...[
                    Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: Text(
                        i18n().label_not_included_uppercase,
                        style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),

                    // CORRECTION 2 : Utilisation correcte de ListView.separated
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: otherBibles.length,
                        separatorBuilder: (_, __) => Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1), height: 0),
                        itemBuilder: (context, index) => otherBiblesWidgets[index], // Utilisation de la liste pré-calculée
                      ),
                    ),
                  ],

                  Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1)),

                  // Boutons bas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Le bouton 'ANNULER' renvoie null
                      TextButton(
                        onPressed: () => Navigator.pop(context), // Ferme sans renvoyer de résultat (annuler -> null)
                        child: Text(
                          i18n().action_cancel_uppercase,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      // Le bouton 'TERMINÉ' renvoie la liste finale (currentOrderedBibles)
                      TextButton(
                        onPressed: () => Navigator.pop(context, currentOrderedBibles),
                        child: Text(
                          i18n().action_done_uppercase,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  // --- LOGIQUE DE RETOUR Future<bool> ---
  if (result != null) {
    // L'utilisateur a cliqué sur 'TERMINÉ'

    // 1. Mise à jour des données (sauvegarde de la nouvelle liste ordonnée)
    JwLifeSettings.instance.webViewData.updateBiblesSet(result);

    // 2. Vérification s'il y a eu un changement (ajout, suppression ou changement d'ordre)
    final resultKeys = result.map((p) => p.getKey()).toList();

    bool hasChanges = false;

    // a) Vérification du nombre d'éléments
    if (initialKeys.length != resultKeys.length) {
      hasChanges = true;
    } else {
      // b) Vérification de l'ordre
      for (int i = 0; i < initialKeys.length; i++) {
        if (initialKeys[i] != resultKeys[i]) {
          hasChanges = true; // Changement d'ordre
          break;
        }
      }
    }

    return hasChanges;

  } else {
    // L'utilisateur a annulé (résultat est null)
    return false;
  }
}

// Remplacez votre fonction _showActionSheet par celle-ci
void showFloatingMenuAtPosition(BuildContext context, String imagePath, double clientX, double clientY) {

  // 1. Récupérer la taille de l'écran et la position du WebView
  final RenderBox renderBox = context.findRenderObject() as RenderBox;
  final Offset webViewPosition = renderBox.localToGlobal(Offset.zero);

  // 2. Calculer la position globale du clic
  // Coordonnée X globale : Position du WebView + X dans le WebView
  final double globalX = webViewPosition.dx + clientX;
  // Coordonnée Y globale : Position du WebView + Y dans le WebView
  final double globalY = webViewPosition.dy + clientY;

  // 3. Définir la zone du PopUp Menu (RelativeRect)
  // Nous définissons la position de départ (top-left corner) du menu.
  final RelativeRect position = RelativeRect.fromLTRB(
    globalX, // Position de départ X
    globalY, // Position de départ Y
    MediaQuery.of(context).size.width - globalX, // Marge droite (le reste de l'écran)
    MediaQuery.of(context).size.height - globalY, // Marge bas (le reste de l'écran)
  );

  // 4. Créer les éléments de menu (comme dans l'exemple précédent)
  final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[
    PopupMenuItem<String>(
      value: 'save',
      child: ListTile(
        dense: true,
        leading: Icon(JwIcons.cloud_arrow_down, color: Theme.of(context).primaryColor),
        title: Text(i18n().action_save_image),
      ),
    ),
    PopupMenuItem<String>(
      value: 'share',
      child: ListTile(
        dense: true,
        leading: Icon(JwIcons.share, color: Theme.of(context).primaryColor),
        title: Text(i18n().action_share_image),
      ),
    ),
    PopupMenuItem<String>(
      value: 'playlist',
      child: ListTile(
        dense: true,
        leading: Icon(JwIcons.list_play, color: Theme.of(context).primaryColor),
        title: Text(i18n().action_add_to_playlist),
      ),
    ),
  ];

  // 5. Afficher le menu
  showMenu<String>(
    context: context,
    position: position,
    items: items,
    elevation: 8.0,
  ).then((String? value) {
    if (value != null) {
      if (value == 'save') {
        _saveImage(imagePath);
      }
      else if (value == 'share') {
        _shareImage(imagePath);
      }
      else if (value == 'playlist') {
        showAddItemToPlaylistDialog(context, imagePath);
      }
    }
  });
}

// NOTE: L'enregistrement nécessite des packages comme `http` et `image_downloader`
Future<void> _saveImage(String imagePath) async {
  await Gal.putImage(imagePath, album: 'JW Life Images');
  showBottomMessage('Image enregistrée dans l\'album JW Life Images.');
}

// Le partage de l'URL est simple avec `share_plus`
void _shareImage(String imagePath) async {
  try {
    // Partage directement l'URL de l'image.
    await SharePlus.instance.share(
        ShareParams(
          title: "Partage de l'image",
          previewThumbnail: XFile(imagePath),
          files: [XFile(imagePath)],
        )
    );
  } catch (e) {
    print('Erreur lors du partage : $e');
  }
}
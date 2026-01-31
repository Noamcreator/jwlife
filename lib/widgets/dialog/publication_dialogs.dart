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
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/realm/catalog.dart';
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
Future<String?> showDocumentDialog(BuildContext context, String? pub, String? docId, String? track, String? issue, String langwritten, String? fileformat) async {
  if(await hasInternetConnection(context: context)) {
    final queryParams = <String, String>{
      if (pub != null) 'pub': pub,
      if (docId != null) 'docid': docId,
      'fileformat': fileformat ?? '',
      if (track != null) 'track': track,
      if (issue != null) 'issue': issue,
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
        _showFilesDownloadDialog(context, response.data, langwritten);
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
  }
  return '';
}

Future<String?> _showFilesDownloadDialog(BuildContext context, dynamic jsonData, String langwritten) async {
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

  final List<String> initialKeys = initialOrderedBibles.map((p) => p.getKey()).toList();
  final bool initialVersesInParallel = JwLifeSettings.instance.webViewSettings.versesInParallel;
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  // --- TA LOGIQUE ET TON BOOLEAN CONSERVÉS ---
  bool versesInParallel = initialVersesInParallel;
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          List<Publication> currentOrderedBibles = List.from(initialOrderedBibles);
          Set<String> orderedBibleCodes = currentOrderedBibles.map((p) => p.getKey()).toSet();

          List<Publication> otherBibles = allBibles
              .where((p) => !orderedBibleCodes.contains(p.getKey()))
              .toList()
            ..sort((a, b) {
              int langCompare = a.mepsLanguage.symbol.compareTo(b.mepsLanguage.symbol);
              if (langCompare != 0) return langCompare;
              return a.shortTitle.compareTo(b.shortTitle);
            });

          return Dialog(
            // Réduction du padding externe pour plus de place
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              // Suppression du padding horizontal du container pour que les listes touchent les bords
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
              constraints: const BoxConstraints(maxHeight: 700, maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TITRE (Padding ajusté) ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Text(
                      i18n().label_icon_parallel_translations,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC7C7C7)),
                    ),
                  ),

                  Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1), height: 1),

                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // Section 1: Toggle versets côté à côté (Gardé intact)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                            child: Text(
                              i18n().messages_help_download_bibles,
                              style: const TextStyle(fontSize: 15, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        
                        // Section 1: Toggle versets côté à côté (Gardé intact)
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                title: Text(
                                  i18n().label_verses_side_by_side,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  i18n().message_verses_side_by_side,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode ? const Color(0xFFc0c0c0) : const Color(0xFF5a5a5a),
                                  ),
                                ),
                                value: versesInParallel,
                                onChanged: (bool value) {
                                  setState(() {
                                    JwLifeSettings.instance.webViewSettings.updateVersesInParallel(value);
                                    versesInParallel = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Section 2: Liste réordonnable (Padding condensé)
                        SliverReorderableList(
                          itemCount: currentOrderedBibles.length,
                          onReorder: (int oldIndex, int newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final Publication item = currentOrderedBibles.removeAt(oldIndex);
                              currentOrderedBibles.insert(newIndex, item);
                              initialOrderedBibles = List.from(currentOrderedBibles);
                            });
                          },
                          itemBuilder: (context, index) {
                            final bible = currentOrderedBibles[index];
                            final bool isLastBible = currentOrderedBibles.length == 1;

                            return Material(
                              key: ValueKey(bible.getKey()),
                              color: Colors.transparent,
                              child: ReorderableDelayedDragStartListener(
                                index: index,
                                child: Column(
                                  children: [
                                    ListTile(
                                      dense: true,
                                      visualDensity: const VisualDensity(vertical: -2), // Rend la liste plus compacte
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                      leading: GestureDetector(
                                        onTap: isLastBible ? null : () {
                                          setState(() {
                                            currentOrderedBibles.removeWhere((p) => p.getKey() == bible.getKey());
                                            initialOrderedBibles = List.from(currentOrderedBibles);
                                          });
                                        },
                                        child: CircleAvatar(
                                          radius: 13,
                                          backgroundColor: isLastBible ? Colors.grey[300] : Colors.red,
                                          child: const Icon(Icons.remove, color: Colors.white, size: 19),
                                        ),
                                      ),
                                      title: Text(
                                        bible.mepsLanguage.vernacular,
                                        style: TextStyle(fontSize: 15, color: isDarkMode ? Colors.white : Colors.black),
                                      ),
                                      subtitle: Text(
                                        bible.shortTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? const Color(0xFFc0c0c0) : const Color(0xFF5a5a5a),
                                        ),
                                      ),
                                      trailing: ReorderableDragStartListener(
                                        index: index,
                                        child: Icon(
                                          Icons.drag_handle,
                                          size: 22,
                                          color: isDarkMode ? const Color(0xFFc0c0c0) : const Color(0xFF5a5a5a),
                                        ),
                                      ),
                                    ),
                                    Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1), height: 1),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Section 3: Autres bibles
                        if (otherBibles.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  child: Text(
                                    i18n().label_not_included_uppercase,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC0C0C0),
                                    ),
                                  ),
                                ),
                                Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1), height: 1),
                              ],
                            ),
                          ),

                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final bible = otherBibles[index];
                                return Column(
                                  children: [
                                    ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                      leading: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            currentOrderedBibles.add(bible);
                                            initialOrderedBibles = List.from(currentOrderedBibles);
                                          });
                                        },
                                        child: const CircleAvatar(
                                          radius: 13,
                                          backgroundColor: Colors.green,
                                          child: Icon(JwIcons.plus, color: Colors.white, size: 19),
                                        ),
                                      ),
                                      title: Text(
                                        bible.mepsLanguage.vernacular,
                                        style: TextStyle(fontSize: 15, color: isDarkMode ? Colors.white : Colors.black),
                                      ),
                                      subtitle: Text(
                                        bible.shortTitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? const Color(0xFFC1C1C1) : const Color(0xFF5a5a5a),
                                        ),
                                      ),
                                    ),
                                    Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1), height: 1),
                                  ],
                                );
                              },
                              childCount: otherBibles.length,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Divider(color: isDarkMode ? Colors.black : const Color(0xFFf1f1f1), height: 1),

                  // --- BOUTONS BAS (Alignement et couleur ajustés) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, {
                            'bibles': currentOrderedBibles,
                            'versesInParallel': versesInParallel,
                          }),
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
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  // --- LOGIQUE DE RETOUR RESTÉE INTACTE ---
  if (result != null) {
    final List<Publication> finalBibles = result['bibles'];
    final bool finalVersesInParallel = result['versesInParallel'];
    
    JwLifeSettings.instance.webViewSettings.updateBiblesSet(finalBibles);
    
    final resultKeys = finalBibles.map((p) => p.getKey()).toList();
    bool hasChanges = false;

    if (initialKeys.length != resultKeys.length) {
      hasChanges = true;
    } 
    else {
      for (int i = 0; i < initialKeys.length; i++) {
        if (initialKeys[i] != resultKeys[i]) {
          hasChanges = true;
          break;
        }
      }
    }

    if(initialVersesInParallel != finalVersesInParallel) {
      hasChanges = true;
    }

    return hasChanges;
  }
  return false;
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

void showMediaDialog(BuildContext context, Iterable<RealmMediaItem> items) {
  // 1. Définition de l'ordre de priorité des symboles
  final symbolPriority = {'sjjm': 1, 'sjjc': 2, 'pksjj': 3};

  // 2. Tri général selon la priorité du symbole
  final sortedItems = items.toList()
    ..sort((a, b) => (symbolPriority[a.pubSymbol] ?? 99)
        .compareTo(symbolPriority[b.pubSymbol] ?? 99));

  // 3. Séparation Audios et Vidéos
  final audios = sortedItems.where((i) => i.type != 'VIDEO').toList();
  final videos = sortedItems.where((i) => i.type == 'VIDEO').toList();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // Utilisation d'un Dialog simple pour plus de liberté sur le design
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), // Bordures plus carrées comme sur l'image
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (audios.isNotEmpty) ...[
                buildSectionHeader(context, i18n().pub_type_audio_programs),
                ...audios.map((item) => buildMediaTile(context, item)),
              ],
              if (videos.isNotEmpty) ...[
                buildSectionHeader(context, i18n().label_videos),
                ...videos.map((item) => buildMediaTile(context, item)),
              ],
              
              // Zone du bouton ANNULER
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8, top: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
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
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Widget pour les titres de section (Gris clair)
Widget buildSectionHeader(BuildContext context, String title) {
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    color: isDark ? Color(0xFF282828) : Color(0xFFD8D8D8),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
  );
}

// Widget pour chaque ligne de média
Widget buildMediaTile(BuildContext context, RealmMediaItem item) {
  final imageUrl = item.images?.squareImageUrl ?? item.images?.squareFullSizeImageUrl;
  final media = item.type == 'VIDEO' ? Video.fromJson(mediaItem: item) : Audio.fromJson(mediaItem: item);

  return ListTile(
    leading: SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // L'image mise en cache
          ClipRRect(
            borderRadius: BorderRadius.zero, // Rectangle strict comme demandé
            child: ImageCachedWidget(
              imageUrl: imageUrl,
              // On utilise l'icône correspondante si l'image charge mal
              icon: item.type == 'VIDEO' ? JwIcons.video : JwIcons.headphones__simple,
              height: 50,
              width: 50,
            ),
          ),
          // L'icône de téléchargement superposée au centre (style JW Library)
          Icon(
            JwIcons.cloud_arrow_down, 
            color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
        ],
      ),
    ),
    title: Text(
      item.title ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 14),
    ),
    subtitle: Text(formatDuration(item.duration)),
    trailing: RepaintBoundary(
      child: PopupMenuButton(
        useRootNavigator: true,
        popUpAnimationStyle: AnimationStyle.lerp(
          const AnimationStyle(curve: Curves.ease),
          const AnimationStyle(curve: Curves.ease),
          0.5,
        ),
        icon: const Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
        itemBuilder: (context) => media is Audio
            ? [
          if (media.isDownloadedNotifier.value && media.filePath != null) getAudioShareFileItem(media),
          getAudioShareItem(media),
          getAudioAddPlaylistItem(context, media),
          getAudioLanguagesItem(context, media),
          getAudioFavoriteItem(media),
          if (media.isDownloadedNotifier.value && !media.isDownloadingNotifier.value) getAudioDownloadItem(context, media),
          getAudioLyricsItem(context, media),
          getCopyLyricsItem(media)
        ] : media is Video ? [
          if (media.isDownloadedNotifier.value && media.filePath != null) getVideoShareFileItem(media),
          getVideoShareItem(media),
          getVideoQrCode(context, media),
          getVideoAddPlaylistItem(context, media),
          getVideoAddNoteItem(context, media),
          getVideoLanguagesItem(context, media),
          getVideoFavoriteItem(media),
          if (media.isDownloadedNotifier.value && ! media.isDownloadingNotifier.value) getVideoDownloadItem(context, media),
          getShowSubtitlesItem(context, media),
          getCopySubtitlesItem(context, media),
        ]
            : [],
      ),
    ),
    onTap: () {
      Navigator.pop(context);
      if (item.type == 'VIDEO') {
        final video = Video.fromJson(mediaItem: item);
        video.showPlayer(context);
      } else {
        final audio = Audio.fromJson(mediaItem: item);
        audio.showPlayer(context);
      }
    },
  );
}

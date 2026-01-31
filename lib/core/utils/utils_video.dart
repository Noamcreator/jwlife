import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/data/controller/notes_controller.dart';
import 'package:jwlife/data/databases/meps_languages.dart';
import 'package:jwlife/data/databases/mepsunit.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/data/models/video.dart' hide Subtitles;
import 'package:jwlife/features/document/data/models/multimedia.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';
import 'package:provider/provider.dart';
import 'package:realm/realm.dart';

import 'package:share_plus/share_plus.dart';

import '../../app/services/settings_service.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../../features/video/subtitles.dart';
import '../../features/video/subtitles_view.dart';
import '../../i18n/i18n.dart';
import '../../widgets/dialog/qr_code_dialog.dart';
import '../api/api.dart';
import 'common_ui.dart';

RealmMediaItem? getMediaItemFromLank(String lank, String wtlocale) => RealmLibrary.realm.all<RealmMediaItem>().query("LanguageAgnosticNaturalKey == '$lank' AND LanguageSymbol == '$wtlocale'").firstOrNull;

RealmMediaItem? getMediaItem(String? keySymbol, int? track, int? documentId, int? issueTagNumber, dynamic mepsLanguage, {bool? isVideo}) {
  var queryParts = <String>[];

  if (keySymbol != null) queryParts.add("PubSymbol == '$keySymbol'");
  if (track != null) queryParts.add("Track == '$track'");
  if (documentId != null && documentId != 0) queryParts.add("DocumentId == '$documentId'");
  if (issueTagNumber != null && issueTagNumber != 0) {
    String issueStr = issueTagNumber.toString();
    if (issueStr.endsWith("00")) {
      issueStr = issueStr.substring(0, 6); // Supprime les deux derniers 0
    }
    queryParts.add("IssueDate == '$issueStr'");
  }

  String? languageSymbol = JwLifeSettings.instance.libraryLanguage.value.symbol;
  if (mepsLanguage != null) {
    if(mepsLanguage is String) {
      languageSymbol = mepsLanguage;
    }
    else if(mepsLanguage is int) {
      languageSymbol = MepsLanguages.getMepsLanguageSymbolFromId(mepsLanguage);
    }
  }
  if (mepsLanguage != null) queryParts.add("LanguageSymbol == '$languageSymbol'");

  if (isVideo != null) queryParts.add("Type == '${isVideo ? 'VIDEO' : 'AUDIO'}'");

  if (queryParts.isEmpty) return null;

  String query = queryParts.join(" AND ");

  final results = RealmLibrary.realm.all<RealmMediaItem>().query(query);
  return results.isNotEmpty ? results.first : null;
}

PopupMenuItem getVideoShareFileItem(Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.document_envelope),
        SizedBox(width: 8),
        Text(i18n().action_open_in_share_file),
      ],
    ),
    onTap: () {
      SharePlus.instance.share(
        ShareParams(
          title: video.title,
          files: [XFile(video.filePath!)],
        ),
      );
    },
  );
}

PopupMenuItem getVideoShareItem(Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.share),
        SizedBox(width: 8),
        Text(i18n().action_open_in_share),
      ],
    ),
    onTap: () {
      String uri = JwOrgUri.mediaItem(
          wtlocale: video.mepsLanguage!,
          lank: video.naturalKey!
      ).toString();

      SharePlus.instance.share(
        ShareParams(
          title: video.title,
          uri: Uri.parse(uri),
        ),
      );
    },
  );
}

PopupMenuItem getVideoQrCode(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.qr_code),
        SizedBox(width: 8),
        Text(i18n().action_qr_code),
      ],
    ),
    onTap: () {
      String uri = JwOrgUri.mediaItem(
        wtlocale: video.mepsLanguage!,
        lank: video.naturalKey!,
      ).toString();

      String? imagePath = video.isDownloadedNotifier.value ? video.imagePath ?? video.networkImageSqr ?? video.networkFullSizeImageSqr : video.networkImageSqr ?? video.networkFullSizeImageSqr;
      showQrCodeDialog(context, video.title, uri, imagePath: imagePath);
    },
  );
}

PopupMenuItem getVideoAddPlaylistItem(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.list_plus),
        SizedBox(width: 8),
        Text(i18n().action_add_to_playlist),
      ],
    ),
    onTap: () {
      showAddItemToPlaylistDialog(context, video);
    },
  );
}

PopupMenuItem getVideoAddNoteItem(BuildContext context, Video video) {
  NotesController notesController = context.read<NotesController>();
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.note_plus),
        SizedBox(width: 8),
        Text(i18n().action_add_a_note),
      ],
    ),
    onTap: () async {
      Note note = await notesController.addNote(title: video.title, media: video);
      showPage(NotePage(note: note));
    },
  );
}

PopupMenuItem getVideoLanguagesItem(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.language),
        SizedBox(width: 8),
        Text(i18n().label_languages_more),
      ],
    ),
    onTap: () async {
      if(await hasInternetConnection(context: context)) {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${video.naturalKey}';
        final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
        if (response.statusCode == 200) {

          showLanguageDialog(context, languagesListJson: response.data['languages'], media: video).then((language) async {
            if (language != null) {
              String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${language['Symbol']}/${video.naturalKey}';
              final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
              if (response.statusCode == 200) {
                final jsonData = response.data;

                final videoMap = {
                  'KeySymbol': video.keySymbol,
                  'DocumentId': video.documentId,
                  'BookNumber': video.bookNumber,
                  'IssueTagNumber': video.issueTagNumber,
                  'Track': video.track,
                  'MepsLanguage': language['Symbol'],
                  'Title': jsonData['media'][0]['title'],
                  'Duration': jsonData['media'][0]['duration'],
                  'FirstPublished': jsonData['media'][0]['firstPublished'],
                  'NaturalKey': jsonData['media'][0]['languageAgnosticNaturalKey'],
                  'FileUrl': jsonData['media'][0]['files'][3]['progressiveDownloadURL'],
                };
                Video v = Video.fromJson(json: videoMap);
                await v.showPlayer(context);
              }
            }
          });
        }
      }
    },
  );
}

PopupMenuItem getVideoFavoriteItem(Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(video.isFavoriteNotifier.value ? JwIcons.star__fill : JwIcons.star),
        SizedBox(width: 8),
        Text(video.isFavoriteNotifier.value ? i18n().action_favorites_remove : i18n().action_favorites_add),
      ],
    ),
    onTap: () async {
      if(video.isFavoriteNotifier.value) {
        await JwLifeApp.userdata.removeAFavorite(video);
        video.isFavoriteNotifier.value = false;
      }
      else {
        await JwLifeApp.userdata.addInFavorite(video);
        video.isFavoriteNotifier.value = true;
      }
    },
  );
}

PopupMenuItem getVideoDownloadItem(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(video.isDownloadedNotifier.value ? JwIcons.trash : JwIcons.cloud_arrow_down),
        SizedBox(width: 8),
        Text(video.isDownloadedNotifier.value ? i18n().action_remove : i18n().action_download),
      ],
    ),
    onTap: () async {
      if(video.isDownloadedNotifier.value) {
        video.remove(context);
      }
      else {
        video.download(context);
      }
    },
  );
}

PopupMenuItem getShowSubtitlesItem(BuildContext context, Video video, {String query=''}) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.caption),
        SizedBox(width: 8),
        Text(i18n().action_show_subtitles),
      ],
    ),
    onTap: () async {
      if (video.isDownloadedNotifier.value && video.subtitlesFilePath != null) {
        showPage(SubtitlesPage(
            video: video,
            query: query
        ));
      }
      else {
        if(await hasInternetConnection(context: context)) {
          showPage(SubtitlesPage(
              video: video,
              query: query
          ));
        }
      }
    },
  );
}

PopupMenuItem getCopySubtitlesItem(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.document_stack),
        SizedBox(width: 8),
        Text(i18n().action_copy_subtitles),
      ],
    ),
    onTap: () async {
      Subtitles subtitles = Subtitles();
      if (video.isDownloadedNotifier.value && video.subtitlesFilePath != null) {
        File file = File(video.subtitlesFilePath!);
        await subtitles.loadSubtitlesFromFile(file);
      }
      else {
        if(await hasInternetConnection(context: context)) {
          String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${video.mepsLanguage}/${video.naturalKey}';
          final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);

          if (response.statusCode == 200) {
            await subtitles.loadSubtitles(response.data['media'][0]);
          }
        }
      }
      Clipboard.setData(ClipboardData(text: subtitles.toString())).then((value) => showBottomMessage("Sous-titres copiés dans le presse-papier"));
    },
  );
}

// Fonction pour afficher le dialogue de téléchargement
Future<int?> showVideoDownloadDialog(BuildContext context, List<dynamic> files) async {
  // Retourne la taille réelle ou 0 si la clé est manquante ou nulle.
  int getFileSize(dynamic file) {
    return (file['filesize'] as int?) ?? 0;
  }

  // Fonction pour extraire la valeur numérique de la résolution à partir du label (ex: "720p" -> 720)
  int getResolutionValue(dynamic file) {
    final label = file['label'] as String?;
    if (label == null) return 0; // Aucune valeur de tri si le label est manquant

    // Utilise une expression régulière pour trouver le premier nombre dans la chaîne (ex: "720p" ou "480p").
    final match = RegExp(r'(\d+)').firstMatch(label);

    // Si un nombre est trouvé, le convertit en entier. Sinon, retourne 0.
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  if(files.any((file) => file['filesize'] != null)) {
    files.sort((a, b) => getFileSize(b).compareTo(getFileSize(a)));
  }
  else {
    files.sort((a, b) {
      final resA = getResolutionValue(a);
      final resB = getResolutionValue(b);

      // Tri primaire : par résolution (720 avant 480).
      final resolutionComparison = resB.compareTo(resA);

      // Tri secondaire : Si les résolutions sont égales (ou 0), trier par taille décroissante.
      if (resolutionComparison != 0) {
        return resolutionComparison;
      }

      // Tri secondaire par taille (décroissante)
      return getFileSize(b).compareTo(getFileSize(a));
    });
  }

  return showDialog<int>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n().message_select_video_size_title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: files.map<Widget>((file) {
                  // GESTION DE L'AFFICHAGE SÉCURISÉ DE LA TAILLE :
                  final int rawFilesize = getFileSize(file);

                  // L'option 'label' est toujours supposée exister pour l'affichage
                  final String label = file['label'] ?? 'Qualité inconnue';

                  // Affichage conditionnel basé sur la présence de la taille
                  return ListTile(
                    title: rawFilesize == 0
                        ? Text("Télécharger les vidéos en $label")
                        : Text(i18n().action_download_video(label, formatFileSize(rawFilesize))),
                    onTap: () {
                      // Retourner l'index du fichier sélectionné
                      Navigator.of(context).pop(files.indexOf(file));
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Fermer le dialogue et retourner null
                    Navigator.of(context).pop(null);
                  },
                  child: Text(i18n().action_cancel_uppercase),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Exemple de signature modifiée si vous utilisez showMenu :
Future<int?> showVideoDownloadMenu(BuildContext context, List<dynamic> files, Offset tapPosition) async {
  // Prépare les éléments de menu à partir de la liste 'files'
  final List<PopupMenuEntry<int>> items = files.map((file) {
    final int rawFilesize = (file['filesize'] as int?) ?? 0;
    final String label = file['label'] ?? 'Qualité inconnue';

    final int fileIndex = files.indexOf(file);

    return PopupMenuItem<int>(
      value: fileIndex, // La valeur à retourner
      child: rawFilesize == 0
          ? Text("Télécharger les vidéos en $label")
          : Text('$label (${formatFileSize(rawFilesize)})'),
    );
  }).toList();

  return await showMenu<int>(
    useRootNavigator: true,
    context: context,
    position: RelativeRect.fromRect(
      tapPosition & const Size(40, 40), // Rectangle d'ancrage
      Offset.zero & MediaQuery.of(context).size, // Taille de l'écran
    ),
    items: items,
    elevation: 8.0,
  );
}

Future<Video?> getVideoApi({Multimedia? multimedia}) async {
  final currentVideo = multimedia;
  if(currentVideo == null) return null;

  String? pub = currentVideo.keySymbol;
  int? issue = currentVideo.issueTagNumber;
  int? docId = currentVideo.mepsDocumentId;
  int? track = currentVideo.track;
  int? mepsLanguageId = currentVideo.mepsLanguageId;

  final Map<String, String> queryParameters = {
    'langwritten': MepsLanguages.getMepsLanguageSymbolFromId(mepsLanguageId ?? 0) ?? '',
  };

  if (pub != null) {
    queryParameters['pub'] = pub;
  }
  if (issue != 0) {
    queryParameters['issue'] = issue.toString();
  }
  if (docId != null) {
    queryParameters['docid'] = docId.toString();
  }
  if (track != null) {
    queryParameters['track'] = track.toString();
  }

  // 2. Construction de l'URL sécurisée
  final uri = Uri.https(
    'app.jw-cdn.org',
    '/apis/pub-media/GETPUBMEDIALINKS',
    queryParameters,
  );

  final apiUrl = uri.toString();

  printTime('apiUrl: $apiUrl');

  try {
    final response = await Api.httpGetWithHeaders(apiUrl, responseType: ResponseType.json);

    if (response.statusCode == 200) {
      String? lang = queryParameters['langwritten'];
      final file = response.data['files'][lang]['MP4'][0];

      final videoMap = {
        'KeySymbol': file['pub'],
        'DocumentId': file['docid'],
        'BookNumber': file['booknum'],
        'IssueTagNumber': issue,
        'Track': track,
        'MepsLanguage': lang,
        'Title': file['title'] ?? '',
        'Duration': file['duration'],
        'NaturalKey': file['languageAgnosticNaturalKey'],
        'FrameHeight': file['frameHeight'],
        'FrameWidth': file['frameWidth'],
        'Label': file['label'],
        'BitRate': file['bitRate'],
        'FileUrl': file['file']['url'],
      };

      return Video.fromJson(json: videoMap);
    }
    else {
      printTime('Loading error: ${response.statusCode}');
    }
  }
  catch (e) {
    printTime('An exception occurred: $e');
  }
}
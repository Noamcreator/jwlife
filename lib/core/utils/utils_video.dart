import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/data/models/video.dart' hide Subtitles;
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:realm/realm.dart';

import 'package:share_plus/share_plus.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import '../../features/video/subtitles.dart';
import '../../features/video/subtitles_view.dart';
import '../api/api.dart';
import 'common_ui.dart';

MediaItem? getMediaItemFromLank(String lank, String wtlocale) => RealmLibrary.realm.all<MediaItem>().query("languageAgnosticNaturalKey == '$lank'").query("languageSymbol == '$wtlocale'").firstOrNull;

MediaItem? getMediaItem(String? keySymbol, int? track, int? documentId, int? issueTagNumber, dynamic mepsLanguage, {bool? isVideo}) {
  var queryParts = <String>[];

  if (keySymbol != null) queryParts.add("pubSymbol == '$keySymbol'");
  if (track != null) queryParts.add("track == '$track'");
  if (documentId != null && documentId != 0) queryParts.add("documentId == '$documentId'");
  if (issueTagNumber != null && issueTagNumber != 0) {
    String issueStr = issueTagNumber.toString();
    if (issueStr.endsWith("00")) {
      issueStr = issueStr.substring(0, 6); // Supprime les deux derniers 0
    }
    queryParts.add("issueDate == '$issueStr'");
  }

  String languageSymbol = JwLifeSettings().currentLanguage.symbol;
  if (mepsLanguage != null && mepsLanguage is String) {
    languageSymbol = mepsLanguage;
  }
  if (mepsLanguage != null) queryParts.add("languageSymbol == '$languageSymbol'");

  if (isVideo != null) queryParts.add("type == '${isVideo ? 'VIDEO' : 'AUDIO'}'");

  if (queryParts.isEmpty) return null;

  String query = queryParts.join(" AND ");

  final results = RealmLibrary.realm.all<MediaItem>().query(query);
  return results.isNotEmpty ? results.first : null;
}

PopupMenuItem getVideoShareItem(Video video) {
  return PopupMenuItem(
    child: Row(
      children: const [
        Icon(JwIcons.share),
        SizedBox(width: 8),
        Text('Envoyer le lien'),
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

PopupMenuItem getVideoAddPlaylistItem(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.list_plus),
        SizedBox(width: 8),
        Text('Ajouter à la liste de lecture'),
      ],
    ),
    onTap: () {
      showAddItemToPlaylistDialog(context, video);
    },
  );
}

PopupMenuItem getVideoLanguagesItem(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.language),
        SizedBox(width: 8),
        Text('Autres langues'),
      ],
    ),
    onTap: () async {
      if(await hasInternetConnection()) {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${video.naturalKey}';
        final response = await Api.httpGetWithHeaders(link);
        if (response.statusCode == 200) {
          final jsonFile = response.body;
          final jsonData = json.decode(jsonFile);

          showLanguageDialog(context, languagesListJson: jsonData['languages']).then((language) async {
            if (language != null) {
              String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${language['Symbol']}/${video.naturalKey}';
              final response = await Api.httpGetWithHeaders(link);
              if (response.statusCode == 200) {
                final jsonFile = response.body;
                final jsonData = json.decode(jsonFile);

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
      else {
        showNoConnectionDialog(context);
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
        Text(video.isFavoriteNotifier.value ? 'Supprimer des favoris' : 'Ajouter aux favoris'),
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

      GlobalKeyService.homeKey.currentState?.refreshFavorites();
    },
  );
}

PopupMenuItem getVideoDownloadItem(BuildContext context, Video video) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(video.isDownloadedNotifier.value ? JwIcons.trash : JwIcons.cloud_arrow_down),
        SizedBox(width: 8),
        Text(video.isDownloadedNotifier.value ? 'Supprimer' : 'Télécharger'),
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
        Text('Voir les sous-titres'),
      ],
    ),
    onTap: () async {
      if (video.isDownloadedNotifier.value) {
        showPage(SubtitlesPage(
            video: video,
            query: query
        ));
      }
      else {
        if(await hasInternetConnection()) {
          showPage(SubtitlesPage(
              video: video,
              query: query
          ));
        }
        else {
          showNoConnectionDialog(context);
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
        Text('Copier les sous-titres'),
      ],
    ),
    onTap: () async {
      Subtitles subtitles = Subtitles();
      if (video.isDownloadedNotifier.value) {
        File file = File(video.subtitlesFilePath);
        await subtitles.loadSubtitlesFromFile(file);
      }
      else {
        if(await hasInternetConnection()) {
          String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${video.mepsLanguage}/${video.naturalKey}';
          final response = await Api.httpGetWithHeaders(link);

          if (response.statusCode == 200) {
            final jsonFile = response.body;
            final jsonData = json.decode(jsonFile);
            await subtitles.loadSubtitles(jsonData['media'][0]);
          }
        }
        else {
          showNoConnectionDialog(context);
          return;
        }
      }
      printTime(subtitles.toString());
      Clipboard.setData(ClipboardData(text: subtitles.toString())).then((value) => showBottomMessage("Sous-titres copiés dans le presse-papier"));
    },
  );
}

// Fonction pour afficher le dialogue de téléchargement
Future<int?> showVideoDownloadDialog(BuildContext context, List<dynamic> files) async {

  // Fonction utilitaire pour obtenir la taille de fichier en toute sécurité.
  // Retourne la taille réelle ou 0 si la clé est manquante ou nulle.
  int getFileSize(dynamic file) {
    // Utiliser l'opérateur 'as' pour s'assurer que 'filesize' est traité comme un entier,
    // ou retourner 0 s'il est null ou manquant.
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
                "Résolution",
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

                  String sizeText;
                  if (rawFilesize == 0) {
                    sizeText = "Taille inconnue";
                  } else {
                    // Calcul de la taille en Mo ou Go
                    double fileSize = rawFilesize / (1024 * 1024); // Taille en Mo
                    sizeText = fileSize < 1024
                        ? "${fileSize.toStringAsFixed(2)} Mo"
                        : "${(fileSize / 1024).toStringAsFixed(2)} Go";
                  }

                  // Affichage conditionnel basé sur la présence de la taille
                  return ListTile(
                    title: rawFilesize == 0
                        ? Text("Télécharger les vidéos en $label")
                        : Text("Télécharger $label ($sizeText)"),
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

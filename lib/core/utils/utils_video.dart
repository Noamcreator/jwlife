import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_media.dart';
import 'package:jwlife/data/databases/Video.dart';
import 'package:jwlife/video/subtitles.dart';
import 'package:jwlife/video/subtitles_view.dart';
import 'package:jwlife/video/video_player_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/dialog/publication_dialogs.dart';
import 'package:realm/realm.dart';

import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../app/jwlife_view.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import 'common_ui.dart';
import 'files_helper.dart';

void showFullScreenVideo(BuildContext context, MediaItem mediaItem) async {
  Video? video = JwLifeApp.mediaCollections.getVideo(mediaItem);

  if (video != null) {
    JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

    showPage(context, VideoPlayerView(
      mediaItem: mediaItem,
      localVideo: video
    ));
  }
  else {
    if(await hasInternetConnection()) {
      JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

      showPage(context, VideoPlayerView(
        mediaItem: mediaItem
      ));
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

MediaItem getVideoItemFromLank(String lank, String wtlocale) => RealmLibrary.realm.all<MediaItem>().query("languageAgnosticNaturalKey == '$lank'").query("languageSymbol == '$wtlocale'").first;
MediaItem getVideoItemFromDocId(String docId, String wtlocale) => RealmLibrary.realm.all<MediaItem>().query("documentId == '$docId'").query("languageSymbol == '$wtlocale'").first;


MediaItem? getVideoItem(String? keySymbol, int? track, int? documentId, int? issueTagNumber, dynamic mepsLanguage) {
  var queryParts = <String>[];
  if (keySymbol != null) queryParts.add("pubSymbol == '$keySymbol'");
  if (track != null) queryParts.add("track == '$track'");
  if (documentId != null) queryParts.add("documentId == '$documentId'");
  if (issueTagNumber != null && issueTagNumber != 0) {
    String issueStr = issueTagNumber.toString();
    if (issueStr.endsWith("00")) {
      issueStr = issueStr.substring(0, 6); // Supprime les deux derniers 0
    }
    queryParts.add("issueDate == '$issueStr'");
  }

  String languageSymbol = JwLifeApp.settings.currentLanguage.symbol;
  if(mepsLanguage != null && mepsLanguage is String) {
    languageSymbol = mepsLanguage;
  }
  if (mepsLanguage != null) queryParts.add("languageSymbol == '$languageSymbol'");

  if (queryParts.isEmpty) return null;

  queryParts.add("type == 'VIDEO'");
  String query = queryParts.join(" AND ");

  return RealmLibrary.realm.all<MediaItem>().query(query).firstOrNull;
}

PopupMenuItem getVideoShareItem(MediaItem item) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.share),
        SizedBox(width: 8),
        Text('Envoyer le lien'),
      ],
    ),
    onTap: () {
      Share.shareUri(Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=${item.languageSymbol}&lank=${item.languageAgnosticNaturalKey}'));
    },
  );
}

PopupMenuItem getVideoLanguagesItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.language),
        SizedBox(width: 8),
        Text('Autres langues'),
      ],
    ),
    onTap: () async {
      final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

      if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${item.languageAgnosticNaturalKey}?clientType=www';
        final response = await http.get(Uri.parse(link));
        if (response.statusCode == 200) {
          final jsonFile = response.body;
          final jsonData = json.decode(jsonFile);

          LanguageDialog languageDialog = LanguageDialog(languagesListJson: jsonData['languages']);
          showDialog(
            context: context,
            builder: (context) => languageDialog,
          );
        }
      }
      else {
        showNoConnectionDialog(context);
      }
    },
  );
}

PopupMenuItem getVideoFavoriteItem(MediaItem item) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.star),
        SizedBox(width: 8),
        Text('Ajouter aux favoris'),
      ],
    ),
    onTap: () async {
      // Ajoutez ici votre logique d'ajout aux favoris
    },
  );
}

PopupMenuItem getVideoDownloadItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.cloud_arrow_down),
        SizedBox(width: 8),
        Text('Télécharger'),
      ],
    ),
    onTap: () async {
      if(await hasInternetConnection()) {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${item.languageSymbol}/${item.languageAgnosticNaturalKey}';
        final response = await http.get(Uri.parse(link));
        if (response.statusCode == 200) {
          final jsonFile = response.body;
          final jsonData = json.decode(jsonFile);

          print(link);

          showVideoDownloadDialog(context, jsonData['media'][0]['files']).then((value) {
            if (value != null) {
              downloadMedia(context, item, jsonData['media'][0], file: value);
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

PopupMenuItem getShowSubtitlesItem(BuildContext context, MediaItem item, {String query=''}) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.caption),
        SizedBox(width: 8),
        Text('Voir les sous-titres'),
      ],
    ),
    onTap: () async {
      Video? video = JwLifeApp.mediaCollections.getVideo(item);
      if (video != null) {
        showPage(context, SubtitlesView(
            localVideo: video,
            query: query
        ));
      }
      else {
        final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

        if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
          showPage(context, SubtitlesView(
              mediaItem: item,
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

PopupMenuItem getCopySubtitlesItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.document_stack),
        SizedBox(width: 8),
        Text('Copier les sous-titres'),
      ],
    ),
    onTap: () async {
      File mediaCollectionFile = await getMediaCollectionsFile();
      Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);
      dynamic media = await getVideoIfDownload(db, item);

      Subtitles subtitles = Subtitles();
      if (media != null) {
        File file = File(media['SubtitleFilePath']);
        await subtitles.loadSubtitlesFromFile(file);
      }
      else {
        final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

        if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
          String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${item.languageSymbol}/${item.languageAgnosticNaturalKey}';
          final response = await http.get(Uri.parse(link));

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
      print(subtitles.toString());
      Clipboard.setData(ClipboardData(text: subtitles.toString())).then((value) => showBottomMessage(context, "Sous-titres copiés dans le presse-papier"));
    },
  );
}



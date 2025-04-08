import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/core/utils/utils_media.dart';
import 'package:jwlife/video/subtitles.dart';
import 'package:jwlife/video/subtitles_view.dart';
import 'package:jwlife/video/video_player_view.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/publication/publication_dialogs.dart';
import 'package:realm/realm.dart';

import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/jwlife_view.dart';
import '../../data/realm/catalog.dart';
import '../../data/realm/realm_library.dart';
import 'common_ui.dart';
import 'files_helper.dart';

void showFullScreenVideo(BuildContext context, String lank, String lang) async {
  File mediaCollectionFile = await getMediaCollectionsFile();
  Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);

  MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("languageAgnosticNaturalKey == '$lank'").query("languageSymbol == '$lang'").first;

  dynamic media = await getMediaIfDownload(db, mediaItem);

  if (media != null) {
    JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

    showPage(context, VideoPlayerView(
      localVideo: media
    ));
  }
  else {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

    if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
      JwLifeView.toggleNavBarBlack.call(JwLifeView.currentTabIndex, true);

      showPage(context, VideoPlayerView(
        lank: lank,
        lang: lang
      ));
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

PopupMenuItem getVideoShareItem(MediaItem item) {
  return PopupMenuItem(
    child: const Text('Envoyer le lien'),
    onTap: () {
      Share.shareUri(Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=${item.languageSymbol}&lank=${item.languageAgnosticNaturalKey}'));
    },
  );
}

PopupMenuItem getVideoLanguagesItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: const Text('Autres langues'),
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
    child: Text('Ajouter aux favoris'),
    onTap: () async {
      // Ajoutez ici votre logique d'ajout aux favoris
    },
  );
}

PopupMenuItem getVideoDownloadItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: Text('Télécharger'),
    onTap: () async {
      final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

      if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${item.languageSymbol}/${item.languageAgnosticNaturalKey}';
        final response = await http.get(Uri.parse(link));
        if (response.statusCode == 200) {
          final jsonFile = response.body;
          final jsonData = json.decode(jsonFile);

          showVideoDownloadDialog(context, jsonData['media'][0]['files']).then((value) {
            if (value != null) {
              downloadVideoFile(item, jsonData['media'][0], value, context);
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
    child: const Text('Voir les sous-titres'),
    onTap: () async {
      File mediaCollectionFile = await getMediaCollectionsFile();
      Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);
      dynamic media = await getMediaIfDownload(db, item);
      if (media != null) {
        showPage(context, SubtitlesView(
            localVideo: media,
            query: query
        ));
      }
      else {
        final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

        if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
          String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${item.languageSymbol}/${item.languageAgnosticNaturalKey}';

          showPage(context, SubtitlesView(
              apiVideoUrl: link,
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
    child: const Text('Copier les sous-titres'),
    onTap: () async {
      File mediaCollectionFile = await getMediaCollectionsFile();
      Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);
      dynamic media = await getMediaIfDownload(db, item);

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
      Clipboard.setData(ClipboardData(text: subtitles.toString())).then((value) => showBottomMessage(context, "Sous-titres copiés dans le presse-papier"));
    },
  );
}



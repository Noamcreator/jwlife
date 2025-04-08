import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_view.dart';
import 'package:jwlife/audio/lyrics_view.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:realm/realm.dart';

import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/publication/publication_dialogs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../video/subtitles.dart';
import 'common_ui.dart';
import 'files_helper.dart';
import 'utils_media.dart';

void showAudioPlayer(BuildContext context, String lank, String lang) async {
  File mediaCollectionFile = await getMediaCollectionsFile();
  Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);

  MediaItem mediaItem = RealmLibrary.realm.all<MediaItem>().query("languageAgnosticNaturalKey == '$lank'").query("languageSymbol == '$lang'").first;

  dynamic media = await getMediaIfDownload(db, mediaItem);

  if (media != null) {

    /*
    showPage(context, VideoPlayerView(
        localVideo: media
    ));

     */
  }
  else {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

    if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
      JwLifeApp.jwAudioPlayer.setRandomMode(false);
      JwLifeApp.jwAudioPlayer.fetchAudioData(lank, lang);
      JwLifeApp.jwAudioPlayer.play();
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

void showAudioPlayerLink(BuildContext context, String pubTitle, List<dynamic> audios, Uri imageFilePath, int id) async {
  File mediaCollectionFile = await getMediaCollectionsFile();
  Database db = await openDatabase(mediaCollectionFile.path, readOnly: true, version: 1);

  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

  if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
    JwLifeApp.jwAudioPlayer.setRandomMode(false);
    JwLifeApp.jwAudioPlayer.setAudioPlaylist(pubTitle, audios, imageFilePath, id: id);
    JwLifeApp.jwAudioPlayer.play();
  }
  else {
    showNoConnectionDialog(context);
  }
}

PopupMenuItem getAudioShareItem(MediaItem item) {
  return PopupMenuItem(
    child: const Text('Envoyer le lien'),
    onTap: () {
      Share.share(
        'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${item.languageSymbol}&lank=${item.languageAgnosticNaturalKey}'
      );
    },
  );
}

PopupMenuItem getAudioLanguagesItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: const Text('Autres langues'),
    onTap: () async {
      String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${item.languageAgnosticNaturalKey}?clientType=www';
      final response = await http.get(Uri.parse(link));
      if (response.statusCode == 200) {
        final jsonFile = response.body;
        final jsonData = json.decode(jsonFile);

        LanguageDialog languageDialog = LanguageDialog(languagesListJson: jsonData['languages']);
        showDialog(
          context: context,
          builder: (context) => languageDialog,
        ).then((value) {
          if (value != null) {
            //Navigator.pushNamed(context, '/audio', arguments: value);
          }
        });
      }
    },
  );
}

PopupMenuItem getAudioFavoriteItem(MediaItem item) {
  return PopupMenuItem(
    child: Text('Ajouter aux favoris'),
    onTap: () async {
      // Ajoutez ici votre logique d'ajout aux favoris
    },
  );
}

PopupMenuItem getAudioDownloadItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: Text('Télécharger'),
    onTap: () async {
      // Téléchargez ici votre
    },
  );
}

PopupMenuItem getAudioLyricsItem(BuildContext context, MediaItem item, {String query=''}) {
  return PopupMenuItem(
    child: const Text('Voir les paroles'),
    onTap: () async {
      String link = 'https://www.jw.org/finder?wtlocale=${item.languageSymbol}&lank=${item.languageAgnosticNaturalKey}';

      showPage(context, LyricsPage(
          audioJwPage: link,
          query: query
      ));
    },
  );
}

PopupMenuItem getCopyLyricsItem(MediaItem item) {
  return PopupMenuItem(
    child: const Text('Copier les paroles'),
    onTap: () async {
      String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${item.languageSymbol}/${item.languageAgnosticNaturalKey}';
      final response = await http.get(Uri.parse(link));
      if (response.statusCode == 200) {
        final jsonFile = response.body;
        final jsonData = json.decode(jsonFile);
        Subtitles subtitles = Subtitles();
        await subtitles.loadSubtitles(jsonData['media'][0]);
        Clipboard.setData(ClipboardData(text: subtitles.toString()));
      }
    },
  );
}



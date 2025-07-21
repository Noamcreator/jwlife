import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:realm/realm.dart';

import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';

import '../../app/services/settings_service.dart';
import '../../features/audio/lyrics_page.dart';
import '../../features/video/subtitles.dart';
import '../api.dart';
import 'common_ui.dart';
import 'utils_media.dart';

import 'package:audio_service/audio_service.dart' as audio_service;

void showAudioPlayerForLink(BuildContext context, String url, audio_service.MediaItem mediaItem, {Duration initialPosition = Duration.zero, Duration? endPosition}) async {
  if(await hasInternetConnection()) {
    JwLifeApp.audioPlayer.playAudioFromLink(url, mediaItem, initialPosition: initialPosition, endPosition: endPosition);
  }
  else {
    showNoConnectionDialog(context);
  }
}

void showAudioPlayer(BuildContext context, MediaItem mediaItem) async {
  Audio? audio = JwLifeApp.mediaCollections.getAudioFromMediaItem(mediaItem);

  if (audio != null) {
    JwLifeApp.audioPlayer.playAudio(mediaItem, localAudio: audio);
  }
  else {
    if(await hasInternetConnection()) {
      JwLifeApp.audioPlayer.playAudio(mediaItem);
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

void showAudioPlayerPublicationLink(BuildContext context, Publication publication, List<Audio> audios, int id, {Duration? start}) async {
  Audio audio = audios.elementAt(id);

  if(audios.isNotEmpty) {
    if(await hasInternetConnection() || audio.isDownloaded) {
      JwLifeApp.audioPlayer.playAudioFromPublicationLink(publication, audios, id, start ?? Duration.zero);
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

MediaItem? getAudioItem(String? keySymbol, int? track, int? documentId, int? issueTagNumber, int? mepsLanguageId) {
  String languageSymbol = JwLifeSettings().currentLanguage.symbol;
  var queryParts = <String>[];
  if (keySymbol != null && keySymbol != '') queryParts.add("pubSymbol == '$keySymbol'");
  if (track != null && track != 0) queryParts.add("track == '$track'");
  if (documentId != null && documentId != 0) queryParts.add("documentId == '$documentId'");
  if (issueTagNumber != null && issueTagNumber != 0) queryParts.add("issueDate == '$issueTagNumber'");
  if (mepsLanguageId != null) queryParts.add("languageSymbol == '$languageSymbol'");

  if (queryParts.isEmpty) return null;

  queryParts.add("type == 'AUDIO'");
  String query = queryParts.join(" AND ");

  printTime("Query: $query");
  return RealmLibrary.realm.all<MediaItem>().query(query).firstOrNull;
}

PopupMenuItem getAudioShareItem(MediaItem item) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.share),
        SizedBox(width: 8),
        Text('Envoyer le lien'),
      ],
    ),
    onTap: () {
      Share.share(
        'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${item.languageSymbol}&lank=${item.languageAgnosticNaturalKey}'
      );
    },
  );
}

PopupMenuItem getAudioLanguagesItem(BuildContext context, MediaItem item) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.language),
        SizedBox(width: 8),
        Text('Autres langues'),
      ],
    ),
    onTap: () async {
      String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${item.languageAgnosticNaturalKey}?clientType=www';
      final response = await Api.httpGetWithHeaders(link);
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

PopupMenuItem getAudioDownloadItem(BuildContext context, MediaItem item) {
  bool isDownload = JwLifeApp.mediaCollections.getAudioFromMediaItem(item) != null;

  return PopupMenuItem(
    child: Row(
      children: [
        isDownload ? Icon(JwIcons.trash) : Icon(JwIcons.cloud_arrow_down),
        SizedBox(width: 8),
        isDownload ? Text('Supprimer') : Text('Télécharger'),
      ],
    ),
    onTap: () async {
      if (isDownload) {
        await removeMedia(item);
      }
      else {
        if(await hasInternetConnection()) {
          String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${item.languageSymbol}/${item.languageAgnosticNaturalKey}';
          final response = await Api.httpGetWithHeaders(link);
          if (response.statusCode == 200) {
            final jsonFile = response.body;
            final jsonData = json.decode(jsonFile);

            printTime(link);

            downloadMedia(context, item, jsonData['media'][0]);
          }
        }
        else {
          showNoConnectionDialog(context);
        }
      }
    },
  );
}

PopupMenuItem getAudioLyricsItem(BuildContext context, MediaItem item, {String query=''}) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.caption),
        SizedBox(width: 8),
        Text('Voir les paroles'),
      ],
    ),
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
    child: Row(
      children: [
        Icon(JwIcons.document_stack),
        SizedBox(width: 8),
        Text('Copier les paroles'),
      ],
    ),
    onTap: () async {
      String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${item.languageSymbol}/${item.languageAgnosticNaturalKey}';
      final response = await Api.httpGetWithHeaders(link);
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



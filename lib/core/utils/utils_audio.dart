import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:realm/realm.dart';

import 'package:share_plus/share_plus.dart';
import 'package:jwlife/app/jwlife_app.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../features/audio/lyrics_page.dart';
import '../../features/video/subtitles.dart';
import '../../i18n/i18n.dart';
import '../api/api.dart';
import '../jworg_uri.dart';
import 'common_ui.dart';

import 'package:audio_service/audio_service.dart' as audio_service;

void showAudioPlayerForLink(BuildContext context, String url, audio_service.MediaItem mediaItem, {Duration initialPosition = Duration.zero, Duration? endPosition}) async {
  if(await hasInternetConnection(context: context)) {
    JwLifeApp.audioPlayer.playAudioFromLink(url, mediaItem, initialPosition: initialPosition, endPosition: endPosition);
  }
}

void showAudioPlayerPublicationLink(BuildContext context, Publication publication, int id, {Duration? start}) async {
  Audio audio = publication.audios.elementAt(id);

  if(publication.audios.isNotEmpty) {
    if(await hasInternetConnection(context: context) || audio.isDownloadedNotifier.value) {
      JwLifeApp.audioPlayer.playAudioFromPublicationLink(publication, id, start ?? Duration.zero);
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

  return RealmLibrary.realm.all<MediaItem>().query(query).firstOrNull;
}

PopupMenuItem getAudioShareItem(Audio audio) {
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
          wtlocale: audio.mepsLanguage!,
          lank: audio.naturalKey!
      ).toString();

      SharePlus.instance.share(
        ShareParams(
          title: audio.title,
          uri: Uri.parse(uri),
        ),
      );
    },
  );
}

PopupMenuItem getAudioAddPlaylistItem(BuildContext context, Audio audio) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.list_plus),
        SizedBox(width: 8),
        Text(i18n().action_add_to_playlist),
      ],
    ),
    onTap: () {
      showAddItemToPlaylistDialog(context, audio);
    },
  );
}

PopupMenuItem getAudioLanguagesItem(BuildContext context, Audio audio) {
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
        String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${audio.naturalKey}';
        final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
        if (response.statusCode == 200) {

          showLanguageDialog(context, languagesListJson: response.data['languages']).then((language) async {
            String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${language['Symbol']}/${audio.naturalKey}';
            print(link);

            final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
            if (response.statusCode == 200) {

              final mediaList = response.data['media'] as List<dynamic>?;
              final media = mediaList != null && mediaList.isNotEmpty
                  ? mediaList.first as Map<String, dynamic>
                  : null;

              final filesList = media?['files'] as List<dynamic>?;
              final files = filesList != null && filesList.isNotEmpty
                  ? filesList.first as Map<String, dynamic>
                  : null;

              final images = media?['images'] as Map<String, dynamic>?;

              final audioMap = {
                'KeySymbol': audio.keySymbol,
                'DocumentId': audio.documentId,
                'BookNumber': audio.bookNumber,
                'IssueTagNumber': audio.issueTagNumber,
                'Track': audio.track,
                'MepsLanguage': language['Symbol'],
                'Title': media?['title'] ?? '',
                'Duration': media?['duration'] ?? 0,
                'FirstPublished': media?['firstPublished'] ?? '',
                'NaturalKey': media?['languageAgnosticNaturalKey'] ?? '',
                'FileUrl': files?['progressiveDownloadURL'] ?? '',
                'ImagePath': images?['cvr']?['md'] ?? images?['sqr']?['md'] ?? '',
              };

              Audio a = Audio.fromJson(json: audioMap);
              await a.showPlayer(context);
            }
          });
        }
      }
    },
  );
}

PopupMenuItem getAudioFavoriteItem(Audio audio) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(audio.isFavoriteNotifier.value ? JwIcons.star__fill : JwIcons.star),
        SizedBox(width: 8),
        Text(audio.isFavoriteNotifier.value ? i18n().action_favorites_remove : i18n().action_favorites_add),
      ],
    ),
    onTap: () async {
      if(audio.isFavoriteNotifier.value) {
        await JwLifeApp.userdata.removeAFavorite(audio);
        audio.isFavoriteNotifier.value = false;
      }
      else {
        await JwLifeApp.userdata.addInFavorite(audio);
        audio.isFavoriteNotifier.value = true;
      }

      GlobalKeyService.homeKey.currentState?.refreshFavorites();
    },
  );
}

PopupMenuItem getAudioDownloadItem(BuildContext context, Audio audio) {
  bool isDownload = audio.isDownloadedNotifier.value;

  return PopupMenuItem(
    child: Row(
      children: [
        isDownload ? Icon(JwIcons.trash) : Icon(JwIcons.cloud_arrow_down),
        SizedBox(width: 8),
        isDownload ? Text(i18n().action_delete) : Text(i18n().action_download),
      ],
    ),
    onTap: () async {
      if (isDownload) {
        audio.remove(context);
      }
      else {
        audio.download(context);
      }
    },
  );
}

PopupMenuItem getAudioLyricsItem(BuildContext context, Audio audio, {String query=''}) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.caption),
        SizedBox(width: 8),
        Text(i18n().action_show_lyrics),
      ],
    ),
    onTap: () async {
      String link = 'https://www.jw.org/finder?wtlocale=${audio.mepsLanguage}&lank=${audio.naturalKey}';

      showPage(LyricsPage(
          audioJwPage: link,
          query: query
      ));
    },
  );
}

PopupMenuItem getCopyLyricsItem(Audio audio) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.document_stack),
        SizedBox(width: 8),
        Text(i18n().action_copy_lyrics),
      ],
    ),
    onTap: () async {
      String link = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/${audio.mepsLanguage}/${audio.naturalKey}';
      final response = await Api.httpGetWithHeaders(link, responseType: ResponseType.json);
      if (response.statusCode == 200) {
        Subtitles subtitles = Subtitles();
        await subtitles.loadSubtitles(response.data['media'][0]);
        Clipboard.setData(ClipboardData(text: subtitles.toString()));
      }
    },
  );
}



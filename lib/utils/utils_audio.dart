import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/realm/catalog.dart';

import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

import '../audio/lyrics_page.dart';
import '../video/subtitle_page.dart';
import '../video/Subtitles.dart';
import '../widgets/dialog/language_dialog.dart';

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

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
            return LyricsPage(
                audioJwPage: link,
                query: query
            );
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
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



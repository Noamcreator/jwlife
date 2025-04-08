import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';

import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/data/realm/catalog.dart' as realm_catalog;

import '../app/jwlife_app.dart';
import '../app/jwlife_view.dart';

class JwAudioPlayer {
  int currentId = -1;
  AudioPlayer player = AudioPlayer();
  ConcatenatingAudioSource playlist = ConcatenatingAudioSource(children: []);
  String album = '';
  String query = '';
  bool randomMode = false;

  Future<void> fetchAudioData(String lank, String lang) async {
    if (lank.isNotEmpty && lang.isNotEmpty) {
      album = '';
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank';
      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          album = data['media'][0]['primaryCategory'];

          setPlaylist([data['media'][0]]);
        }
        else {
          print('Loading error: ${response.statusCode}');
        }
      }
      catch (e) {
        print('An exception occurred: $e');
      }
    }
    else {
      print('Lank or lang parameters are missing in the URL.');
    }
  }

  Future<void> fetchAudiosCategoryData(realm_catalog.Category category, {int? id}) async {
    List<dynamic> audios = [];

    if(album != category.localizedName) {
      album = category.localizedName!;
      String languageSymbol = JwLifeApp.currentLanguage.symbol;

      // URL de l'API
      final url = 'https://b.jw-cdn.org/apis/mediator/v1/categories/$languageSymbol/${category.key}?detailed=1&mediaLimit=0';
      print(url);

      // Requête HTTP pour récupérer le JSON
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Conversion de la réponse en JSON
        final jsonData = json.decode(response.body);

        // Vérification si la catégorie contient des médias
        if (jsonData['category'] != null && jsonData['category']['media'] != null) {
          for (var media in jsonData['category']['media']) {
            if (media['naturalKey'] != null) {
              audios.add(media);
            }
          }
        }

        setPlaylist(audios, id: id);
      }
      else {
        throw Exception('Erreur lors de la récupération des données : ${response.statusCode}');
      }
    }
    else {
      player.seek(Duration.zero, index: id);
    }
  }

  Future<void> fetchAudiosSearchData(List<Map<String, dynamic>> audios, String query, {int? id}) async {
    if(this.query != query) {
      this.query = query;
      String languageSymbol = JwLifeApp.currentLanguage.symbol;

      int mediaId = 0;

      List<AudioSource> children = [];
      for(var audio in audios) {
        String url = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$languageSymbol/${audio['lank']}';
        print(url);

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          // Conversion de la réponse en JSON
          final jsonData = json.decode(response.body)['media'][0];

          // Vérification si la catégorie contient des médias
          children.add(
            AudioSource.uri(
              Uri.parse(jsonData['files'][0]['progressiveDownloadURL']),
              tag: MediaItem(
                id: '${mediaId++}',
                album: album,
                title: jsonData['title'],
                artUri: Uri.parse(jsonData['images']['sqr']['md']),
                //extras: {'docId': audio['images']['sqr']['lg'].split('/').last.split('_')[0]},
              ),
            ),
          );
        }
        else {
          throw Exception('Erreur lors de la récupération des données : ${response.statusCode}');
        }
      }

      playlist = ConcatenatingAudioSource(children: children);

      // Configuration de l'audio player
      player.setAudioSource(playlist, initialIndex: id ?? 0);
    }
    else {
      player.seek(Duration.zero, index: id);
    }
  }

  void setPlaylist(List<dynamic> audios, {int? id}) {
    int mediaId = 0;

    playlist = ConcatenatingAudioSource(children: [
      for (var audio in audios)
        AudioSource.uri(
          Uri.parse(audio['files'][0]['progressiveDownloadURL']),
          tag: MediaItem(
            id: '${mediaId++}',
            album: album,
            title: audio['title'],
            artUri: Uri.parse(audio['images']['sqr']['md']),
            //extras: {'docId': audio['images']['sqr']['lg'].split('/').last.split('_')[0]},
          ),
        ),
    ]);

    // Configuration de l'audio player
    player.setAudioSource(playlist, initialIndex: id ?? 0);
  }

  void setAudioPlaylist(String pubTitle, List<dynamic> audios, Uri imageFilePath, {int? id}) {
    int mediaId = 0;

    playlist = ConcatenatingAudioSource(children: [
      for (var audio in audios)
        AudioSource.uri(
          Uri.parse(audio['file']['url']),
          tag: MediaItem(
            id: '${mediaId++}',
            artUri: imageFilePath,
            album: pubTitle,
            title: audio['title'],
            //extras: {'docId': audio['images']['sqr']['lg'].split('/').last.split('_')[0]},
          ),
        ),
    ]);

    // Configuration de l'audio player
    player.setAudioSource(playlist, initialIndex: id ?? 0);
  }

  void setLanguagePlaylist(ConcatenatingAudioSource playlist, album, {int? id}) {
    this.album = album;
    this.playlist = playlist;
    player.setAudioSource(this.playlist, initialIndex: id ?? 0);
  }

  void setId(int id) {
    currentId = id;
  }

  void setRandomMode(bool randomMode) {
    if (this.randomMode == randomMode) return;
    this.randomMode = randomMode;
    player.setShuffleModeEnabled(randomMode);
  }

  void play() {
    player.play();
    if (!JwLifeView.isAudioWidgetVisible) {
      JwLifeView.toggleAudioWidgetVisibility(true);
    }
  }

  void pause() {
    player.pause();
  }

  void next() {
    player.seekToNext();
    player.play();
  }

  void previous() {
    player.seekToPrevious();
    player.play();
  }

  void close() {
    currentId = -1;
    album = '';
    randomMode = false;
    playlist = ConcatenatingAudioSource(children: []);
    player.stop();
    JwLifeView.toggleAudioWidgetVisibility(false);
  }
}
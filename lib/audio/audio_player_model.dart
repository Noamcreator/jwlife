import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';

import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_media.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart' as realm_catalog;
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:realm/realm.dart';

import '../app/jwlife_app.dart';
import '../app/jwlife_view.dart';
import '../data/databases/Audio.dart';

class JwAudioPlayer {
  int? currentId;
  AudioPlayer player = AudioPlayer();
  ConcatenatingAudioSource playlist = ConcatenatingAudioSource(children: []);
  String album = '';
  Publication? publication;
  String query = '';
  bool randomMode = false;

  Future<void> fetchAudioData(realm_catalog.MediaItem mediaItem) async {
    String lank = mediaItem.languageAgnosticNaturalKey!;
    String lang = mediaItem.languageSymbol!;

    if (lank.isNotEmpty && lang.isNotEmpty) {
      album = '';
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank';
      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          album = RealmLibrary.realm.all<realm_catalog.Category>().query("key == '${mediaItem.primaryCategory}'").first.localizedName!;

          Audio audio = Audio.fromJson(data['media'][0]);
          audio.imagePath = mediaItem.realmImages!.squareFullSizeImageUrl ?? mediaItem.realmImages!.squareImageUrl ?? '';
          setPlaylist([audio]);
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

  Future<void> fetchAudiosCategoryData(realm_catalog.Category category, List<realm_catalog.MediaItem> filteredAudios, {int? id}) async {
    List<Audio> audios = [];

    if(album != category.localizedName) {
      album = category.localizedName!;
      String languageSymbol = JwLifeApp.settings.currentLanguage.symbol;

      if(await hasInternetConnection()) {
        // URL de l'API
        final url = 'https://b.jw-cdn.org/apis/mediator/v1/categories/$languageSymbol/${category.key}?detailed=1&mediaLimit=0';

        print('URL: $url');

        // Requête HTTP pour récupérer le JSON
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          // Conversion de la réponse en JSON
          final jsonData = json.decode(response.body);
          bool onlineIsNotEmpty = jsonData['category'] != null && jsonData['category']['media'] != null;

          for (int i = 0; i < filteredAudios.length; i++) {
            realm_catalog.MediaItem mediaItem = filteredAudios[i];

            Audio? localAudio = JwLifeApp.mediaCollections.getAudioFromMediaItem(mediaItem);

            if (localAudio != null) {
              audios.add(localAudio);
            }
            else {
              if (onlineIsNotEmpty) {
                if (jsonData['category']['media'][i]['naturalKey'] != null) {
                  Audio audio = Audio.fromJson(jsonData['category']['media'][i]);
                  audio.imagePath = mediaItem.realmImages!.squareFullSizeImageUrl ?? mediaItem.realmImages!.squareImageUrl ?? '';
                  audios.add(audio);
                }
              }
            }
          }

          setPlaylist(audios, id: id);
        }
      }
      else {
        setPlaylist(JwLifeApp.mediaCollections.getAudiosFromCategory(category), id: id);
      }
    }
    else {
      player.seek(Duration.zero, index: id);
    }
  }

  Future<void> setPlaylist(List<Audio> audios, {Publication? pub, int? id = 0, Duration? position = Duration.zero}) async {
    if(pub == null || pub != publication) {
      int mediaId = 0;

      List<AudioSource> children = [];

      publication = pub;

      for (var audio in audios) {
        if (audio.isDownloaded) {
          AudioMetadata metadata = readMetadata(File(audio.filePath), getImage: true);

          children.add(AudioSource.file(
            audio.filePath,
            tag: MediaItem(
              id: '${mediaId++}',
              album: metadata.album,
              title: metadata.title!,
              artUri: Uri.file(audio.imagePath),
            ),
          ));
        }
        else if (pub != null) {
          children.add(AudioSource.uri(
            Uri.parse(audio.fileUrl),
            tag: MediaItem(
              id: '${mediaId++}',
              album: pub.title,
              title: audio.title,
              artUri: pub.imageSqr != null ? Uri.file(pub.imageSqr!) : Uri.parse(''),
            ),
          ));
        }
        else {
          String image = (await ImageDatabase.getOrDownloadImage(audio.imagePath))!.path;

          children.add(AudioSource.uri(
            Uri.parse(audio.fileUrl),
            tag: MediaItem(
              id: '${mediaId++}',
              album: album,
              title: audio.title,
              artUri: Uri.file(image),
            ),
          ));
        }
      }

      playlist = ConcatenatingAudioSource(children: children);

      // Configuration de l'audio player
      player.setAudioSource(playlist, initialIndex: id, initialPosition: position);
    }
    else {
      player.seek(position, index: id);
    }
  }

  Future<void> playAudio(realm_catalog.MediaItem mediaItem, {Audio? localAudio}) async {
    History.insertAudio(mediaItem);

    if(localAudio != null) {
      setPlaylist([localAudio]);
    }
    else {
      await fetchAudioData(mediaItem);
    }
    play();
  }

  Future<void> playAudiosCategory(realm_catalog.Category category, List<realm_catalog.MediaItem> filteredAudios, {int id = 0, bool randomMode = false}) async {
    History.insertAudio(filteredAudios[id]);

    setRandomMode(randomMode);
    await fetchAudiosCategoryData(category, filteredAudios, id: id);
    play();
  }

  /*
  void setLanguagePlaylist(ConcatenatingAudioSource playlist, album, {int? id}) {
    this.album = album;
    this.playlist = playlist;
    player.setAudioSource(this.playlist, initialIndex: id ?? 0);
  }

   */

  void setId(int? id) {
    currentId = id;
  }

  void setRandomMode(bool randomMode) {
    if (this.randomMode == randomMode) return;
    this.randomMode = randomMode;
    player.setShuffleModeEnabled(randomMode);
  }

  Future<void> play({Duration? start}) async {
    if (start != null) await player.seek(start);
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
    currentId = null;
    album = '';
    randomMode = false;
    player.stop();
    playlist = ConcatenatingAudioSource(children: []);
    JwLifeView.toggleAudioWidgetVisibility(false);
  }
}
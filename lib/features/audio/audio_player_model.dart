import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';

import 'package:just_audio/just_audio.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/tiles_cache.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/realm/catalog.dart' as realm_catalog;
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:realm/realm.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../core/api.dart';
import '../../data/models/audio.dart';

class JwLifeAudioPlayer {
  int? currentId;
  AudioPlayer player = AudioPlayer();
  String album = '';
  Publication? publication;
  String query = '';
  bool randomMode = false;

  bool isSettingPlaylist = false;

  Future<void> fetchAudioData(realm_catalog.MediaItem mediaItem) async {
    String lank = mediaItem.languageAgnosticNaturalKey!;
    String lang = mediaItem.languageSymbol!;

    if (lank.isNotEmpty && lang.isNotEmpty) {
      album = '';
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank';
      try {
        final response = await Api.httpGetWithHeaders(apiUrl);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          album = RealmLibrary.realm.all<realm_catalog.Category>().query("key == '${mediaItem.primaryCategory}'").first.localizedName!;

          Audio audio = Audio.fromJson(data['media'][0]);
          audio.imagePath = mediaItem.realmImages!.squareFullSizeImageUrl ?? mediaItem.realmImages!.squareImageUrl ?? '';
          await setPlaylist([audio]);
        }
        else {
          printTime('Loading error: ${response.statusCode}');
        }
      }
      catch (e) {
        printTime('An exception occurred: $e');
      }
    }
    else {
      printTime('Lank or lang parameters are missing in the URL.');
    }
  }

  Future<void> fetchAudiosCategoryData(realm_catalog.Category category, List<realm_catalog.MediaItem> filteredAudios, {int? id}) async {
    List<Audio> audios = [];

    if(album != category.localizedName) {
      album = category.localizedName!;
      String languageSymbol = JwLifeSettings().currentLanguage.symbol;

      if(await hasInternetConnection()) {
        // URL de l'API
        final url = 'https://b.jw-cdn.org/apis/mediator/v1/categories/$languageSymbol/${category.key}?detailed=1&mediaLimit=0';

        printTime('URL: $url');

        // Requête HTTP pour récupérer le JSON
        final response = await Api.httpGetWithHeaders(url);

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

          await setPlaylist(audios, id: id);
        }
      }
      else {
        await setPlaylist(JwLifeApp.mediaCollections.getAudiosFromCategory(category), id: id);
      }
    }
    else {
      await player.seek(Duration.zero, index: id);
    }
  }

  Future<void> setPlaylist(List<Audio> audios, {Publication? pub, int? id = 0, Duration? position = Duration.zero, bool randomm = false}) async {
    isSettingPlaylist = true;
    randomMode = randomm;
    currentId = id;

    if (pub != null && pub == publication) {
      await player.seek(position, index: id);
    }
    else {
      List<AudioSource> audioSources = [];

      publication = pub;

      // Télécharge ou récupère les images nécessaires en parallèle
      final List<Future<Uri>> imageFutures = audios.map((audio) async {
        if (audio.isDownloaded) {
          return Uri.file(audio.imagePath);
        }
        else if (pub != null && pub.imageSqr != null) {
          return Uri.file(pub.imageSqr!);
        }
        else {
          final imageFile = await TilesCache().getOrDownloadImage(audio.imagePath);
          return Uri.file(imageFile!.file.path);
        }
      }).toList();

      // Attend que toutes les images soient prêtes
      final List<Uri> images = await Future.wait(imageFutures);

      // Ensuite, ajoute chaque audio avec son image
      for (int i = 0; i < audios.length; i++) {
        final audio = audios[i];
        final imageUri = images[i];

        AudioSource audioSource;

        if (audio.isDownloaded) {
          audioSource = AudioSource.file(
            audio.filePath,
            tag: MediaItem(
              id: '$i',
              album: audio.categoryKey,
              title: audio.title,
              artUri: imageUri,
                extras: {
                  'keySymbol': audio.keySymbol,
                  'documentId': audio.documentId,
                  'track': audio.track,
                  'mepsLanguage': audio.mepsLanguage,
                  'issueTagNumber': audio.issueTagNumber,
                }
            ),
          );
        }
        else {
          audioSource = AudioSource.uri(
            Uri.parse(audio.fileUrl),
            headers: Api.getHeaders(),
            tag: MediaItem(
                id: '$i',
                album: pub?.title ?? album,
                title: audio.title,
                artUri: imageUri,
                extras: {
                  'keySymbol': audio.keySymbol,
                  'documentId': audio.documentId,
                  'track': audio.track,
                  'mepsLanguage': audio.mepsLanguage,
                  'issueTagNumber': audio.issueTagNumber,
                  'naturalKey': audio.naturalKey
                }
            ),
          );
        }

        audioSources.add(audioSource);
      }
      DefaultShuffleOrder shuffleOrder = DefaultShuffleOrder();
      randomMode ? id != null ? shuffleOrder.shuffle(initialIndex: id) : shuffleOrder.shuffle() : shuffleOrder = DefaultShuffleOrder();
      await player.setAudioSources(audioSources, initialIndex: id, initialPosition: position, shuffleOrder: shuffleOrder);
    }
    isSettingPlaylist = false;
  }


  Future<void> playAudio(realm_catalog.MediaItem mediaItem, {Audio? localAudio}) async {
    History.insertAudioMediaItem(mediaItem);

    if(localAudio != null) {
      await setPlaylist([localAudio]);
    }
    else {
      await fetchAudioData(mediaItem);
    }
    await play();
  }

  Future<void> playAudios(realm_catalog.Category category, List<realm_catalog.MediaItem> filteredAudios, {int id = 0, bool randomMode = false}) async {
    History.insertAudioMediaItem(filteredAudios[id]);

    setRandomMode(randomMode);
    await fetchAudiosCategoryData(category, filteredAudios, id: id);
    await play();
  }

  /*
  void setLanguagePlaylist(ConcatenatingAudioSource playlist, album, {int? id}) {
    this.album = album;
    this.playlist = playlist;
    player.setAudioSource(this.playlist, initialIndex: id ?? 0);
  }

   */

  Future<void> playAudioFromLink(String link, MediaItem mediaItem, {Duration initialPosition = Duration.zero, Duration? endPosition}) async {
    await player.clearAudioSources();

    AudioSource audioSource = AudioSource.uri(
      Uri.parse(link),
      headers: Api.getHeaders(),
      tag: mediaItem,
    );

    await player.setAudioSource(audioSource, initialPosition: initialPosition);

    // Configuration de l'audio player
    player.positionStream.listen((position) async {
      if (endPosition != null && position >= endPosition && player.playing) {
        await close();
      }
    });
    await play();
  }

  Future<void> playAudioFromPublicationLink(Publication publication, List<Audio> audios, int id, Duration position) async {
    Audio audio = audios.elementAt(id);

    History.insertAudio(audio);

    setRandomMode(false);
    await setPlaylist(audios, pub: publication, id: id, position: position);
    await play();
  }

  void setId(int? id) {
    currentId = id;
  }

  Future<void> setRandomMode(bool randomMode) async {
    this.randomMode = randomMode;
  }

  Future<void> play({Duration? start}) async {
    if (start != null) await player.seek(start);
    if (!GlobalKeyService.jwLifePageKey.currentState!.audioWidgetVisible) {
      GlobalKeyService.jwLifePageKey.currentState!.toggleAudioWidgetVisibility(true);
    }
    await player.play();
  }

  void pause() {
    player.pause();
  }

  Future<void> next() async {
    await player.seekToNext();
    await player.play();
  }

  Future<void> previous() async {
    await player.seekToPrevious();
    await player.play();
  }

  Future<void> close() async {
    currentId = null;
    album = '';
    publication = null;
    randomMode = false;
    await player.clearAudioSources();
    await player.stop();
    GlobalKeyService.jwLifePageKey.currentState!.toggleAudioWidgetVisibility(false);
  }
}
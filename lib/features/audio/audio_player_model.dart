import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwlife/app/jwlife_app.dart';

import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/tiles_cache.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:realm/realm.dart';

import '../../app/services/global_key_service.dart';
import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../data/models/audio.dart';
import '../../data/realm/catalog.dart';

class JwLifeAudioPlayer {
  int? currentId;
  final player = AudioPlayer();
  RealmCategory? album;
  Publication? publication;
  String query = '';
  bool randomMode = false;

  bool isSettingPlaylist = false;

  Future<void> fetchAudioData(Audio audio) async {
    String? lank = audio.naturalKey;
    String? lang = audio.mepsLanguage ?? JwLifeSettings.instance.libraryLanguage.value.symbol;

    if(audio.fileUrl != null) {
      await setPlaylist([audio]);
    }
    if (lank != null) {
      album = null;
      final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$lang/$lank';
      try {
        final response = await Api.httpGetWithHeaders(apiUrl, responseType: ResponseType.json);

        if (response.statusCode == 200) {
          album = RealmLibrary.realm.all<RealmCategory>().query("Key == '${audio.categoryKey}' AND LanguageSymbol == '$lang'").firstOrNull;

          final apiMedia = response.data['media'][0];
          audio.imagePath = audio.networkImageSqr;
          audio.fileUrl = apiMedia['files'][0]['progressiveDownloadURL'];
          audio.lastModified = apiMedia['files'][0]['modifiedDatetime'];
          audio.bitRate = apiMedia['files'][0]['bitRate'];
          audio.duration = apiMedia['files'][0]['duration'];
          audio.mimeType = apiMedia['files'][0]['mimetype'];
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

  Future<void> fetchAudiosCategoryData(RealmCategory category, List<Audio> audios, Audio first, bool hasConnection) async {
    List<Audio> finalAudios = [];

    if(album != category || player.audioSources.length < audios.length) {
      album = category;
      String languageSymbol = category.languageSymbol ?? JwLifeSettings.instance.libraryLanguage.value.symbol;

      if(hasConnection) {
        // URL de l'API
        final url = 'https://b.jw-cdn.org/apis/mediator/v1/categories/$languageSymbol/${category.key}?detailed=1&mediaLimit=0';

        printTime('URL: $url');

        // Requête HTTP pour récupérer le JSON
        final response = await Api.httpGetWithHeaders(url, responseType: ResponseType.json);

        if (response.statusCode == 200) {
          // Conversion de la réponse en JSON
          bool onlineIsNotEmpty = response.data['category'] != null && response.data['category']['media'] != null;

          for (int i = 0; i < audios.length; i++) {
            Audio audio = audios[i];

            if (audio.isDownloadedNotifier.value) {
              finalAudios.add(audio);
            }
            else {
              final apiMedia = response.data['category']['media'][i];
              if (onlineIsNotEmpty) {
                if (apiMedia['naturalKey'] != null) {
                  audio.imagePath = audio.networkImageSqr;
                  audio.fileUrl = apiMedia['files'][0]['progressiveDownloadURL'];
                  audio.lastModified = apiMedia['files'][0]['modifiedDatetime'];
                  audio.bitRate = apiMedia['files'][0]['bitRate'];
                  audio.duration = apiMedia['files'][0]['duration'];
                  audio.mimeType = apiMedia['files'][0]['mimetype'];
                  finalAudios.add(audio);
                }
              }
            }
          }
        }
        else {
          finalAudios.addAll(audios);
        }
      }
      else {
        finalAudios.addAll(audios);
      }

      await setPlaylist(finalAudios, id: audios.indexOf(first));
    }
    else {
      await player.seek(Duration.zero, index: audios.indexOf(first));
    }
  }

  Future<void> setPlaylist(List<Audio> audios, {Publication? pub, int? id = 0, Duration? position = Duration.zero, bool random = false}) async {
    isSettingPlaylist = true;
    randomMode = random;
    currentId = id;

    if (pub != null && pub == publication) {
      await player.seek(position, index: id);
    }
    else {
      List<AudioSource> audioSources = [];

      publication = pub;

      // Télécharge ou récupère les images nécessaires en parallèle
      final List<Future<Uri>> imageFutures = audios.map((audio) async {
        if (audio.isDownloadedNotifier.value) {
          return Uri.file(audio.imagePath!);
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

        // 1. Déterminer la valeur de l'album une seule fois.
        // Cette logique complexe est maintenant factorisée.
        final String albumTitle = pub?.getTitle() ??
            (album?.name?.isNotEmpty == true
                ? album!.name!
                : RealmLibrary.realm
                .all<RealmCategory>()
                .query("Key == '${audio.categoryKey}' AND LanguageSymbol == '${audio.mepsLanguage ?? JwLifeSettings.instance.libraryLanguage.value.symbol}'",)
                .firstOrNull
                ?.name ?? '');

        final MediaItem mediaItem = MediaItem(
          id: '$i',
          album: albumTitle, // Utilise la variable factorisée
          title: audio.title.replaceAll('&nbsp;', ' '),
          artUri: imageUri,
          extras: {
            'keySymbol': audio.keySymbol,
            'documentId': audio.documentId,
            'bookNumber': audio.bookNumber,
            'track': audio.track,
            'mepsLanguage': audio.mepsLanguage,
            'issueTagNumber': audio.issueTagNumber,
            'stream': !audio.isDownloadedNotifier.value,
          },
        );

        if (audio.isDownloadedNotifier.value) {
          audioSource = AudioSource.file(
            audio.filePath!,
            tag: mediaItem,
          );
        }
        else {
          audioSource = AudioSource.uri(
            Uri.parse(audio.fileUrl!),
            headers: Api.getHeaders(),
            tag: mediaItem,
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


  Future<void> playAudio(Audio audio, {Duration initialPosition = Duration.zero}) async {
    JwLifeApp.history.insertAudio(audio);

    if(audio.isDownloadedNotifier.value) {
      await setPlaylist([audio]);
    }
    else {
      await fetchAudioData(audio);
    }
    await play(initialPosition: initialPosition);
  }

  Future<void> playAudios(RealmCategory category, List<Audio> audios, {Audio? first, bool randomMode = false}) async {
    if(audios.isEmpty) return;
    final downloadedAudios = audios.where((element) => element.isDownloadedNotifier.value).toList();

    if(await hasInternetConnection(context: downloadedAudios.isEmpty || (first != null && !downloadedAudios.contains(first)) ? GlobalKeyService.jwLifePageKey.currentContext : null, type: 'stream')) {
      Audio firstAudio = first ?? audios.first;

      if(randomMode) {
        firstAudio = audios[Random().nextInt(audios.length)];
      }

      JwLifeApp.history.insertAudio(firstAudio);

      setRandomMode(randomMode);
      await fetchAudiosCategoryData(category, audios, firstAudio, true);
      await play();
    }
    else if (downloadedAudios.isNotEmpty) {
      Audio firstAudio = first ?? downloadedAudios.first;

      if(!downloadedAudios.contains(firstAudio)) return;

      if(randomMode) {
        firstAudio = downloadedAudios[Random().nextInt(downloadedAudios.length)];
      }

      JwLifeApp.history.insertAudio(firstAudio);

      setRandomMode(randomMode);
      await fetchAudiosCategoryData(category, downloadedAudios, firstAudio, false);
      await play();
    }
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

  Future<void> playAudioFromPublicationLink(Publication publication, int id, Duration position) async {
    Audio audio = publication.audiosNotifier.value.elementAt(id);

    JwLifeApp.history.insertAudio(audio);

    setRandomMode(false);
    await setPlaylist(publication.audiosNotifier.value, pub: publication, id: id, position: position);
    await play();
  }

  void setId(int? id) {
    currentId = id;
  }

  Future<void> setRandomMode(bool randomMode) async {
    this.randomMode = randomMode;
    player.setShuffleModeEnabled(randomMode);
  }

  Future<void> play({Duration? initialPosition}) async {
    if (initialPosition != null) await player.seek(initialPosition);
    if (!GlobalKeyService.jwLifePageKey.currentState!.audioWidgetVisible.value) {
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
    album = null;
    publication = null;
    randomMode = false;
    await player.clearAudioSources();
    await player.stop();
    GlobalKeyService.jwLifePageKey.currentState!.toggleAudioWidgetVisibility(false);
  }
}
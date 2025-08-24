import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/app/startup/create_database.dart';
import 'package:jwlife/app/startup/splash_screen.dart';
import 'package:jwlife/core/bible_clues_info.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/constants.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/assets_downloader.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/databases/media_collections.dart';
import 'package:jwlife/data/databases/mepsunit.dart';
import 'package:jwlife/data/databases/pub_collections.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/userdata.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/i18n/app_localizations.dart';
import 'package:realm/realm.dart';

import '../core/shared_preferences/shared_preferences_utils.dart';
import '../core/utils/common_ui.dart';
import '../data/databases/tiles_cache.dart';
import '../data/repositories/PublicationRepository.dart';
import '../features/audio/audio_player_model.dart';
import '../features/bible/pages/local_bible_chapter.dart';
import '../features/home/pages/daily_text_page.dart';
import '../features/publication/pages/document/local/document_page.dart';
import 'jwlife_page.dart';
import 'startup/copy_assets.dart';

class JwLifeApp extends StatefulWidget {
  static late PubCollections pubCollections;
  static late MediaCollections mediaCollections;
  static late Userdata userdata;
  static late JwLifeAudioPlayer audioPlayer;
  static late BibleCluesInfo bibleCluesInfo;

  JwLifeApp({super.key}) {
    pubCollections = PubCollections();
    mediaCollections = MediaCollections();
    userdata = Userdata();
    audioPlayer = JwLifeAudioPlayer();
    bibleCluesInfo = BibleCluesInfo(bibleBookNames: []);
  }

  @override
  State<JwLifeApp> createState() => JwLifeAppState();
}

class JwLifeAppState extends State<JwLifeApp> {
  bool initialized = false;
  ThemeMode _themeMode = JwLifeSettings().themeMode;
  ThemeData _lightTheme = JwLifeSettings().lightData;
  ThemeData _darkTheme = JwLifeSettings().darkData;
  Locale _locale = JwLifeSettings().locale;

  @override
  void initState() {
    super.initState();

    initializeData().then((_) {
      setState(() {
        initialized = true;
      });
    });
  }

  void toggleTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    JwLifeSettings().themeMode = themeMode;
    JwLifeSettings().webViewData.updateTheme(themeMode);
    final theme = themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.light ? 'light' : 'system';
    setTheme(theme);
  }

  Future<void> togglePrimaryColor(Color color) async {
    setState(() {
      _lightTheme = AppTheme.getLightTheme(color);
      _darkTheme = AppTheme.getDarkTheme(color);
    });
    JwLifeSettings().lightData = AppTheme.getLightTheme(color);
    JwLifeSettings().darkData = AppTheme.getDarkTheme(color);

    JwLifeSettings().lightPrimaryColor = color;
    JwLifeSettings().darkPrimaryColor = color;

    setPrimaryColor(JwLifeSettings().themeMode, color);

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changePrimaryColor(color, color);
        }
        else if (state is DailyTextPageState) {
          state.changePrimaryColor(color, color);
        }
      }
    }
  }

  void changeLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    JwLifeSettings().locale = locale;
    setLocale(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: initialized ? JwLifePage(key: GlobalKeyService.jwLifePageKey) : const SplashScreen()
    );
  }

  Future<void> initializeData() async {
    printTime('Start: PublicationCategory.initializeCategories');
    PublicationCategory.initialize();
    PublicationAttribute.initialize();
    printTime('End: PublicationCategory.initializeCategories');

    printTime('Start: Initializing database...');
    await Future.wait([
      CreateDatabase.create(),
      CopyAssets.copy(),
    ]);
    printTime('End: Initializing database...');

    printTime('Start: Initializing collections...');
    await Future.wait([
      JwLifeApp.pubCollections.init(),
      JwLifeApp.mediaCollections.init(),
      TilesCache().init(),
    ]);
    printTime('End: Initializing collections...');

    await JwLifeApp.userdata.init();
    JwLifeSettings().webViewData.init();

    printTime('Start: Copying assets, downloading, loading homepage, and fetching API data...');
    final futures = <Future>[
      PubCatalog.loadPublicationsInHomePage()
    ];

    if (await hasInternetConnection()) {
      futures.addAll([
        Api.fetchCurrentVersion(),
        Api.fetchCurrentJwToken(),
      ]);
    }

    await Future.wait(futures);

    printTime('End: Copying assets, downloading, loading homepage, and fetching API data...');
    AssetsDownload.download();
  }

  Future<void> handleUri(JwOrgUri uri) async {
    final ctx = GlobalKeyService.homeKey.currentState!.context;

    try {
      if (uri.isPublication) {
        Publication? publication = await PubCatalog.searchPub(uri.pub!, uri.issue!, uri.wtlocale);
        if (publication != null) {
          GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0);
          publication.showMenu(ctx);
        }
      }
      else if (uri.isDocument) {
        int? mepsLanguageId = await Mepsunit.getMepsLanguageIdFromSymbol(uri.wtlocale);
        if (mepsLanguageId == null) return;

        int startParagraphId;
        int endParagraphId;

        final parStr = uri.par!; // ex: "4" ou "4-6"

        if (parStr.contains('-')) {
          final parts = parStr.split('-');
          startParagraphId = int.parse(parts[0]);
          endParagraphId = int.parse(parts[1]);
        } else {
          startParagraphId = int.parse(parStr);
          endParagraphId = startParagraphId;
        }

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0);

        showDocumentView(
          ctx,
          uri.docid!,
          mepsLanguageId,
          startParagraphId: startParagraphId,
          endParagraphId: endParagraphId,
        );
      }
      else if (uri.isBibleBook) {
        BuildContext bibleContext = GlobalKeyService.bibleKey.currentState!.context;
        Publication? biblePub = GlobalKeyService.bibleKey.currentState!.currentBible;
        if (biblePub == null) return;

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(1);

        showPage(bibleContext,
            LocalChapterBiblePage(
            bible: biblePub,
            book: uri.book!
        ));
      }
      else if (uri.isBibleChapter) {
        String bibleStr = uri.bible!; // ex: "01003015" ou "01003000-01003999"

        int bibleBook;
        int bibleChapter;
        int firstVerse;
        int lastVerse;

        if (bibleStr.contains('-')) {
          // Plage de versets
          final parts = bibleStr.split('-');
          final start = int.parse(parts[0]);
          final end = int.parse(parts[1]);

          bibleBook = start ~/ 1000000;
          bibleChapter = (start ~/ 1000) % 1000;
          firstVerse = start % 1000;
          lastVerse = end % 1000;
        }
        else {
          // Verset unique
          final value = int.parse(bibleStr);
          bibleBook = value ~/ 1000000;
          bibleChapter = (value ~/ 1000) % 1000;
          firstVerse = value % 1000;
          lastVerse = firstVerse;
        }

        BuildContext bibleContext = GlobalKeyService.bibleKey.currentState!.context;
        Publication? biblePub = GlobalKeyService.bibleKey.currentState!.currentBible;
        if (biblePub == null) return;

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(1);

        showPageBibleChapter(
          bibleContext,
          biblePub,
          bibleBook,
          bibleChapter,
          firstVerse: firstVerse,
          lastVerse: lastVerse,
        );
      }
      else if (uri.isMediaItem) {
        Duration startTime = Duration.zero;
        Duration? endTime;

        if (uri.ts != null && uri.ts!.isNotEmpty) {
          final parts = uri.ts!.split('-');
          if (parts.isNotEmpty) {
            startTime = JwOrgUri.parseDuration(parts[0]) ?? Duration.zero;
          }
          if (parts.length > 1) {
            endTime = JwOrgUri.parseDuration(parts[1]);
          }
        }

        MediaItem mediaItem = getMediaItemFromLank(uri.lank!, uri.wtlocale);

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0);
        if(mediaItem.type == 'AUDIO') {
          showAudioPlayer(ctx, mediaItem, initialPosition: startTime);
        }
        else {
          showFullScreenVideo(ctx, mediaItem, initialPosition: startTime);
        }
      }
      else if (uri.isDailyText) {
        BuildContext homeContext = GlobalKeyService.homeKey.currentState!.context;
        final date = (uri.date == null || uri.date == 'today') ? DateTime.now() : DateTime.parse(uri.date!);

        List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: date);

        // Si Publication a un champ 'id' ou 'symbol' à tester
        Publication? dailyTextPub = dayPubs.firstWhereOrNull((p) => p.symbol.contains('es')); // ou p.symbol, p.title, etc.

        if (dailyTextPub == null) return;

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0);
        showPageDailyText(homeContext, dailyTextPub, date: date);
      }
      else if (uri.isMeetings) {
        final date = (uri.date == null) ? DateTime.now() : DateTime.parse(uri.date!);

        List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: date);

        GlobalKeyService.meetingsKey.currentState!.refreshMeetingsPubs(publications: dayPubs);
        GlobalKeyService.meetingsKey.currentState!.refreshSelectedDay(date);

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(3);
      }
    }
    catch (e) {
      print('Erreur parsing JwLifeUri: $e');
    }
  }
}
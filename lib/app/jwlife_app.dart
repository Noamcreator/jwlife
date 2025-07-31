import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/app/startup/create_database.dart';
import 'package:jwlife/app/startup/splash_screen.dart';
import 'package:jwlife/core/bible_clues_info.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/constants.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/assets_downloader.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/media_collections.dart';
import 'package:jwlife/data/databases/pub_collections.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/databases/userdata.dart';
import 'package:jwlife/features/publication/pages/document/local/dated_text_manager.dart';
import 'package:jwlife/i18n/app_localizations.dart';

import '../data/databases/tiles_cache.dart';
import '../features/audio/audio_player_model.dart';
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
  bool _initialized = false;
  ThemeMode _themeMode = JwLifeSettings().themeMode;
  ThemeData _lightTheme = JwLifeSettings().lightData;
  ThemeData _darkTheme = JwLifeSettings().darkData;
  Locale _locale = JwLifeSettings().locale;

  @override
  void initState() {
    super.initState();

    initializeData().then((_) {
      setState(() {
        _initialized = true;
      });
    });
  }

  void toggleTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    JwLifeSettings().themeMode = themeMode;
    JwLifeSettings().webViewData.update(themeMode);
    final theme = themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.light ? 'light' : 'system';
    setTheme(theme);

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.changeTheme(themeMode);
        }
        else if (state is DailyTextPageState) {
          state.changeTheme(themeMode);
        }
      }
    }
  }

  Future<void> togglePrimaryColor(Color color) async {
    setState(() {
      _lightTheme = AppTheme.getLightTheme(color);
      _darkTheme = AppTheme.getDarkTheme(color);
    });
    JwLifeSettings().lightData = AppTheme.getLightTheme(color);
    JwLifeSettings().darkData = AppTheme.getDarkTheme(color);
    setPrimaryColor(JwLifeSettings().themeMode, color);
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
      home: _initialized ? JwLifePage(key: GlobalKeyService.jwLifePageKey) : const SplashScreen()
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
      CopyAssets.copy()
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
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:jwlife/i18n/app_localizations.dart';

import '../data/databases/tiles_cache.dart';
import '../features/audio/audio_player_model.dart';
import 'jwlife_page.dart';
import 'startup/copy_assets.dart';

class JwLifeApp extends StatefulWidget {
  static late Function(Color) togglePrimaryColor;

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
  State<JwLifeApp> createState() => _JwLifeAppState();
}

class _JwLifeAppState extends State<JwLifeApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    JwLifeApp.togglePrimaryColor = _togglePrimaryColor;

    initializeData().then((_) {
      setState(() {
        _initialized = true;
      });
    });
  }

  Future<void> _togglePrimaryColor(Color color) async {
    setState(() {
      JwLifeSettings().lightData = AppTheme.getLightTheme(color);
      JwLifeSettings().darkData = AppTheme.getDarkTheme(color);
    });
    setPrimaryColor(JwLifeSettings().themeMode, color);
  }

  void _toggleTheme(ThemeMode themeMode) {
    setState(() {
      JwLifeSettings().themeMode = themeMode;
    });
    JwLifeSettings().webViewData.update(themeMode);
    final theme = themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.light ? 'light' : 'system';
    setTheme(theme);
  }

  void _changeLocale(Locale locale) {
    setState(() {
      JwLifeSettings().locale = locale;
    });
    setLocale(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: JwLifeSettings().themeMode,
      theme: JwLifeSettings().lightData,
      darkTheme: JwLifeSettings().darkData,
      locale: JwLifeSettings().locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _initialized
          ? JwLifePage(
        toggleTheme: _toggleTheme,
        changeLocale: _changeLocale,
      )
          : AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
        ),
        child: const SplashScreen(),
      ),
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
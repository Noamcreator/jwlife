import 'dart:io';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jw_settings.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/app/startup/create_database.dart';
import 'package:jwlife/app/startup/splash_screen.dart';
import 'package:jwlife/audio/audio_player_model.dart';
import 'package:jwlife/core/BibleCluesInfo.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/constants.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/assets_downloader.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/MediaCollections.dart';
import 'package:jwlife/data/databases/PubCollections.dart';
import 'package:jwlife/data/databases/PublicationCategory.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/userdata/Userdata.dart';
import 'package:jwlife/i18n/app_localizations.dart';

import '../core/utils/files_helper.dart';
import '../data/databases/TilesCache.dart';
import 'jwlife_view.dart';
import 'startup/copy_assets.dart';

class JwLifeApp extends StatefulWidget {
  static late Function(Color) togglePrimaryColor;

  static JwSettings settings = JwSettings();
  static PubCollections pubCollections = PubCollections();
  static MediaCollections mediaCollections = MediaCollections();
  static TilesCache tilesCache = TilesCache();
  static Userdata userdata = Userdata();
  static JwAudioPlayer jwAudioPlayer = JwAudioPlayer();
  static BibleCluesInfo bibleCluesInfo = BibleCluesInfo(bibleBookNames: []);
  static List<PublicationCategory> categories = []; // Initialise une catégorie vide

  // Le constructeur prend settings comme paramètre nommé
  const JwLifeApp({super.key});

  @override
  _JwLifeAppState createState() => _JwLifeAppState();
}

class _JwLifeAppState extends State<JwLifeApp> {
  BeamerDelegate? routerDelegate; // Change to nullable

  @override
  void initState() {
    super.initState();

    JwLifeApp.togglePrimaryColor = _togglePrimaryColor;

    initializeData().then((_) {
      setState(() {
        routerDelegate = BeamerDelegate(
          initialPath: '/home',
          locationBuilder: RoutesLocationBuilder(
            routes: {
              '*': (context, state, data) => JwLifeView(
                toggleTheme: _toggleTheme,
                changeLocale: _changeLocale,
              ),
            },
          ).call,
        );
      });
    });
  }

  Future<void> _togglePrimaryColor(Color color) async {
    setState(() {
      JwLifeApp.settings.lightData = AppTheme.getLightTheme(color);
      JwLifeApp.settings.darkData = AppTheme.getDarkTheme(color);
    });
    setPrimaryColor(JwLifeApp.settings.themeMode, color);
  }

  void _toggleTheme(ThemeMode themeMode) {
    setState(() {
      JwLifeApp.settings.themeMode = themeMode;
    });
    JwLifeApp.settings.webViewData.update(themeMode);
    final theme = themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.light ? 'light' : 'system';
    setTheme(theme);
  }

  void _changeLocale(Locale locale) {
    setState(() {
      JwLifeApp.settings.locale = locale;
    });
    setLocale(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    if (routerDelegate == null) {
      // Show a placeholder while the routerDelegate is being initialized
      return MaterialApp(
        title: Constants.appName,
        debugShowCheckedModeBanner: false,
        themeMode: JwLifeApp.settings.themeMode,
        theme: JwLifeApp.settings.lightData,
        darkTheme: JwLifeApp.settings.darkData,
        home: Scaffold(
          body: SplashScreen()
        ),
      );
    }

    // Once initialized, build the app with the router
    return MaterialApp.router(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: JwLifeApp.settings.themeMode,
      theme: JwLifeApp.settings.lightData,
      darkTheme: JwLifeApp.settings.darkData,
      locale: JwLifeApp.settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerDelegate: routerDelegate!,
      routeInformationParser: BeamerParser(),
      backButtonDispatcher: BeamerBackButtonDispatcher(
        delegate: routerDelegate!,
      ),
    );
  }

  Future<void> initializeData() async {
    printTime('Start: PublicationCategory.initializeCategories');
    PublicationCategory.initializeCategories();
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
      JwLifeApp.tilesCache.init(),
      JwLifeApp.userdata.init(),
    ]);
    printTime('End: Initializing collections...');

    printTime('Start: Copying assets, downloading, loading homepage, and fetching API data...');

    final futures = <Future>[
      AssetsDownload.download(),
      JwLifeApp.settings.webViewData.init(),
      PubCatalog.loadHomePage(),
    ];

    if (await hasInternetConnection()) {
      futures.addAll([
        Api.fetchCurrentVersion(),
        Api.fetchCurrentJwToken(),
      ]);
    }

    await Future.wait(futures);

    printTime('End: Copying assets, downloading, loading homepage, and fetching API data...');
  }
}
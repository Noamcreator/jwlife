import 'dart:io';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:jwlife/data/databases/PublicationAttribute.dart';
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

  // Champs statiques modifiables plus tard
  static late JwSettings settings;
  static late PubCollections pubCollections;
  static late MediaCollections mediaCollections;
  static late TilesCache tilesCache;
  static late Userdata userdata;
  static late JwAudioPlayer jwAudioPlayer;
  static late BibleCluesInfo bibleCluesInfo;

  // Constructeur
  JwLifeApp(JwSettings jwSettings, {super.key}) {
    settings = jwSettings;
    pubCollections = PubCollections();
    mediaCollections = MediaCollections();
    tilesCache = TilesCache();
    userdata = Userdata();
    jwAudioPlayer = JwAudioPlayer();
    bibleCluesInfo = BibleCluesInfo(bibleBookNames: []);
  }

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
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.white,
          ),
          child: Scaffold(
            body: SplashScreen(),
          ),
        )
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
      routeInformationParser: BeamerParser(),
      routerDelegate: routerDelegate!,
      backButtonDispatcher: BeamerBackButtonDispatcher(fallbackToBeamBack: false, delegate: routerDelegate!),
    );
  }

  Future<void> initializeData() async {
    printTime('Start: PublicationCategory.initializeCategories');
    PublicationCategory.initializeCategories();
    PublicationAttribute.initializeAttributes();
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
      //JwLifeApp.mediaCollections.init(),
      JwLifeApp.tilesCache.init(),
    ]);
    printTime('End: Initializing collections...');

    await JwLifeApp.userdata.init();

    JwLifeApp.settings.webViewData.init();

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
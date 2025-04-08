import 'dart:io';

import 'package:beamer/beamer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/startup/create_database.dart';
import 'package:jwlife/app/startup/splash_screen.dart';
import 'package:jwlife/audio/audio_player_model.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/core/constants.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/webview_data.dart';
import 'package:jwlife/data/meps/language.dart';
import 'package:jwlife/data/userdata/Userdata.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'jwlife_view.dart';
import 'startup/copy_assets.dart';

class JwLifeApp extends StatefulWidget {
  static late Function(Color) togglePrimaryColor;

  static ThemeMode theme = ThemeMode.system;
  static ThemeData lightData = AppTheme.getLightTheme(Color(0xFF295568));
  static ThemeData darkData = AppTheme.getDarkTheme(Color.lerp(Color(0xFF295568), Colors.white, 0.3)!);
  static Locale locale = Locale('en');
  static JwAudioPlayer jwAudioPlayer = JwAudioPlayer();
  static Userdata userdata = Userdata();
  static MepsLanguage currentLanguage = MepsLanguage(id: 3, symbol: 'F', vernacular: 'Français', primaryIetfCode: 'fr', rsConf: 'r30', lib: 'lp-f');
  static WebViewData webviewData = WebViewData();
  static List<dynamic> bibles = [];

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
      JwLifeApp.lightData = AppTheme.getLightTheme(color);
      JwLifeApp.darkData = AppTheme.getDarkTheme(color);
    });
    setPrimaryColor(JwLifeApp.theme, color);
  }

  void _toggleTheme(ThemeMode themeMode) {
    setState(() {
      JwLifeApp.theme = themeMode;
    });
    JwLifeApp.webviewData.update(themeMode);
    final theme = themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.light ? 'light' : 'system';
    setTheme(theme);
  }

  void _changeLocale(Locale locale) {
    setState(() {
      JwLifeApp.locale = locale;
    });
    setLocale(locale.languageCode);
  }

  Future<void> loadBibles() async {
    File pubCollectionsFile = await getPubCollectionsFile();

    if (await pubCollectionsFile.exists()) {
      Database pubCollectionsDB = await openReadOnlyDatabase(pubCollectionsFile.path);

      List<Map<String, dynamic>> result = await pubCollectionsDB.rawQuery('''
    SELECT DISTINCT
      Publication.*
    FROM 
      Publication
    WHERE Publication.PublicationCategorySymbol = 'bi'
''');

      JwLifeApp.bibles = result;

      pubCollectionsDB.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (routerDelegate == null) {
      // Show a placeholder while the routerDelegate is being initialized
      return MaterialApp(
        title: Constants.appName,
        debugShowCheckedModeBanner: false,
        themeMode: JwLifeApp.theme,
        theme: JwLifeApp.lightData,
        darkTheme: JwLifeApp.darkData,
        home: Scaffold(
          body: SplashScreen()
        ),
      );
    }

    // Once initialized, build the app with the router
    return MaterialApp.router(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: JwLifeApp.theme,
      theme: JwLifeApp.lightData,
      darkTheme: JwLifeApp.darkData,
      locale: JwLifeApp.locale,
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
    sqfliteFfiInit();
    await CopyAssets.copy();
    await CreateDatabase.create();
    await JwLifeApp.userdata.init();
    await JwLifeApp.webviewData.init(JwLifeApp.theme);
    await loadBibles();

    if (await hasInternetConnection()) {
      await Api.fetchCurrentVersion();
      await Api.fetchCurrentJwToken();
    }
  }
}
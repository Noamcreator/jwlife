import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/app/startup/splash_screen.dart';
import 'package:jwlife/core/bible_clues_info.dart';
import 'package:jwlife/core/constants.dart';
import 'package:jwlife/core/ui/theme.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/controller/block_ranges_controller.dart';
import 'package:jwlife/data/controller/tags_controller.dart';
import 'package:jwlife/data/databases/media_collections.dart';
import 'package:jwlife/data/databases/pub_collections.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/userdata.dart';
import 'package:provider/provider.dart';

import '../core/shared_preferences/shared_preferences_utils.dart';
import '../data/controller/notes_controller.dart';
import '../data/databases/tiles_cache.dart';
import '../features/audio/audio_player_model.dart';
import '../features/document/local/document_page.dart';
import '../features/home/pages/daily_text_page.dart';
import '../i18n/localization.dart';
import 'jwlife_page.dart';

class _JwLifePageContainer extends StatelessWidget {
  const _JwLifePageContainer();

  @override
  Widget build(BuildContext context) {
    return JwLifePage(key: GlobalKeyService.jwLifePageKey);
  }
}

class JwLifeApp extends StatefulWidget {
  static final PubCollections pubCollections = PubCollections();
  static final MediaCollections mediaCollections = MediaCollections();
  static final Userdata userdata = Userdata();
  static final JwLifeAudioPlayer audioPlayer = JwLifeAudioPlayer();
  static BibleCluesInfo bibleCluesInfo = BibleCluesInfo(bibleBookNames: []);

  const JwLifeApp({super.key});

  @override
  State<JwLifeApp> createState() => JwLifeAppState();
}

class JwLifeAppState extends State<JwLifeApp> {
  final ValueNotifier _initialized = ValueNotifier(false);
  ThemeMode _themeMode = JwLifeSettings.instance.themeMode;
  ThemeData _lightTheme = JwLifeSettings.instance.lightData;
  ThemeData _darkTheme = JwLifeSettings.instance.darkData;
  Locale _locale = JwLifeSettings.instance.locale;

  @override
  void initState() {
    super.initState();

    // Lancement de l'initialisation des données
    initializeData();
  }

  @override
  void didChangeDependencies() {
    // Mettre à jour le webView si ThemeMode.system est actif et que la luminosité effective change.
    if (_themeMode == ThemeMode.system && _initialized.value) {
      final currentResolvedBrightness = MediaQuery.of(context).platformBrightness;
      bool isDark = currentResolvedBrightness == Brightness.dark;
      String theme = isDark ? 'dark' : 'light';

      if(JwLifeSettings.instance.webViewData.theme != theme) {
        JwLifeSettings.instance.webViewData.updateTheme(isDark);
      }
    }

    super.didChangeDependencies();
  }

  // --- Gestion du Thème et de la Couleur ---

  void toggleTheme(ThemeMode themeMode) {
    JwLifeSettings.instance.themeMode = themeMode;

    // Calculer la Brightness effective pour le web view.
    final Brightness resolvedBrightness = (themeMode == ThemeMode.system) ? MediaQuery.of(context).platformBrightness : (themeMode == ThemeMode.light ? Brightness.light : Brightness.dark);

    bool isDark = resolvedBrightness == Brightness.dark;

    JwLifeSettings.instance.themeMode = themeMode;
    JwLifeSettings.instance.webViewData.updateTheme(isDark);

    final theme = themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.light ? 'light' : 'system';
    AppSharedPreferences.instance.setTheme(theme);

    setState(() {
      _themeMode = themeMode;
    });
  }

  Future<void> togglePrimaryColor(Color color) async {
    final newLightTheme = AppTheme.getLightTheme(color);
    final newDarkTheme = AppTheme.getDarkTheme(color);

    setState(() {
      _lightTheme = newLightTheme;
      _darkTheme = newDarkTheme;
    });

    // Mise à jour de la persistance et des données de thème en une seule fois
    JwLifeSettings.instance
      ..lightData = newLightTheme
      ..darkData = newDarkTheme
      ..lightPrimaryColor = color
      ..darkPrimaryColor = color;

    await AppSharedPreferences.instance.setPrimaryColor(JwLifeSettings.instance.themeMode, color);

    // Notification des widgets via GlobalKey (à refactoriser idéalement avec Provider/InheritedWidget)
    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;
        if (state is DocumentPageState) {
          state.changePrimaryColor(color, color);
        } else if (state is DailyTextPageState) {
          state.changePrimaryColor(color, color);
        }
      }
    }
  }

  Future<void> toggleBibleColor(Color color) async {
    JwLifeSettings.instance.bibleColor = color;
    await AppSharedPreferences.instance.setBibleColor(color);

    // Mise à jour de la page Bible si elle est affichée
    GlobalKeyService.bibleKey.currentState?.refreshColor();
  }

  void changeLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    JwLifeSettings.instance.locale = locale;
    AppSharedPreferences.instance.setLocale(locale.languageCode);
  }

  // --- Construction de l'UI ---

  @override
  Widget build(BuildContext context) {
    printTime('Build JwLifeApp');

    return MaterialApp(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ValueListenableBuilder(
        valueListenable: _initialized,
        builder: (context, value, child) {
          if (value) {
            return MultiProvider(
                providers: [
                  ChangeNotifierProvider(create: (_) => BlockRangesController()),
                  ChangeNotifierProvider(create: (_) => NotesController()..loadNotes()),
                  ChangeNotifierProvider(create: (_) => TagsController()..loadTags()),
                ],
                child: const _JwLifePageContainer()
            );
          }
          else {
            return const SplashScreen();
          }
        },
      ),
    );
  }

  // --- Initialisation des Données ---
  Future<void> initializeData() async {
    // Étape 1 : Initialisation synchrone (rapide)
    PublicationCategory.initialize();
    PublicationAttribute.initialize();

    // Étape 2 : Initialisation asynchrone et parallèle (performance)
    await Future.wait([
      JwLifeApp.pubCollections.init(),
      JwLifeApp.mediaCollections.init(),
      TilesCache().init(),
      JwLifeApp.userdata.init()
    ]);

    // Calculer la Brightness effective pour le web view.
    final isDark = _themeMode == ThemeMode.system ? MediaQuery.of(context).platformBrightness == Brightness.dark : _themeMode == ThemeMode.dark;

    // Étape 5 : Initialisation finale
    JwLifeSettings.instance.webViewData.init(isDark);

    AppDataService.instance.loadAllContentData();
  }

  void finishInitialized() {
    _initialized.value = true;
  }
}
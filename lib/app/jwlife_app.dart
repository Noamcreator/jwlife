import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/app/startup/auto_update.dart';
import 'package:jwlife/app/startup/splash_screen.dart';
import 'package:jwlife/core/bible_clues_info.dart';
import 'package:jwlife/core/api/api.dart';
import 'package:jwlife/core/constants.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/theme.dart';
import 'package:jwlife/core/utils/assets_downloader.dart';
import 'package:jwlife/core/utils/utils.dart';
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
import 'package:jwlife/i18n/app_localizations.dart';

import '../core/shared_preferences/shared_preferences_utils.dart';
import '../core/utils/common_ui.dart';
import '../data/databases/tiles_cache.dart';
import '../data/models/audio.dart';
import '../data/models/video.dart';
import '../data/realm/catalog.dart';
import '../features/audio/audio_player_model.dart';
import '../features/bible/pages/bible_chapter_page.dart';
import '../features/home/pages/daily_text_page.dart';
import '../features/publication/pages/document/local/document_page.dart';
import 'jwlife_page.dart';
import 'startup/copy_assets.dart';

class JwLifeApp extends StatefulWidget {
  // Utilisation de 'static final' pour initialiser les dépendances
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
  bool initialized = false;
  ThemeMode _themeMode = JwLifeSettings().themeMode;
  ThemeData _lightTheme = JwLifeSettings().lightData;
  ThemeData _darkTheme = JwLifeSettings().darkData;
  Locale _locale = JwLifeSettings().locale;

  @override
  void initState() {
    super.initState();

    // Lancement de l'initialisation des données
    initializeData().then((_) {
      setState(() {
        initialized = true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    // Mettre à jour le webView si ThemeMode.system est actif et que la luminosité effective change.
    if (_themeMode == ThemeMode.system && initialized) {
      final currentResolvedBrightness = MediaQuery.of(context).platformBrightness;
      bool isDark = currentResolvedBrightness == Brightness.dark;
      String theme = isDark ? 'dark' : 'light';

      if(JwLifeSettings().webViewData.theme != theme) {
        JwLifeSettings().webViewData.updateTheme(isDark);
      }
    }

    super.didChangeDependencies();
  }

  // --- Gestion du Thème et de la Couleur ---

  void toggleTheme(ThemeMode themeMode) {

    JwLifeSettings().themeMode = themeMode;

    // Calculer la Brightness effective pour le web view.
    final Brightness resolvedBrightness = (themeMode == ThemeMode.system) ? MediaQuery.of(context).platformBrightness : (themeMode == ThemeMode.light ? Brightness.light : Brightness.dark);

    bool isDark = resolvedBrightness == Brightness.dark;

    JwLifeSettings().themeMode = themeMode;
    JwLifeSettings().webViewData.updateTheme(isDark);

    final theme = themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.light ? 'light' : 'system';
    setTheme(theme);

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
    JwLifeSettings()
      ..lightData = newLightTheme
      ..darkData = newDarkTheme
      ..lightPrimaryColor = color
      ..darkPrimaryColor = color;

    await setPrimaryColor(JwLifeSettings().themeMode, color);

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
    JwLifeSettings().bibleColor = color;
    await setBibleColor(color);

    // Mise à jour de la page Bible si elle est affichée
    GlobalKeyService.bibleKey.currentState?.refreshBiblePage();
  }

  void changeLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    JwLifeSettings().locale = locale;
    setLocale(locale.languageCode);
  }

  // --- Construction de l'UI ---

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
      // Utilisation de 'const' pour SplashScreen
      home: initialized ? JwLifePage(key: GlobalKeyService.jwLifePageKey) : const SplashScreen(),
    );
  }

  // --- Initialisation des Données ---

  Future<void> initializeData() async {
    // Étape 1 : Initialisation synchrone (rapide)
    PublicationCategory.initialize();
    PublicationAttribute.initialize();

    // Étape 2 : Initialisation asynchrone et parallèle (performance)
    await Future.wait([
      CopyAssets.copy(),
      JwLifeApp.pubCollections.init(),
      JwLifeApp.mediaCollections.init(),
      TilesCache().init(),
    ]);

    // Étape 3 : Initialisation séquentielle des données utilisateur et catalogue
    await JwLifeApp.userdata.init();
    await PubCatalog.loadPublicationsInHomePage();

    // Étape 4 : Vérification de la connexion et mise à jour (performance)
    final isConnected = await hasInternetConnection();
    if (isConnected) {
      Api.fetchCurrentJwToken();
      JwLifeAutoUpdater.checkAndUpdate();
      AssetsDownload.download();
    }

    // Calculer la Brightness effective pour le web view.
    bool isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    // Étape 5 : Initialisation finale
    JwLifeSettings().webViewData.init(isDark);
  }

  // --- Gestion des URIs (Deep Linking) ---

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

        int? startParagraphId;
        int? endParagraphId;

        String? parStr = uri.par; // ex: "4" ou "4-6"

        if(parStr != null) {
          if (parStr.contains('-')) {
            final parts = parStr.split('-');
            startParagraphId = int.parse(parts[0]);
            endParagraphId = int.parse(parts[1]);
          } else {
            startParagraphId = int.parse(parStr);
            endParagraphId = startParagraphId;
          }
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
        Publication? biblePub = GlobalKeyService.bibleKey.currentState!.currentBible;
        if (biblePub == null) return;

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(1, goToFirstPage: true);

        showPage(
            BibleChapterPage(
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

        Publication? biblePub = GlobalKeyService.bibleKey.currentState!.currentBible;
        if (biblePub == null) return;

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(1, goToFirstPage: true);

        showPageBibleChapter(
          biblePub,
          bibleBook,
          bibleChapter,
          firstVerse: firstVerse,
          lastVerse: lastVerse,
        );
      }
      else if (uri.isMediaItem) {
        Duration startTime = Duration.zero;

        if (uri.ts != null && uri.ts!.isNotEmpty) {
          final parts = uri.ts!.split('-');
          if (parts.isNotEmpty) {
            startTime = JwOrgUri.parseDuration(parts[0]) ?? Duration.zero;
          }
          if (parts.length > 1) {
          }
        }

        MediaItem? mediaItem = getMediaItemFromLank(uri.lank!, uri.wtlocale);

        if (mediaItem == null) return;

        if(mediaItem.type == 'AUDIO') {
          Audio audio = Audio.fromJson(mediaItem: mediaItem);
          audio.showPlayer(context, initialPosition: startTime);
        }
        else {
          GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0, goToFirstPage: true);
          Video video = Video.fromJson(mediaItem: mediaItem);
          video.showPlayer(context, initialPosition: startTime);
        }
      }
      else if (uri.isDailyText) {
        final date = (uri.date == null || uri.date == 'today') ? DateTime.now() : DateTime.parse(uri.date!);

        List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: date);

        // Si Publication a un champ 'id' ou 'symbol' à tester
        Publication? dailyTextPub = dayPubs.firstWhereOrNull((p) => p.keySymbol.contains('es')); // ou p.symbol, p.title, etc.

        if (dailyTextPub == null) return;

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0, goToFirstPage: true);
        showPageDailyText(dailyTextPub, date: date);
      }
      else if (uri.isMeetings) {
        final date = (uri.date == null) ? DateTime.now() : DateTime.parse(uri.date!);

        List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: date);

        GlobalKeyService.workShipKey.currentState!.refreshMeetingsPubs(publications: dayPubs);
        GlobalKeyService.workShipKey.currentState!.refreshSelectedDay(date);

        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(3, goToFirstPage: true);
      }
    }
    catch (e) {
      print('Erreur parsing JwLifeUri: $e');
    }
  }
}
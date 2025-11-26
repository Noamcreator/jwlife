import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_page.dart';
import '../jwlife_app.dart';

// Import des pages et de leurs State respectifs
import '../../features/home/pages/home_page.dart';
import '../../features/bible/pages/bible_page.dart';
import '../../features/library/pages/library_page.dart';
import '../../features/workship/pages/workship_page.dart';
import '../../features/predication/pages/predication_page.dart';
import '../../features/personal/pages/personal_page.dart';

enum PageType {
  home,
  bible,
  library,
  workShip,
  predication,
  personal,
}

class GlobalKeyService {
  // Singleton instance
  static final GlobalKeyService _instance = GlobalKeyService._internal();
  factory GlobalKeyService() => _instance;
  GlobalKeyService._internal();

  /// Global key pour l'application principale
  static final GlobalKey<JwLifeAppState> jwLifeAppKey = GlobalKey<JwLifeAppState>();
  static final GlobalKey<JwLifePageState> jwLifePageKey = GlobalKey<JwLifePageState>();

  /// Clé actuellement sélectionnée (ex : pour effectuer une action ciblée sur la page active)
  static GlobalKey<State<StatefulWidget>>? currentPageKey;

  /// Toutes les clés des pages dans l’ordre défini par PageType
  static final Map<PageType, GlobalKey> _pageKeys = {
    PageType.home: GlobalKey<HomePageState>(),
    PageType.bible: GlobalKey<BiblePageState>(),
    PageType.library: GlobalKey<LibraryPageState>(),
    PageType.workShip: GlobalKey<WorkShipPageState>(),
    PageType.predication: GlobalKey<PredicationPageState>(),
    PageType.personal: GlobalKey<PersonalPageState>(),
  };

  /// Accès typé aux GlobalKeys par page
  static GlobalKey<HomePageState> get homeKey => _pageKeys[PageType.home]! as GlobalKey<HomePageState>;
  static GlobalKey<BiblePageState> get bibleKey => _pageKeys[PageType.bible]! as GlobalKey<BiblePageState>;
  static GlobalKey<LibraryPageState> get libraryKey => _pageKeys[PageType.library]! as GlobalKey<LibraryPageState>;
  static GlobalKey<WorkShipPageState> get workShipKey => _pageKeys[PageType.workShip]! as GlobalKey<WorkShipPageState>;
  static GlobalKey<PredicationPageState> get predicationKey => _pageKeys[PageType.predication]! as GlobalKey<PredicationPageState>;
  static GlobalKey<PersonalPageState> get personalKey => _pageKeys[PageType.personal]! as GlobalKey<PersonalPageState>;

  /// Récupère une clé générique par type
  static GlobalKey<T> getKey<T extends State<StatefulWidget>>(PageType type) {
    return _pageKeys[type]! as GlobalKey<T>;
  }

  /// Définit dynamiquement la page actuellement visible
  static void setCurrentPage(GlobalKey globalKey) {
    currentPageKey = globalKey;
  }

  /// Optionnel : récupère la liste complète (utile si tu veux les injecter quelque part)
  static List<GlobalKey> get allPageKeys => _pageKeys.values.toList();
}

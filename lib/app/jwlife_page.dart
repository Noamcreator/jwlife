import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/features/bible/views/bible_page.dart';
import 'package:jwlife/features/congregation/pages/congregation_page.dart';
import 'package:jwlife/features/home/views/home_page.dart';
import 'package:jwlife/features/library/pages/library_page.dart';
import 'package:jwlife/features/personal/pages/personal_page.dart';

import '../core/icons.dart';
import 'package:jwlife/i18n/localization.dart';

import '../features/audio/audio_player_widget.dart';
import '../features/meetings/pages/meeting_page.dart';
import '../features/predication/pages/predication_page.dart';
import '../widgets/custom_bottom_navigation_item.dart';
import '../widgets/slide_indexed_stack.dart';

class JwLifePage extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLocale;

  static final List<GlobalKey> pageKeys = [
    GlobalKey<HomePageState>(),
    GlobalKey<BiblePageState>(),
    GlobalKey<LibraryPageState>(),
    GlobalKey<MeetingsPageState>(),
    GlobalKey<PredicationPageState>(),
    GlobalKey<CongregationPageState>(),
    GlobalKey<PersonalPageState>(),
  ];

  static late GlobalKey<HomePageState> Function() getHomeGlobalKey;
  static late GlobalKey<BiblePageState> Function() getBibleGlobalKey;
  static late GlobalKey<LibraryPageState> Function() getLibraryGlobalKey;
  static late GlobalKey<MeetingsPageState> Function() getMeetingsGlobalKey;
  static late GlobalKey<PredicationPageState> Function() getPredicationGlobalKey;
  static late GlobalKey<CongregationPageState> Function() getCongregationGlobalKey;
  static late GlobalKey<PersonalPageState> Function() getPersonalGlobalKey;

  static void initializePageKeys() {
    getHomeGlobalKey = () => pageKeys[0] as GlobalKey<HomePageState>;
    getBibleGlobalKey = () => pageKeys[1] as GlobalKey<BiblePageState>;
    getLibraryGlobalKey = () => pageKeys[2] as GlobalKey<LibraryPageState>;
    getMeetingsGlobalKey = () => pageKeys[3] as GlobalKey<MeetingsPageState>;
    getPredicationGlobalKey = () => pageKeys[4] as GlobalKey<PredicationPageState>;
    getCongregationGlobalKey = () => pageKeys[5] as GlobalKey<CongregationPageState>;
    getPersonalGlobalKey = () => pageKeys[6] as GlobalKey<PersonalPageState>;
  }

  static late Function(bool) toggleNavBarVisibility;
  static late Function(bool) toggleNavBarBlack;
  static late Function(bool) toggleNavBarPositioned;
  static late Function(bool) toggleAudioWidgetVisibility;
  static late Function() getNavBarVisibility;

  static List<bool> navBarVisible = [true, true, true, true, true, true, true];
  static List<bool> navBarIsBlack = [false, false, false, false, false, false, false];
  static List<bool> navBarIsPositioned = [false, false, false, false, false, false, false];
  static bool audioWidgetVisible = false;
  static int currentIndex = 0;

  const JwLifePage({super.key, required this.toggleTheme, required this.changeLocale});

  @override
  State<JwLifePage> createState() => _JwLifePageState();
}

class _JwLifePageState extends State<JwLifePage> {
  final List<bool> _navBarVisible = List.from(JwLifePage.navBarVisible);
  final List<bool> _navBarIsBlack = List.from(JwLifePage.navBarIsBlack);
  final List<bool> _navBarIsPositioned = List.from(JwLifePage.navBarIsPositioned);

  bool _audioWidgetVisible = JwLifePage.audioWidgetVisible;
  int _currentIndex = JwLifePage.currentIndex;

  late final List<Widget> _pages;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(7, (_) => GlobalKey<NavigatorState>());

  Future<bool> _onWillPop() async {
    final currentNavigator = _navigatorKeys[_currentIndex].currentState!;
    if (currentNavigator.canPop()) {
      currentNavigator.pop();
      setState(() {
        _navBarVisible[_currentIndex] = true;
        _navBarIsBlack[_currentIndex] = false;
        _navBarIsPositioned[_currentIndex] = false;
      });
      _updateSystemUiMode();
      return false;
    }
    return true; // sort de l'app si aucune pile ne peut revenir
  }

  @override
  void initState() {
    super.initState();

    JwLifePage.initializePageKeys();

    _pages = [
      HomePage(key: JwLifePage.pageKeys[0], toggleTheme: widget.toggleTheme, changeLocale: widget.changeLocale),
      BiblePage(key: JwLifePage.pageKeys[1]),
      LibraryPage(key: JwLifePage.pageKeys[2]),
      MeetingsPage(key: JwLifePage.pageKeys[3]),
      PredicationPage(key: JwLifePage.pageKeys[4]),
      CongregationPage(key: JwLifePage.pageKeys[5]),
      PersonalPage(key: JwLifePage.pageKeys[6]),
    ];

    JwLifePage.toggleNavBarVisibility = _toggleNavBarVisibility;
    JwLifePage.toggleNavBarBlack = _toggleNavBarBlack;
    JwLifePage.toggleNavBarPositioned = _toggleNavBarPositioned;
    JwLifePage.toggleAudioWidgetVisibility = _toggleAudioWidgetVisibility;
    JwLifePage.getNavBarVisibility = () => _navBarVisible[_currentIndex];
  }

  void _toggleNavBarVisibility(bool isVisible) {
    setState(() {
      _navBarVisible[_currentIndex] = isVisible;
    });
  }

  void _toggleNavBarBlack(bool isBlack) {
    setState(() {
      _navBarIsBlack[_currentIndex] = isBlack;
    });
    _updateSystemUiMode();
  }

  void _toggleNavBarPositioned(bool isPositioned) {
    setState(() {
      _navBarIsPositioned[_currentIndex] = isPositioned;
      _navBarVisible[_currentIndex] = !isPositioned;
    });
    _updateSystemUiMode();
  }

  void _toggleAudioWidgetVisibility(bool isVisible) {
    setState(() {
      _audioWidgetVisible = isVisible;
    });
  }

  void _updateSystemUiMode() {
    if (_navBarIsBlack[_currentIndex] || _navBarIsPositioned[_currentIndex]) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final Widget content = WillPopScope(
      onWillPop: _onWillPop,
      child: IndexedStack(
        index: _currentIndex,
        children: List.generate(_pages.length, (index) {
          return Navigator(
            key: _navigatorKeys[index],
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (_) => _pages[index],
                settings: settings,
              );
            },
          );
        }),
      ),
    );

    final Widget audioWidget = Visibility(
      child: AudioPlayerWidget(
        key: const ValueKey('audio'),
        visible: _audioWidgetVisible && !_navBarIsBlack[_currentIndex],
      ),
    );

    final Widget bottomNav = _navBarVisible[_currentIndex]
        ? CustomBottomNavigation(
      currentIndex: _currentIndex,
      selectedFontSize: 8.5,
      unselectedFontSize: 8.0,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      backgroundColor: _navBarIsBlack[_currentIndex]
          ? Colors.transparent
          : Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      selectedIconTheme: IconThemeData(
        color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
      ),
      selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor: _navBarIsBlack[_currentIndex]
          ? Colors.white
          : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
      items: [
        CustomBottomNavigationItem(label: localization(context).navigation_home, icon: const Icon(JwIcons.home)),
        CustomBottomNavigationItem(label: localization(context).navigation_bible, icon: const Icon(JwIcons.bible)),
        CustomBottomNavigationItem(label: localization(context).navigation_library, icon: const Icon(JwIcons.publication_video_music)),
        CustomBottomNavigationItem(label: localization(context).navigation_meetings, icon: const Icon(JwIcons.speaker_audience)),
        CustomBottomNavigationItem(label: localization(context).navigation_predication, icon: const Icon(JwIcons.persons_doorstep)),
        CustomBottomNavigationItem(label: localization(context).navigation_congregations, icon: const Icon(JwIcons.kingdom_hall)),
        CustomBottomNavigationItem(label: localization(context).navigation_personal, icon: const Icon(JwIcons.person_studying)),
      ],
      onTap: (index) {
        if (index == _currentIndex) {
          _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
          setState(() {
            _navBarVisible[_currentIndex] = true;
            _navBarIsBlack[index] = false;
            _navBarIsPositioned[index] = false;
          });
        }
        else {
          setState(() {
            _currentIndex = index;
            JwLifePage.currentIndex = index;
          });
        }
        _updateSystemUiMode();
      },
    ) : const SizedBox.shrink();

    return _navBarIsPositioned[_currentIndex] || _navBarIsBlack[_currentIndex]
        ? Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: content),
          if (!isKeyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: _navBarVisible[_currentIndex] ? 56.0 : 0,
              child: audioWidget,
            ),
          if (_navBarVisible[_currentIndex])
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: bottomNav,
            ),
        ],
      ),
    )
        : Scaffold(
      body: Column(
        children: [
          Expanded(child: content),
          audioWidget
        ],
      ),
      bottomNavigationBar: bottomNav,
    );
  }
}

import 'package:beamer/beamer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/startup/login_view.dart';
import 'package:jwlife/modules/bible/views/bible_verse_recognizer.dart';
import 'package:jwlife/modules/congregation/views/congregation_view.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/library_view.dart';
import 'package:jwlife/modules/meetings/views/meeting_view.dart';
import 'package:jwlife/modules/personal/views/personal_view.dart';
import 'package:jwlife/modules/predication/views/predication_view.dart';

import '../audio/audio_player_widget.dart';
import '../core/icons.dart';
import '../l10n/localization.dart';

class JwLifeView extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLocale;

  static late Function(bool) toggleNavBarBody;
  static late Function(bool) toggleNavBarVisibility;
  static late Function(int, bool) toggleNavBarBlack;
  static late Function(bool) toggleAudioWidgetVisibility;

  static int currentTabIndex = 0;
  static bool hasBody = true;
  static bool isPersistentTabViewVisible = true;
  static bool isAudioWidgetVisible = false;
  static List<bool> persistentBarIsBlack = [false, false, false, false, false, false, false];

  const JwLifeView({super.key, required this.toggleTheme, required this.changeLocale});

  @override
  State<JwLifeView> createState() => _JwLifeViewState();
}

class _JwLifeViewState extends State<JwLifeView> {
  bool _isNavBarHasBody = false;
  bool _isPersistentTabViewVisible = true;
  bool _isAudioWidgetVisible = false;
  bool _persistentBarIsBlack = false;
  late int _currentIndex;

  // Declare and initialize Beamer delegates for /home and /library
  late List<BeamerDelegate> _routerDelegates;

  @override
  void initState() {
    super.initState();

    // Initialize static methods for nav bar and audio widget visibility
    JwLifeView.toggleNavBarBody = _toggleBottomBarBody;
    JwLifeView.toggleNavBarVisibility = _toggleBottomBarVisibility;
    JwLifeView.toggleNavBarBlack = _toggleBottomBarBlack;
    JwLifeView.toggleAudioWidgetVisibility = _toggleAudioWidgetVisibility;

    // Initialize the Beamer delegates for home and library
    _routerDelegates = [
      BeamerDelegate(
        initialPath: '/home',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/home')) {
            return SimpleLocation(
              routeInformation,
              HomeView(
                  toggleTheme: widget.toggleTheme,
                  changeLocale: widget.changeLocale
              ),
            );
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/bible',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/bible')) {
            return SimpleLocation(routeInformation, SpeechToTextScreen());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/library',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/library')) {
            return SimpleLocation(routeInformation, LibraryView());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/meetings',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/meetings')) {
            return SimpleLocation(routeInformation, MeetingsView());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/predication',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/predication')) {
            return SimpleLocation(routeInformation, PredicationView());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/congregation',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/congregation')) {
            return SimpleLocation(routeInformation, CongregationView());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/personal',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/personal')) {
            return SimpleLocation(routeInformation, PersonalView());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uriString = Beamer.of(context).configuration.location;
    _currentIndex = ["/home", "/bible", "/library", "/meetings", "/predication", "/congregation", "/personal"]
        .indexWhere((path) => uriString.contains(path));
  }

  void _toggleBottomBarBody(bool isBody) {
    JwLifeView.hasBody = isBody;
    setState(() {
      _isNavBarHasBody = isBody;
    });
  }

  void _toggleBottomBarVisibility(bool isVisible) {
    JwLifeView.isPersistentTabViewVisible = isVisible;
    setState(() {
      _isPersistentTabViewVisible = isVisible;
    });
  }

  void _toggleAudioWidgetVisibility(bool isVisible) {
    JwLifeView.isAudioWidgetVisible = isVisible;
    setState(() {
      _isAudioWidgetVisible = isVisible;
    });
  }

  void _toggleBottomBarBlack(int index, bool black) {
    _toggleBottomBarBody(!black);
    JwLifeView.persistentBarIsBlack[index] = black;
    setState(() {
      _persistentBarIsBlack = black;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: <Widget>[
                  IndexedStack(
                    index: _currentIndex,
                    children: _routerDelegates.map((delegate) =>
                        Beamer(routerDelegate: delegate)).toList(),
                  ),
                ],
              ),
            ),
            // Positionner le player audio tout en bas avec un espace dédié
            AudioPlayerWidget(
              visible: _isAudioWidgetVisible && !_persistentBarIsBlack,
            ),
          ],
        ), // Pour gérer l'orientation paysage, on ne fait rien ici
        extendBody: _persistentBarIsBlack,
        bottomNavigationBar: Visibility(
            visible: _isPersistentTabViewVisible,
            child: Theme(
              data: Theme.of(context).copyWith(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.grey.withOpacity(0.1),
              ),
              child: BottomNavigationBar(
                unselectedFontSize: 8.0,
                selectedFontSize: 8.5,
                backgroundColor: _persistentBarIsBlack
                    ? Colors.transparent
                    : Theme.of(context).bottomNavigationBarTheme.backgroundColor,
                currentIndex: _currentIndex,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
                unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
                landscapeLayout: BottomNavigationBarLandscapeLayout.linear,
                items: [
                  BottomNavigationBarItem(label: localization(context).navigation_home, icon: const Icon(JwIcons.home)),
                  BottomNavigationBarItem(label: localization(context).navigation_bible, icon: Icon(JwIcons.bible)),
                  BottomNavigationBarItem(label: localization(context).navigation_library, icon: Icon(JwIcons.publication_video_music)),
                  BottomNavigationBarItem(label: localization(context).navigation_meetings, icon: Icon(JwIcons.speaker_audience)),
                  BottomNavigationBarItem(label: localization(context).navigation_predication, icon: Icon(JwIcons.persons_doorstep)),
                  BottomNavigationBarItem(label: localization(context).navigation_congregations, icon: Icon(JwIcons.kingdom_hall)),
                  BottomNavigationBarItem(label: localization(context).navigation_personal, icon: Icon(JwIcons.person_studying)),
                ],
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                    _routerDelegates[_currentIndex].update(rebuild: false);
                  });
                },
              ),
            )
        ),
      ),
      Visibility(
        visible: FirebaseAuth.instance.currentUser == null,
        child: Scaffold(
          body: LoginView(update: setState, fromSettings: false),
        ),
      )
    ]);
  }
}

class SimpleLocation extends BeamLocation<BeamState> {
  SimpleLocation(RouteInformation super.routeInformation, this.page);

  final Widget page;

  @override
  List<String> get pathPatterns => ['/*'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
    BeamPage(
      key: ValueKey(page.runtimeType.toString()),
      title: page.runtimeType.toString(),
      type: BeamPageType.noTransition,
      child: page,
    )
  ];
}
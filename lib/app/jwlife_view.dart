import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/modules/bible/views/bible_view.dart';
import 'package:jwlife/modules/congregation/views/congregation_view.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/library_view.dart';
import 'package:jwlife/modules/meetings/views/meeting_view.dart';
import 'package:jwlife/modules/personal/views/personal_view.dart';
import 'package:jwlife/modules/predication/views/predication_view.dart';

import '../audio/audio_player_widget.dart';
import '../core/icons.dart';
import 'package:jwlife/i18n/localization.dart';

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
  bool _isPersistentTabViewVisible = true;
  bool _isAudioWidgetVisible = false;
  bool _persistentBarIsBlack = false;
  int _currentIndex = 0;

  // Declare and initialize Beamer delegates for different sections of the app
  late List<BeamerDelegate> _routerDelegates;

  @override
  void initState() {
    super.initState();

    // Initialize static methods for nav bar and audio widget visibility
    JwLifeView.toggleNavBarVisibility = _toggleBottomBarVisibility;
    JwLifeView.toggleNavBarBlack = _toggleBottomBarBlack;
    JwLifeView.toggleAudioWidgetVisibility = _toggleAudioWidgetVisibility;

    // Initialize the Beamer delegates for various sections (home, bible, etc.)
    _routerDelegates = [
      BeamerDelegate(
        initialPath: '/home',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/home')) {
            return SimpleLocation(
              routeInformation,
              HomeView(
                toggleTheme: widget.toggleTheme,
                changeLocale: widget.changeLocale,
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
            return SimpleLocation(routeInformation, BibleView());
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
    JwLifeView.persistentBarIsBlack[index] = black;
    setState(() {
      _persistentBarIsBlack = black;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
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
              // Audio widget displayed at the bottom if conditions are met
              AudioPlayerWidget(
                visible: _isAudioWidgetVisible && !_persistentBarIsBlack,
              ),
            ],
          ),
          extendBody: _persistentBarIsBlack,
          bottomNavigationBar: _isPersistentTabViewVisible
              ? Visibility(
            visible: _isPersistentTabViewVisible,
            child: Theme(
              data: Theme.of(context).copyWith(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.grey.withOpacity(0.1),
              ),
              child: BottomNavigationBar(
                unselectedFontSize: 8.0,
                selectedFontSize: 8.5,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                backgroundColor: _persistentBarIsBlack
                    ? Colors.transparent
                    : Theme.of(context).bottomNavigationBarTheme.backgroundColor,
                currentIndex: _currentIndex,
                type: BottomNavigationBarType.fixed,
                selectedIconTheme: IconThemeData(
                  color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
                  fill: 0.0,
                ),
                unselectedItemColor: _persistentBarIsBlack ? Colors.white : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
                landscapeLayout: BottomNavigationBarLandscapeLayout.linear,
                items: [
                  BottomNavigationBarItem(
                    label: localization(context).navigation_home,
                    icon: const Icon(JwIcons.home),
                  ),
                  BottomNavigationBarItem(
                    label: localization(context).navigation_bible,
                    icon: Icon(JwIcons.bible),
                  ),
                  BottomNavigationBarItem(
                    label: localization(context).navigation_library,
                    icon: Icon(JwIcons.publication_video_music),
                  ),
                  BottomNavigationBarItem(
                    label: localization(context).navigation_meetings,
                    icon: Icon(JwIcons.speaker_audience),
                  ),
                  BottomNavigationBarItem(
                    label: localization(context).navigation_predication,
                    icon: Icon(JwIcons.persons_doorstep),
                  ),
                  BottomNavigationBarItem(
                    label: localization(context).navigation_congregations,
                    icon: Icon(JwIcons.kingdom_hall),
                  ),
                  BottomNavigationBarItem(
                    label: localization(context).navigation_personal,
                    icon: Icon(JwIcons.person_studying),
                  ),
                ],
                onTap: (index) {
                  if (index == _currentIndex) {
                    Navigator.pop(context);
                  }
                  setState(() {
                    _currentIndex = index;
                    _routerDelegates[_currentIndex].update(rebuild: false);
                  });
                },
              ),
            ),
          )
              : Container(),
        ),
        /*
        Visibility(
          visible: FirebaseAuth.instance.currentUser == null,
          child: Scaffold(
            body: LoginView(update: setState, fromSettings: false),
          ),
        ),
         */
      ],
    );
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
      child: page,
    ),
  ];
}
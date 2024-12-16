import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/pages/bible_page.dart';
import 'package:jwlife/pages/congregation_page.dart';
import 'package:jwlife/pages/home_page.dart';
import 'package:jwlife/pages/library_page.dart';
import 'package:jwlife/pages/meeting_page.dart';
import 'package:jwlife/pages/personal_page.dart';
import 'package:jwlife/pages/predication_page.dart';
import 'package:jwlife/splash_screen.dart';
import 'package:jwlife/userdata/Userdata.dart';
import 'package:jwlife/utils/icons.dart';
import 'package:jwlife/utils/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/AudioPlayerWidget.dart';
import 'audio/JwAudioPlayer.dart';
import 'load_assets.dart';
import 'meps/language.dart';

class JwLifeApp extends StatefulWidget {
  final bool isDarkTheme;
  static JwAudioPlayer jwAudioPlayer = JwAudioPlayer();
  static Userdata userdata = Userdata();
  static Language currentLanguage = Language(id: 3, symbol: 'F', vernacular: 'Français', primaryIetfCode: 'fr', rsConf: 'r30', lib: 'lp-f');

  static late Function() setStateHomePage;

  const JwLifeApp({super.key, required this.isDarkTheme});

  @override
  _JwLifeAppState createState() => _JwLifeAppState();
}

class _JwLifeAppState extends State<JwLifeApp> {
  late bool _isDarkTheme;
  BeamerDelegate? routerDelegate; // Change to nullable

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;

    initializeData().then((_) {
      setState(() {
        routerDelegate = BeamerDelegate(
          initialPath: '/home',
          locationBuilder: RoutesLocationBuilder(
            routes: {
              '*': (context, state, data) => JwLifePage(
                toggleTheme: _toggleTheme,
              ),
            },
          ).call,
        );
      });
    });
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkTheme = isDark;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isDarkTheme', isDark);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (routerDelegate == null) {
      // Show a placeholder while the routerDelegate is being initialized
      return MaterialApp(
        title: 'Jw Life',
        debugShowCheckedModeBanner: false,
        themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
        theme: light,
        darkTheme: dark,
        home: Scaffold(
          body: SplashScreen()
        ),
      );
    }

    // Once initialized, build the app with the router
    return MaterialApp.router(
      title: 'Jw Life',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      theme: light,
      darkTheme: dark,
      routerDelegate: routerDelegate!,
      routeInformationParser: BeamerParser(),
      backButtonDispatcher: BeamerBackButtonDispatcher(
        delegate: routerDelegate!,
      ),
    );
  }

  Future<void> initializeData() async {
    await LoadAssets.copyAssets();
    await JwLifeApp.userdata.init();
  }
}


class JwLifePage extends StatefulWidget {
  final Function(bool) toggleTheme;

  static late Function(bool) toggleNavBarVisibility;
  static late Function(int, bool) toggleNavBarBlack;
  static late Function(bool) toggleAudioWidgetVisibility;

  static int currentTabIndex = 0;
  static bool isPersistentTabViewVisible = true;
  static bool isAudioWidgetVisible = false;
  static List<bool> persistentBarIsBlack = [false, false, false, false, false, false, false];

  const JwLifePage({super.key, required this.toggleTheme});

  @override
  State<JwLifePage> createState() => _JwLifePageState();
}

class _JwLifePageState extends State<JwLifePage> {
  bool _isPersistentTabViewVisible = true;
  bool _isAudioWidgetVisible = false;
  bool _persistentBarIsBlack = false;
  bool _isExtended = false;
  late int _currentIndex;

  // Declare a list of delegates but initialize them later
  late List<BeamerDelegate> _routerDelegates;

  @override
  void initState() {
    super.initState();

    // Initialize static methods for nav bar and audio widget visibility
    JwLifePage.toggleNavBarVisibility = _toggleBottomBarVisibility;
    JwLifePage.toggleNavBarBlack = _toggleBottomBarBlack;
    JwLifePage.toggleAudioWidgetVisibility = _toggleAudioWidgetVisibility;

    // Initialize the Beamer delegates within initState to access widget.toggleTheme
    _routerDelegates = [
      BeamerDelegate(
        initialPath: '/home',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/home')) {
            return SimpleLocation(
              routeInformation,
              HomePage(toggleTheme: widget.toggleTheme),
            );
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/bible',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/bible')) {
            return SimpleLocation(routeInformation, BiblePage());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/library',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/library')) {
            return SimpleLocation(routeInformation, LibraryPage());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/meeting',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/meeting')) {
            return SimpleLocation(routeInformation, const MeetingPage());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/predication',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/predication')) {
            return SimpleLocation(routeInformation, PredicationPage());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/congregation',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/congregation')) {
            return SimpleLocation(routeInformation, CongregationPage());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
      BeamerDelegate(
        initialPath: '/personal',
        locationBuilder: (routeInformation, _) {
          if (routeInformation.location.contains('/personal')) {
            return SimpleLocation(routeInformation, PersonalPage());
          }
          return NotFound(path: routeInformation.location);
        },
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uriString = Beamer
        .of(context)
        .configuration
        .location;
    _currentIndex =
        ["/home", "/bible", "/library", "/meeting", "/predication", "/congregation", "/personal"]
            .indexWhere((path) => uriString.contains(path));
  }

  void _toggleBottomBarVisibility(bool isVisible) {
    JwLifePage.isPersistentTabViewVisible = isVisible;
    setState(() {
      _isPersistentTabViewVisible = isVisible;
    });
  }

  void _toggleAudioWidgetVisibility(bool isVisible) {
    JwLifePage.isAudioWidgetVisible = isVisible;
    setState(() {
      _isAudioWidgetVisible = isVisible;
    });
  }

  void _toggleBottomBarBlack(int index, bool black) {
    JwLifePage.persistentBarIsBlack[index] = black;
    setState(() {
      _persistentBarIsBlack = black;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediaQuery
          .of(context)
          .orientation == Orientation.portrait
          ? Column(
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
      )
          : Row(
        children: [
          _isPersistentTabViewVisible ? NavigationRail(
            leading: SizedBox(
              width: _isExtended ? 240 : 40.0,  // Largeur fixe pour l'icône de menu
              child: IconButton(
                alignment: _isExtended ? Alignment.centerLeft : Alignment.center,
                icon: Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isExtended = !_isExtended;
                  });
                },
              ),
            ),
            backgroundColor: _persistentBarIsBlack
                ? Colors.transparent
                : Theme
                .of(context)
                .bottomNavigationBarTheme
                .backgroundColor,
            selectedIconTheme: IconThemeData(
              color: Theme
                  .of(context)
                  .bottomNavigationBarTheme
                  .selectedItemColor,
            ),
            unselectedIconTheme: IconThemeData(
              color: Theme
                  .of(context)
                  .bottomNavigationBarTheme
                  .unselectedItemColor,
            ),
            useIndicator: false,
            indicatorColor: _persistentBarIsBlack
                ? Colors.transparent
                : Theme
                .of(context)
                .bottomNavigationBarTheme
                .backgroundColor,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0.0),
            ),
            minWidth: 60.0,
            extended: _isExtended,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              _isExtended = false;
              JwLifePage.currentTabIndex = index;
              setState(() {
                _toggleBottomBarBlack(index, JwLifePage.persistentBarIsBlack[index]);
              });
              if (index != _currentIndex) {
                setState(() => _currentIndex = index);
                _routerDelegates[_currentIndex].update(rebuild: false);
              }
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(JwIcons.home),
                label: Text('Accueil'),
              ),
              NavigationRailDestination(
                icon: Icon(JwIcons.bible),
                label: Text('Bible'),
              ),
              NavigationRailDestination(
                icon: Icon(JwIcons.publication_video_music),
                label: Text('Bibliothèque'),
              ),
              NavigationRailDestination(
                icon: Icon(JwIcons.speaker_audience),
                label: Text('Réunions'),
              ),
              NavigationRailDestination(
                icon: Icon(JwIcons.persons_doorstep),
                label: Text('Prédication'),
              ),
              NavigationRailDestination(
                icon: Icon(JwIcons.kingdom_hall),
                label: Text('Assemblée Locale'),
              ),
              NavigationRailDestination(
                icon: Icon(JwIcons.person_studying),
                label: Text('Personel'),
              ),
            ],
          ) : Container(),
          // Zone principale avec le contenu
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _routerDelegates.map((delegate) =>
                  Beamer(routerDelegate: delegate)).toList(),
            ),
          ),
        ],
      ),
      extendBody: _persistentBarIsBlack,
      bottomNavigationBar: _isPersistentTabViewVisible && MediaQuery
          .of(context)
          .orientation == Orientation.portrait
          ? BottomNavigationBar(
        unselectedFontSize: 8.0,
        selectedFontSize: 8.5,
        backgroundColor: _persistentBarIsBlack
            ? Colors.transparent
            : Theme
            .of(context)
            .bottomNavigationBarTheme
            .backgroundColor,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme
            .of(context)
            .bottomNavigationBarTheme
            .selectedItemColor,
        unselectedItemColor: Theme
            .of(context)
            .bottomNavigationBarTheme
            .unselectedItemColor,
        items: const [
          BottomNavigationBarItem(label: 'Accueil', icon: Icon(JwIcons.home)),
          BottomNavigationBarItem(label: 'Bible', icon: Icon(JwIcons.bible)),
          BottomNavigationBarItem(label: 'Bibliothèque', icon: Icon(JwIcons.publication_video_music)),
          BottomNavigationBarItem(label: 'Réunions', icon: Icon(JwIcons.speaker_audience)),
          BottomNavigationBarItem(label: 'Prédication', icon: Icon(JwIcons.persons_doorstep)),
          BottomNavigationBarItem(label: 'Assemblée Locale', icon: Icon(JwIcons.kingdom_hall)),
          BottomNavigationBarItem(label: 'Personel', icon: Icon(JwIcons.person_studying)),
        ],
        onTap: (index) {
          JwLifePage.currentTabIndex = index;
          setState(() {
            _toggleBottomBarBlack(
                index, JwLifePage.persistentBarIsBlack[index]);
          });
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
            _routerDelegates[_currentIndex].update(rebuild: false);
          }
        },
      )
          : SizedBox.shrink(),
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
      type: BeamPageType.noTransition,
      child: page,
    )
  ];
}

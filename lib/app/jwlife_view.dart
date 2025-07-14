import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import '../widgets/custom_bottom_navigation_item.dart';

class JwLifeView extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final Function(Locale) changeLocale;

  static late Function(bool) toggleNavBarVisibility;
  static late Function(bool) toggleNavBarBlack;
  static late Function(bool) toggleNavBarPositioned;
  static late Function(bool) toggleNavBarSystemUiMode;
  static late Function(bool) toggleAudioWidgetVisibility;

  static late Function() getNavBarVisibility;

  static List<bool> navBarVisible = [true, true, true, true, true, true, true];
  static List<bool> navBarIsBlack = [false, false, false, false, false, false, false];
  static List<bool> navBarIsPositioned = [false, false, false, false, false, false, false];
  static bool audioWidgetVisible = false;
  static int currentIndex = 0;

  const JwLifeView({super.key, required this.toggleTheme, required this.changeLocale});

  @override
  State<JwLifeView> createState() => _JwLifeViewState();
}

class _JwLifeViewState extends State<JwLifeView> {
  final List<bool> _navBarVisible = [true, true, true, true, true, true, true];
  final List<bool> _navBarIsBlack = [false, false, false, false, false, false, false];
  final List<bool> _navBarIsPositioned = [false, false, false, false, false, false, false];
  bool _audioWidgetVisible = false;
  int _currentIndex = 0;

  // Declare and initialize Beamer delegates for different sections of the app
  late List<BeamerDelegate> _routerDelegates;

  @override
  void initState() {
    super.initState();

    // Initialize static methods for nav bar and audio widget visibility
    JwLifeView.toggleNavBarVisibility = _toggleNavBarVisibility;
    JwLifeView.toggleNavBarBlack = _toggleNavBarBlack;
    JwLifeView.toggleNavBarPositioned = _toggleNavBarPositioned;
    JwLifeView.toggleAudioWidgetVisibility = _toggleAudioWidgetVisibility;

    JwLifeView.getNavBarVisibility = getNavBarVisibility;

    // Initialize the Beamer delegates for various sections (home, bible, etc.)
    _routerDelegates = [
      BeamerDelegate(
        initialPath: '/home',
        locationBuilder: getRouteLocation(
          HomeView(
            toggleTheme: widget.toggleTheme,
            changeLocale: widget.changeLocale,
          ),
          'home',
        ).call,
      ),
      BeamerDelegate(
        initialPath: '/bible',
        locationBuilder:  getRouteLocation(
          BibleView(),
          'bible',
        ).call,
      ),
      BeamerDelegate(
        initialPath: '/library',
        locationBuilder: getRouteLocation(
          LibraryView(),
          'library',
        ).call,
      ),
      BeamerDelegate(
        initialPath: '/meetings',
        locationBuilder: getRouteLocation(
          MeetingsView(),
          'meetings',
        ).call,
      ),
      BeamerDelegate(
        initialPath: '/predication',
        locationBuilder: getRouteLocation(
          PredicationView(),
          'predication',
        ).call,
      ),
      BeamerDelegate(
        initialPath: '/congregation',
        locationBuilder: getRouteLocation(
          CongregationView(),
          'congregation',
        ).call,
      ),
      BeamerDelegate(
        initialPath: '/personal',
        locationBuilder: getRouteLocation(
          PersonalView(),
          'personal',
        ).call,
      ),
    ];
  }

  bool getNavBarVisibility() {
    return JwLifeView.navBarVisible[_currentIndex];
  }

  void _toggleNavBarVisibility(bool isVisible) {
    JwLifeView.navBarVisible[_currentIndex] = isVisible;
    setState(() {
      _navBarVisible[_currentIndex] = isVisible;
    });
  }

  void _toggleNavBarBlack(bool isBlack) {
    JwLifeView.navBarIsBlack[_currentIndex] = isBlack;
    setState(() {
      _navBarIsBlack[_currentIndex] = isBlack;
    });
    if (isBlack) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    }
    else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
    }
  }

  void _toggleNavBarPositioned(bool isPositioned) {
    JwLifeView.navBarIsPositioned[_currentIndex] = isPositioned;
    setState(() {
      _navBarIsPositioned[_currentIndex] = isPositioned;
      _navBarVisible[_currentIndex] = !isPositioned;
    });
    if (isPositioned) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    }
    else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
    }
  }

  void _toggleAudioWidgetVisibility(bool isVisible) {
    JwLifeView.audioWidgetVisible = isVisible;
    setState(() {
      _audioWidgetVisible = isVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final Widget content = IndexedStack(
      index: _currentIndex,
      children: _routerDelegates
          .map((delegate) => Beamer(routerDelegate: delegate))
          .toList(),
    );

    final Widget audioWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !isKeyboardOpen
          ? AudioPlayerWidget(
        key: const ValueKey('audio'),
        visible: _audioWidgetVisible && !_navBarIsBlack[_currentIndex],
      )
          : const SizedBox.shrink(key: ValueKey('no-audio')),
    );

    final Widget bottomNav = _navBarVisible[_currentIndex]
        ? CustomBottomNavigation(
      currentIndex: _currentIndex,
      selectedFontSize: 8.5,
      unselectedFontSize: 8.0,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      backgroundColor: _navBarIsBlack[_currentIndex]
          ? Colors.transparent
          : Theme.of(context)
          .bottomNavigationBarTheme
          .backgroundColor,
      selectedIconTheme: IconThemeData(
        color:
        Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        fill: 0.0,
      ),
      selectedItemColor:
      Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor: _navBarIsBlack[_currentIndex]
          ? Colors.white
          : Theme.of(context)
          .bottomNavigationBarTheme
          .unselectedItemColor,
      items: [
        CustomBottomNavigationItem(
          label: localization(context).navigation_home,
          icon: const Icon(JwIcons.home),
        ),
        CustomBottomNavigationItem(
          label: localization(context).navigation_bible,
          icon: const Icon(JwIcons.bible),
        ),
        CustomBottomNavigationItem(
          label: localization(context).navigation_library,
          icon: const Icon(JwIcons.publication_video_music),
        ),
        CustomBottomNavigationItem(
          label: localization(context).navigation_meetings,
          icon: const Icon(JwIcons.speaker_audience),
        ),
        CustomBottomNavigationItem(
          label: localization(context).navigation_predication,
          icon: const Icon(JwIcons.persons_doorstep),
        ),
        CustomBottomNavigationItem(
          label: localization(context).navigation_congregations,
          icon: const Icon(JwIcons.kingdom_hall),
        ),
        CustomBottomNavigationItem(
          label: localization(context).navigation_personal,
          icon: const Icon(JwIcons.person_studying),
        ),
      ],
      onTap: (index) async {
        final delegate = _routerDelegates[index];

        if (index == _currentIndex) {
          await popToRoot(delegate);
        }
        else {
          setState(() {
            _currentIndex = index;
            _routerDelegates[index].update(rebuild: true);
          });
          JwLifeView.currentIndex = index;
        }

        if (_navBarIsBlack[index] || _navBarIsPositioned[index]) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
        }
        else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
        }
      },
    ) : const SizedBox.shrink();

    return _navBarIsPositioned[_currentIndex] || _navBarIsBlack[_currentIndex] ? Scaffold(
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
      )
    ) :
    Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(child: content),
          audioWidget,
        ],
      ),
      bottomNavigationBar: bottomNav
    );
  }
}

Future<void> popToRoot(BeamerDelegate delegate) async {
  bool canPop = true;
  while (canPop) {
    canPop = await delegate.popRoute();
  }
}


RoutesLocationBuilder getRouteLocation(Widget page, String path) {
  return RoutesLocationBuilder(
    routes: {
      '/$path': (context, state, data) => page,
    },
  );
}
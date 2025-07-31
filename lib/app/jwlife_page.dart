import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/home/pages/home_page.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import '../features/bible/pages/bible_page.dart';
import '../features/meetings/pages/meeting_page.dart';
import '../features/predication/pages/predication_page.dart';
import 'package:jwlife/features/congregation/pages/congregation_page.dart';
import 'package:jwlife/features/library/pages/library_page.dart';
import 'package:jwlife/features/personal/pages/personal_page.dart';

import '../core/icons.dart';
import 'package:jwlife/i18n/localization.dart';

import '../features/audio/audio_player_widget.dart';
import '../widgets/custom_bottom_navigation_item.dart';

class JwLifePage extends StatefulWidget {
  const JwLifePage({super.key});

  @override
  State<JwLifePage> createState() => JwLifePageState();
}

class JwLifePageState extends State<JwLifePage> {
  final List<bool> navBarVisible = [true, true, true, true, true, true, true];
  final List<bool> navBarIsBlack = [false, false, false, false, false, false, false];
  final List<bool> navBarIsPositioned = [false, false, false, false, false, false, false];

  bool audioWidgetVisible = false;
  int currentIndex = 0;
  bool resizeToAvoidBottomInset = false;

  late final List<Widget> _pages;

  final List<GlobalKey<NavigatorState>> navigatorKeys = List.generate(7, (_) => GlobalKey<NavigatorState>());

  List<List<GlobalKey<State<StatefulWidget>>>> webViewPageKeys = List.generate(7, (_) => []);

  @override
  void initState() {
    super.initState();

    _pages = [
      HomePage(key: GlobalKeyService.getKey<HomePageState>(PageType.home)),
      BiblePage(key: GlobalKeyService.getKey<BiblePageState>(PageType.bible)),
      LibraryPage(key: GlobalKeyService.getKey<LibraryPageState>(PageType.library)),
      MeetingsPage(key: GlobalKeyService.getKey<MeetingsPageState>(PageType.meetings)),
      PredicationPage(key: GlobalKeyService.getKey<PredicationPageState>(PageType.predication)),
      CongregationPage(key: GlobalKeyService.getKey<CongregationPageState>(PageType.congregation)),
      PersonalPage(key: GlobalKeyService.getKey<PersonalPageState>(PageType.personal)),
    ];
  }

  void toggleNavBarVisibility(bool isVisible) {
    if(navBarVisible[currentIndex] != isVisible) {
      _updateSystemUiMode(isVisible);
      setState(() {
        navBarVisible[currentIndex] = isVisible;
      });
    }
  }

  void toggleNavBarBlack(bool isBlack) {
    if(navBarIsBlack[currentIndex] != isBlack) {
      setState(() {
        navBarIsBlack[currentIndex] = isBlack;
        navBarVisible[currentIndex] = true;
      });
    }
  }

  void toggleNavBarPositioned(bool isPositioned) {
    if(navBarIsPositioned[currentIndex] != isPositioned) {
      setState(() {
        navBarIsPositioned[currentIndex] = isPositioned;
        navBarVisible[currentIndex] = true;
      });
    }
  }

  void toggleAudioWidgetVisibility(bool isVisible) {
    setState(() {
      audioWidgetVisible = isVisible;
    });
  }

  void _updateSystemUiMode(bool isVisible) {
    if (!isVisible) {
      if(navBarIsBlack[currentIndex] == true) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive, overlays: SystemUiOverlay.values);
      }
      else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
      }
    }
    else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
    }
  }

  void toggleResizeToAvoidBottomInset(bool resize) {
    setState(() {
      resizeToAvoidBottomInset = resize;
    });
  }

  void handleBack(BuildContext context) {
    final currentNavigator = navigatorKeys[currentIndex].currentState!;

    if (currentNavigator.canPop()) {
      currentNavigator.pop();

      bool needsUpdate = false;

      if (!navBarVisible[currentIndex]) {
        navBarVisible[currentIndex] = true;
        needsUpdate = true;
      }
      if (navBarIsPositioned[currentIndex]) {
        navBarIsPositioned[currentIndex] = false;
        needsUpdate = true;
      }
      if (navBarIsBlack[currentIndex]) {
        navBarIsBlack[currentIndex] = false;
        needsUpdate = true;
      }

      if (needsUpdate) {
        setState(() {});
      }

      _updateSystemUiMode(true);
    }
    else {
      showJwDialog(
        context: context,
        titleText: 'Quitter',
        contentText: 'Voulez-vous vraiment quitter l\'application JW life ?',
        buttons: [
          JwDialogButton(label: 'ANNULER', closeDialog: true),
          JwDialogButton(
            label: 'QUITTER',
            closeDialog: false,
            onPressed: (buildContext) async {
              await SystemNavigator.pop();
            },
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if(webViewPageKeys[currentIndex].isNotEmpty) {
          final webViewPageState = webViewPageKeys[currentIndex].last.currentState!;
          if(webViewPageState is DocumentPageState) {
            webViewPageState.handleBackPress();
            return;
          }
          else if (webViewPageState is DailyTextPageState) {
            webViewPageState.handleBackPress();
            return;
          }
        }
        if (didPop) return;
        handleBack(context); // même logique aussi
      },
      child: IndexedStack(
        index: currentIndex,
        children: List.generate(_pages.length, (index) {
          return Navigator(
            key: navigatorKeys[index],
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
      maintainState: true,
      visible: audioWidgetVisible && !navBarIsBlack[currentIndex] && navBarVisible[currentIndex],
      child: AudioPlayerWidget(),
    );

    final Widget bottomNavWidget = Visibility(
      maintainState: true,
      visible: navBarVisible[currentIndex],
      child: CustomBottomNavigation(
        currentIndex: currentIndex,
        selectedFontSize: 8.5,
        unselectedFontSize: 8.0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        backgroundColor: navBarIsBlack[currentIndex]
            ? Colors.transparent
            : Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        selectedIconTheme: IconThemeData(
            color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor
        ),
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: navBarIsBlack[currentIndex]
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
          if (index == currentIndex) {
            navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
            webViewPageKeys[index].clear();
            setState(() {
              navBarVisible[currentIndex] = true;
              navBarIsBlack[index] = false;
              navBarIsPositioned[index] = false;
            });
          }
          else {
            GlobalKeyService.setCurrentPage(navigatorKeys[index]);
            setState(() {
              currentIndex = index;
            });
          }
        },
      )
    );

    return Scaffold(
      resizeToAvoidBottomInset: navBarIsPositioned[currentIndex] || navBarIsBlack[currentIndex] ? false : resizeToAvoidBottomInset,
      body: navBarIsPositioned[currentIndex] || navBarIsBlack[currentIndex]
          ? Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            left: 0,
            right: 0,
            bottom: 72.0,
            child: audioWidget,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: bottomNavWidget,
          ),
        ],
      ) : Column(
        children: [
          Expanded(child: content),
          audioWidget
        ],
      ),
      bottomNavigationBar: navBarIsPositioned[currentIndex] || navBarIsBlack[currentIndex] ? null : bottomNavWidget,
    );
  }
}

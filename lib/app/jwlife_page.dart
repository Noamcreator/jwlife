import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/home/pages/home_page.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/features/publication/pages/document/local/full_screen_image_page.dart';
import 'package:jwlife/features/video/video_player_page.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import '../data/databases/history.dart';
import '../features/bible/pages/bible_page.dart';
import '../features/image_page.dart';
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
  final List<bool> navBarIsDisable = [false, false, false, false, false, false, false];

  bool audioWidgetVisible = false;
  int currentNavigationBottomBarIndex = 0;
  bool resizeToAvoidBottomInset = false;

  late final List<Widget> _pages;

  final List<GlobalKey<NavigatorState>> navigatorKeys = List.generate(7, (_) => GlobalKey<NavigatorState>());
  List<List<GlobalKey<State<StatefulWidget>>>> webViewPageKeys = List.generate(7, (_) => []);

  final Map<int, List<Widget>> pagesByNavigator = {};

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
    _updateSystemUiMode(isVisible);
  }

  void toggleNavBarDisable(bool isDisable) {
    if (navBarIsDisable[currentNavigationBottomBarIndex] != isDisable) {
      setState(() {
        navBarIsDisable[currentNavigationBottomBarIndex] = isDisable;
      });
    }
  }

  void toggleAudioWidgetVisibility(bool isVisible) {
    setState(() {
      audioWidgetVisible = isVisible;
    });

    for(var key in webViewPageKeys) {
      for(var state in key) {
        state.currentState!.setState(() {});
      }
    }
  }

  void _updateSystemUiMode(bool isVisible) {
    if (!isVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack, overlays: SystemUiOverlay.values);
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

  Future<void> handleBack(BuildContext context) async {
    final currentNavigator = navigatorKeys[currentNavigationBottomBarIndex].currentState!;

    final currentPages = pagesByNavigator[currentNavigationBottomBarIndex];
    final currentWebKeys = webViewPageKeys[currentNavigationBottomBarIndex];

    if (currentPages != null && currentPages.isNotEmpty) {
      final lastPage = currentPages.last;

      if (currentWebKeys.isNotEmpty && lastPage is DocumentPage) {
        final webViewPageState = currentWebKeys.last.currentState;
        if (webViewPageState is DocumentPageState) {
          if (!await webViewPageState.handleBackPress(fromPopScope: true)) {
            return;
          }
          currentWebKeys.removeLast();
        }
        else if (webViewPageState is DailyTextPageState) {
          if (!await webViewPageState.handleBackPress(fromPopScope: true)) {
            return;
          }
          currentWebKeys.removeLast();
        }
      }
    }

    Widget? pageBeforePop;

    if (currentPages != null && currentPages.length >= 2) {
      pageBeforePop = currentPages[currentPages.length - 2];
    }

    if (currentNavigator.canPop()) {
      currentNavigator.pop();

      final currentPages = pagesByNavigator[currentNavigationBottomBarIndex];
      if (currentPages != null && currentPages.isNotEmpty) {
        final lastPage = currentPages.last;

        printTime('lastPage: ${lastPage.runtimeType}');

        if (pageBeforePop != null) {
          printTime('previousPage: ${pageBeforePop.runtimeType}');

          if (pageBeforePop is DocumentPage || pageBeforePop is DailyTextPage || pageBeforePop is FullScreenImagePage || pageBeforePop is ImagePage || pageBeforePop is VideoPlayerPage) {
            if (!navBarIsDisable[currentNavigationBottomBarIndex]) {
              setState(() {
                navBarIsDisable[currentNavigationBottomBarIndex] = true;
              });
            }
          }
          else {
            if (navBarIsDisable[currentNavigationBottomBarIndex]) {
              setState(() {
                navBarIsDisable[currentNavigationBottomBarIndex] = false;
              });
            }
          }
        }
        else {
          if (navBarIsDisable[currentNavigationBottomBarIndex]) {
            setState(() {
              navBarIsDisable[currentNavigationBottomBarIndex] = false;
            });
          }
        }
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

  void changeNavBarIndex(int index) {
    if (index == currentNavigationBottomBarIndex) {
      navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
      webViewPageKeys[index].clear();
      setState(() {
        navBarIsDisable[index] = false;
      });
    }
    else {
      GlobalKeyService.setCurrentPage(navigatorKeys[index]);
      setState(() {
        currentNavigationBottomBarIndex = index;
      });
    }
  }

  void addPageToTab(Widget page) {
    // Initialise la liste pour l'onglet s'il n'existe pas encore
    pagesByNavigator.putIfAbsent(currentNavigationBottomBarIndex, () => []);

    // Ajoute la page à la liste des pages ouvertes de cet onglet
    pagesByNavigator[currentNavigationBottomBarIndex]!.add(page);
  }

  void removePageFromTab() {
    // Supprime la page de la liste des pages ouvertes de cet onglet
    if (pagesByNavigator[currentNavigationBottomBarIndex]!.isNotEmpty) {
      pagesByNavigator[currentNavigationBottomBarIndex]!.removeLast();
    }
  }

  NavigatorState getCurrentState() {
    return navigatorKeys[currentNavigationBottomBarIndex].currentState!;
  }

  Widget getBottomNavigationBar({bool isBlack = false}) {
    return CustomBottomNavigation(
      currentIndex: currentNavigationBottomBarIndex,
      selectedFontSize: 8.5,
      unselectedFontSize: 8.0,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      backgroundColor: isBlack ? Colors.transparent : Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      selectedIconTheme: IconThemeData(color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor),
      selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor: isBlack
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
        changeNavBarIndex(index);
      },
      onLongPress: (index) {
        if (index != currentNavigationBottomBarIndex) {
          GlobalKeyService.setCurrentPage(navigatorKeys[index]);
          setState(() {
            currentNavigationBottomBarIndex = index;
          });
        }
        BuildContext context = navigatorKeys[index].currentContext!;
        History.showHistoryDialog(context, bottomBarIndex: index);
      }
    );
  }

  Widget getAudioWidget() {
    return AudioPlayerWidget();
  }

  @override
  Widget build(BuildContext context) {
    final Widget bottomNavigationBar = getBottomNavigationBar();

    final Widget content = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        handleBack(context);
      },
      child: IndexedStack(
        index: currentNavigationBottomBarIndex,
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

    return Scaffold(
      resizeToAvoidBottomInset: navBarIsDisable[currentNavigationBottomBarIndex] ? false : resizeToAvoidBottomInset,
      body: Column(
        children: [
          Expanded(child: content),
          audioWidgetVisible && !navBarIsDisable[currentNavigationBottomBarIndex] ? getAudioWidget() : Container(),
        ],
      ),
      bottomNavigationBar: navBarIsDisable[currentNavigationBottomBarIndex] ? null : bottomNavigationBar,
    );
  }
}

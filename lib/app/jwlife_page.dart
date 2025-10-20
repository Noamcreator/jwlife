import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/home/pages/home_page.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/features/publication/pages/document/local/full_screen_image_page.dart';
import 'package:jwlife/features/video/video_player_page.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import '../data/databases/history.dart';
import '../features/bible/pages/bible_page.dart';
import '../features/image/image_page.dart';
import '../features/workship/pages/workship_page.dart';
import '../features/predication/pages/predication_page.dart';
import 'package:jwlife/features/library/pages/library_page.dart';
import 'package:jwlife/features/personal/pages/personal_page.dart';

import '../core/icons.dart';
import 'package:jwlife/i18n/localization.dart';

import '../features/audio/audio_player_widget.dart';
import '../widgets/long_press_bottom_navigation_bar.dart';
import '../widgets/slide_indexed_stack.dart';

class JwLifePage extends StatefulWidget {
  const JwLifePage({super.key});

  @override
  State<JwLifePage> createState() => JwLifePageState();
}

class JwLifePageState extends State<JwLifePage> {
  final List<bool> navBarIsDisable = [false, false, false, false, false, false];
  final List<bool> navBarIsTransparent = [false, false, false, false, false, false];
  final List<bool> resizeToAvoidBottomInset = [false, false, false, false, false, false];

  bool audioWidgetVisible = false;
  int currentNavigationBottomBarIndex = 0;
  bool _popMenuOpen = false;

  late final List<Widget> _pages;

  final List<GlobalKey<NavigatorState>> navigatorKeys = List.generate(6, (_) => GlobalKey<NavigatorState>());
  List<List<GlobalKey<State<StatefulWidget>>>> webViewPageKeys = List.generate(6, (_) => []);

  final Map<int, List<Widget>> pagesByNavigator = {};

  final ValueNotifier<bool> controlsVisible = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();

    _pages = [
      HomePage(key: GlobalKeyService.getKey<HomePageState>(PageType.home)),
      BiblePage(key: GlobalKeyService.getKey<BiblePageState>(PageType.bible)),
      LibraryPage(key: GlobalKeyService.getKey<LibraryPageState>(PageType.library)),
      WorkShipPage(key: GlobalKeyService.getKey<WorkShipPageState>(PageType.workShip)),
      PredicationPage(key: GlobalKeyService.getKey<PredicationPageState>(PageType.predication)),
      PersonalPage(key: GlobalKeyService.getKey<PersonalPageState>(PageType.personal)),
    ];
  }

  @override
  void dispose() {
    controlsVisible.dispose();
    super.dispose();
  }

  void toggleBottomNavBarVisibility(bool isVisible) {
    controlsVisible.value = isVisible;
  }

  void toggleNavBarVisibility(bool isVisible) {
    toggleBottomNavBarVisibility(isVisible);
    _updateSystemUiMode(isVisible);
  }

  void toggleNavBarDisable(bool isDisable) {
    if (navBarIsDisable[currentNavigationBottomBarIndex] != isDisable) {
      setState(() {
        navBarIsDisable[currentNavigationBottomBarIndex] = isDisable;
      });
    }
  }

  void toggleNavBarTransparent(bool isDisable) {
    if (navBarIsTransparent[currentNavigationBottomBarIndex] != isDisable) {
      setState(() {
        navBarIsTransparent[currentNavigationBottomBarIndex] = isDisable;
      });
    }
  }

  void toggleAudioWidgetVisibility(bool isVisible) {
    setState(() {
      audioWidgetVisible = isVisible;
    });

    for (var keys in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys) {
      for (var key in keys) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.toggleAudioPlayer(isVisible);
        }
        else if (state is DailyTextPageState) {
          state.toggleAudioPlayer(isVisible);
        }
      }
    }
  }

  void togglePopMenuOpen(bool isOpen) {
    if (_popMenuOpen != isOpen) {
      _popMenuOpen = isOpen;
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

  void toggleResizeToAvoidBottomInset(bool resizeToAvoidBottom) {
    if (resizeToAvoidBottomInset[currentNavigationBottomBarIndex] != resizeToAvoidBottom) {
      setState(() {
        resizeToAvoidBottomInset[currentNavigationBottomBarIndex] = resizeToAvoidBottom;
      });
    }
  }

  Future<void> handleBack<T>(BuildContext context, {T? result}) async {
    final currentNavigator = navigatorKeys[currentNavigationBottomBarIndex].currentState!;
    final currentPages = pagesByNavigator[currentNavigationBottomBarIndex];
    final currentWebKeys = webViewPageKeys[currentNavigationBottomBarIndex];

    if (_popMenuOpen) {
      togglePopMenuOpen(false);
      if (currentNavigator.canPop()) {
        result == null ? currentNavigator.pop() : currentNavigator.pop(result);
      }
      return;
    }

    if (currentPages != null && currentPages.isNotEmpty) {
      final lastPage = currentPages.last;
      if (currentWebKeys.isNotEmpty && (lastPage is DocumentPage || lastPage is DailyTextPage)) {
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

    final canPop = currentNavigator.canPop();

    if (canPop) {
      final pageBeforePop = currentPages != null && currentPages.length >= 2 ? currentPages[currentPages.length - 2] : null;

      result == null ? currentNavigator.pop() : currentNavigator.pop(result);

      _updateUiBasedOnPreviousPage(pageBeforePop);
      _updateSystemUiMode(true);
    }
    else if (currentNavigationBottomBarIndex != 0) {
      changeNavBarIndex(0);
    }
    else {
      _showExitConfirmationDialog(context);
    }
  }

  void _updateUiBasedOnPreviousPage(Widget? pageBeforePop) {
    final shouldDisableNavBar = pageBeforePop is DocumentPage || pageBeforePop is DailyTextPage;

    final shouldDisableTransparentNavBar = pageBeforePop is FullScreenImagePage
        || pageBeforePop is ImagePage || pageBeforePop is VideoPlayerPage;

    setState(() {
      navBarIsDisable[currentNavigationBottomBarIndex] = shouldDisableNavBar;
      navBarIsTransparent[currentNavigationBottomBarIndex] = shouldDisableTransparentNavBar;
    });

    final currentPages = pagesByNavigator[currentNavigationBottomBarIndex];
    if (currentPages != null && currentPages.isNotEmpty && currentPages.last is NotePage) {
      setState(() {
        resizeToAvoidBottomInset[currentNavigationBottomBarIndex] = false;
      });
    }
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showJwDialog(
      context: context,
      titleText: 'Quitter',
      contentText: 'Voulez-vous vraiment quitter l\'application JW life ?',
      buttons: [
        JwDialogButton(label: 'ANNULER', closeDialog: true),
        JwDialogButton(
          label: 'QUITTER',
          closeDialog: true,
          onPressed: (_) async {
            await SystemNavigator.pop();
          },
        ),
      ],
    );
  }

  void returnToFirstPage(int index) {
    navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    webViewPageKeys[index].clear();
    setState(() {
      navBarIsDisable[index] = false;
      navBarIsTransparent[index] = false;
    });

    if(index == 1) {
      GlobalKeyService.bibleKey.currentState?.goToTheBooksTab();
    }
    else if(index == 2) {
      GlobalKeyService.libraryKey.currentState?.goToThePubsTab();
    }
    else if(index == 3) {
      GlobalKeyService.workShipKey.currentState?.goToTheMeetingsTab();
    }
  }

  void changeNavBarIndex(int index) {
    if (index == currentNavigationBottomBarIndex) {
      returnToFirstPage(index);
    }
    else {
      GlobalKeyService.setCurrentPage(navigatorKeys[index]);
      setState(() {
        currentNavigationBottomBarIndex = index;
      });

      for (var key in GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[index]) {
        final state = key.currentState;

        if (state is DocumentPageState) {
          state.updateBottomBar();
        }
        else if (state is DailyTextPageState) {
          state.updateBottomBar();
        }
      }
    }
  }

  void addPageToTab(Widget page) {
    pagesByNavigator.putIfAbsent(currentNavigationBottomBarIndex, () => []);
    pagesByNavigator[currentNavigationBottomBarIndex]!.add(page);
  }

  void removePageFromTab() {
    if (pagesByNavigator[currentNavigationBottomBarIndex]!.isNotEmpty) {
      pagesByNavigator[currentNavigationBottomBarIndex]!.removeLast();
    }
  }

  NavigatorState getCurrentState() {
    return navigatorKeys[currentNavigationBottomBarIndex].currentState!;
  }

  Widget _buildBottomNavigationBar({bool isTransparent = false}) {
    return LongPressBottomNavBar(
      currentIndex: currentNavigationBottomBarIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: isTransparent ? Colors.transparent : Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor: isTransparent ? Colors.white : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5),
      unselectedLabelStyle: const TextStyle(fontSize: 8.0),
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
        // Faire vibre le tel
        HapticFeedback.lightImpact();

        History.showHistoryDialog(context, bottomBarIndex: index);
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(JwIcons.home),
          label: localization(context).navigation_home,
        ),
        BottomNavigationBarItem(
          icon: const Icon(JwIcons.bible),
          label: localization(context).navigation_bible,
        ),
        BottomNavigationBarItem(
          icon: const Icon(JwIcons.publication_video_music),
          label: localization(context).navigation_library,
        ),
        BottomNavigationBarItem(
          icon: const Icon(JwIcons.speaker_audience),
          label: localization(context).navigation_workship,
        ),
        BottomNavigationBarItem(
          icon: const Icon(JwIcons.persons_doorstep),
          label: localization(context).navigation_predication,
        ),
        BottomNavigationBarItem(
          icon: const Icon(JwIcons.person_studying),
          label: localization(context).navigation_personal,
        ),
      ],
    );
  }

  Widget getAudioWidget() {
    return AudioPlayerWidget();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = navBarIsDisable[currentNavigationBottomBarIndex] || navBarIsTransparent[currentNavigationBottomBarIndex];
    final bool isTransparent = navBarIsTransparent[currentNavigationBottomBarIndex];

    final Widget content = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          handleBack(context);
        },
        child: Padding(
          padding: EdgeInsets.only(bottom: !isDisabled ? 70 : 0),
          child: LazyIndexedStack(
            index: currentNavigationBottomBarIndex,
            initialIndexes: [0, 2],
            builders: List.generate(_pages.length, (index) {
              return (_) => Navigator(
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
        )
    );

    return Scaffold(
      resizeToAvoidBottomInset: isDisabled ? false : resizeToAvoidBottomInset[currentNavigationBottomBarIndex],
      body: Stack(
        children: [
          content,
          ValueListenableBuilder<bool>(
            valueListenable: controlsVisible,
            builder: (context, isVisible, child) {
              if (!isVisible) return const SizedBox.shrink();
              return child!;
            },
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (audioWidgetVisible) getAudioWidget(),
                  _buildBottomNavigationBar(isTransparent: isTransparent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
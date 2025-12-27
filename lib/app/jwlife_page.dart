import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/document/local/document_page.dart';
import 'package:jwlife/features/image/pages/full_screen_image_page.dart';
import 'package:jwlife/features/video/video_player_page.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import '../data/databases/history.dart';

import '../core/icons.dart';
import 'package:jwlife/i18n/i18n.dart';

import '../features/audio/audio_player_widget.dart';
import '../widgets/long_press_bottom_navigation_bar.dart';
import 'container.dart';

class JwLifePage extends StatefulWidget {
  const JwLifePage({super.key});

  @override
  State<JwLifePage> createState() => JwLifePageState();
}

class JwLifePageState extends State<JwLifePage> with WidgetsBindingObserver {
  final ValueNotifier<List<bool>> navBarIsTransparentNotifier = ValueNotifier<List<bool>>([false, false, false, false, false, false]);

  final ValueNotifier<bool> audioWidgetVisible = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentNavigationBottomBarIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> controlsVisible = ValueNotifier<bool>(true);

  bool _popMenuOpen = false;

  final List<GlobalKey<NavigatorState>> navigatorKeys = List.generate(6, (_) => GlobalKey<NavigatorState>());
  List<List<GlobalKey<State<StatefulWidget>>>> webViewPageKeys = List.generate(6, (_) => []);

  final Map<int, List<Widget>> pagesByNavigator = {};

  Orientation orientation = Orientation.portrait;

  final ValueNotifier<Set<int>> loadedNavigators = ValueNotifier<Set<int>>({0});

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controlsVisible.dispose();
    navBarIsTransparentNotifier.dispose();
    super.dispose();
  }

  void toggleBottomNavBarVisibility(bool isVisible) {
    controlsVisible.value = isVisible;
  }

  void toggleNavBarVisibility(bool isVisible) {
    toggleBottomNavBarVisibility(isVisible);
    _updateSystemUiMode(isVisible);
  }

  void toggleNavBarTransparent(bool isDisable) {
    final int currentIndex = currentNavigationBottomBarIndex.value;
    final List<bool> currentList = navBarIsTransparentNotifier.value;

    if (currentList[currentIndex] != isDisable) {
      final List<bool> newList = List<bool>.from(currentList);
      newList[currentIndex] = isDisable;

      navBarIsTransparentNotifier.value = newList;
    }
  }

  void toggleAudioWidgetVisibility(bool isVisible) {
    audioWidgetVisible.value = isVisible;

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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    }
    else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);
    }
  }

  Future<void> handleBack<T>(BuildContext context, {T? result}) async {
    final currentNavigator = navigatorKeys[currentNavigationBottomBarIndex.value].currentState!;
    final currentPages = pagesByNavigator[currentNavigationBottomBarIndex.value];
    final currentWebKeys = webViewPageKeys[currentNavigationBottomBarIndex.value];

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
      else if (lastPage is VideoPlayerPage) {
        Orientation currentOrientation = MediaQuery.of(context).orientation;
        if (currentOrientation != orientation) {
          if(orientation == Orientation.portrait) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          }
          else if (orientation == Orientation.landscape) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          }
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
    else if (currentNavigationBottomBarIndex.value != 0) {
      changeNavBarIndex(0);
    }
    else {
      _showExitConfirmationDialog(context);
    }
  }

  void _updateUiBasedOnPreviousPage(Widget? pageBeforePop) {
    final shouldDisableTransparentNavBar = pageBeforePop is FullScreenImagePage || pageBeforePop is VideoPlayerPage;
    final int currentIndex = currentNavigationBottomBarIndex.value;
    final List<bool> currentTransparentList = navBarIsTransparentNotifier.value;

    if(currentTransparentList[currentIndex] != shouldDisableTransparentNavBar) {
      final List<bool> newList = List<bool>.from(currentTransparentList);
      newList[currentIndex] = shouldDisableTransparentNavBar;
      navBarIsTransparentNotifier.value = newList;
    }
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showJwDialog(
      context: context,
      titleText: 'Quitter',
      contentText: 'Voulez-vous vraiment quitter l\'application JW life ?',
      buttons: [
        JwDialogButton(label: i18n().action_cancel_uppercase, closeDialog: true),
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

    final List<bool> currentList = navBarIsTransparentNotifier.value;
    if(currentList[index] != false) {
      final List<bool> newList = List<bool>.from(currentList);
      newList[index] = false;
      navBarIsTransparentNotifier.value = newList;
    }

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

  void changeNavBarIndex(int index, {bool goToFirstPage = false}) {
    if (index == currentNavigationBottomBarIndex.value) {
      returnToFirstPage(index);
    }
    else if(goToFirstPage) {
      GlobalKeyService.setCurrentPage(navigatorKeys[index]);
      currentNavigationBottomBarIndex.value = index;

      returnToFirstPage(index);
    }
    else {
      GlobalKeyService.setCurrentPage(navigatorKeys[index]);
      currentNavigationBottomBarIndex.value = index;
    }
  }

  void addPageToTab(Widget page) {
    pagesByNavigator.putIfAbsent(currentNavigationBottomBarIndex.value, () => []);
    pagesByNavigator[currentNavigationBottomBarIndex.value]!.add(page);
  }

  void removePageFromTab() {
    if (pagesByNavigator[currentNavigationBottomBarIndex.value]!.isNotEmpty) {
      pagesByNavigator[currentNavigationBottomBarIndex.value]!.removeLast();
    }
  }

  NavigatorState getCurrentState() {
    return navigatorKeys[currentNavigationBottomBarIndex.value].currentState!;
  }

  void loadAllNavigator() {
    if (mounted) {
      loadedNavigators.value = {...loadedNavigators.value, 1, 2, 3, 4, 5};
    }
  }

  Widget _createNavigator(int index) {
    switch (index) {
      case 0:
        return Navigator(
          key: navigatorKeys[0],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (_) => const HomePageContainer(),
              settings: settings,
            );
          },
        );
      case 1:
        return Navigator(
          key: navigatorKeys[1],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (_) => const BiblePageContainer(),
              settings: settings,
            );
          },
        );
      case 2:
        return Navigator(
          key: navigatorKeys[2],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (_) => const LibraryPageContainer(),
              settings: settings,
            );
          },
        );
      case 3:
        return Navigator(
          key: navigatorKeys[3],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (_) => const WorkShipPageContainer(),
              settings: settings,
            );
          },
        );
      case 4:
        return Navigator(
          key: navigatorKeys[4],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (_) => const PredicationPageContainer(),
              settings: settings,
            );
          },
        );
      case 5:
        return Navigator(
          key: navigatorKeys[5],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (_) => const PersonalPageContainer(),
              settings: settings,
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removeViewInsets(
      removeBottom: true, // empêche les rebuilds liés au clavier
      context: context,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        extendBodyBehindAppBar: true,

        body: Stack(
          children: [
            // --- CONTENU PRINCIPAL AVEC NAVIGATORS ---
            PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                handleBack(context);
              },
              child: ValueListenableBuilder<int>(
                valueListenable: currentNavigationBottomBarIndex,
                builder: (context, index, child) {
                  return ValueListenableBuilder<Set<int>>(
                    valueListenable: loadedNavigators,
                    builder: (context, loaded, _) {
                      return IndexedStack(
                        index: index,
                        children: List.generate(6, (i) {
                          if (i == index || loaded.contains(i)) {
                            return _createNavigator(i);
                          }
                          return const SizedBox.shrink();
                        }),
                      );
                    },
                  );
                },
              ),
            ),

            // --- BOTTOM BAR + AUDIO WIDGET ---
            ValueListenableBuilder<bool>(
              valueListenable: controlsVisible,
              builder: (context, isVisible, _) {
                if (!isVisible) return const SizedBox.shrink();

                return ValueListenableBuilder<int>(
                  valueListenable: currentNavigationBottomBarIndex,
                  builder: (context, currentIndex, _) {
                    return ValueListenableBuilder<List<bool>>(
                      valueListenable: navBarIsTransparentNotifier,
                      builder: (context, navBarTransparentList, _) {
                        final bool isTransparent = navBarTransparentList[currentIndex];

                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // --- AUDIO WIDGET ---
                              ValueListenableBuilder<bool>(
                                valueListenable: audioWidgetVisible,
                                builder: (context, audioVisible, child) {
                                  if (!audioVisible || isTransparent) return const SizedBox.shrink();
                                  return child!;
                                },
                                child: const AudioPlayerWidget(),
                              ),

                              // --- NAVIGATION BAR ---
                              LongPressBottomNavBar(
                                currentIndex: currentIndex,
                                type: BottomNavigationBarType.fixed,
                                backgroundColor: isTransparent
                                    ? Colors.transparent
                                    : Theme.of(context).bottomNavigationBarTheme.backgroundColor,

                                selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
                                unselectedItemColor: isTransparent
                                    ? Colors.white
                                    : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,

                                selectedLabelStyle: const TextStyle(fontSize: 9),
                                unselectedLabelStyle: const TextStyle(fontSize: 8.0),

                                onTap: (index) {
                                  changeNavBarIndex(index);
                                },

                                onLongPress: (index) {
                                  if (index != currentNavigationBottomBarIndex.value) {
                                    GlobalKeyService.setCurrentPage(navigatorKeys[index]);
                                    currentNavigationBottomBarIndex.value = index;
                                  }

                                  final BuildContext context = navigatorKeys[index].currentContext!;
                                  HapticFeedback.lightImpact();
                                  History.showHistoryDialog(context, bottomBarIndex: index);
                                },

                                items: [
                                  BottomNavigationBarItem(
                                    icon: const Icon(JwIcons.home),
                                    label: i18n().navigation_home,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(JwIcons.bible),
                                    label: i18n().navigation_bible,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(JwIcons.publication_video_music),
                                    label: i18n().navigation_library,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(JwIcons.speaker_audience),
                                    label: i18n().navigation_workship,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(JwIcons.persons_doorstep),
                                    label: i18n().navigation_predication,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(JwIcons.person_studying),
                                    label: i18n().navigation_personal,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
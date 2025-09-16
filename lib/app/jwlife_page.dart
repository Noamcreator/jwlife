import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/features/home/pages/daily_text_page.dart';
import 'package:jwlife/features/home/pages/home_page.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';
import 'package:jwlife/features/publication/pages/document/local/document_page.dart';
import 'package:jwlife/features/publication/pages/document/local/full_screen_image_page.dart';
import 'package:jwlife/features/video/video_player_page.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import '../data/databases/history.dart';
import '../features/bible/pages/bible_page.dart';
import '../features/image/image_page.dart';
import '../features/meetings/pages/meeting_page.dart';
import '../features/predication/pages/predication_page.dart';
import 'package:jwlife/features/congregation/pages/congregation_page.dart';
import 'package:jwlife/features/library/pages/library_page.dart';
import 'package:jwlife/features/personal/pages/personal_page.dart';

import '../core/icons.dart';
import 'package:jwlife/i18n/localization.dart';

import '../features/audio/audio_player_widget.dart';
import '../widgets/custom_bottom_navigation_item.dart';
import '../widgets/slide_indexed_stack.dart';

class JwLifePage extends StatefulWidget {
  const JwLifePage({super.key});

  @override
  State<JwLifePage> createState() => JwLifePageState();
}

class JwLifePageState extends State<JwLifePage> {
  final List<bool> navBarIsDisable = [false, false, false, false, false, false, false];
  final List<bool> resizeToAvoidBottomInset = [false, false, false, false, false, false, false];

  bool audioWidgetVisible = false;
  int currentNavigationBottomBarIndex = 0;
  bool _popMenuOpen = false;

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

  // Code optimisé
  Future<void> handleBack<T>(BuildContext context, {T? result}) async {
    final currentNavigator = navigatorKeys[currentNavigationBottomBarIndex].currentState!;
    final currentPages = pagesByNavigator[currentNavigationBottomBarIndex];
    final currentWebKeys = webViewPageKeys[currentNavigationBottomBarIndex];

    // Cas 1: Le menu contextuel est ouvert
    if (_popMenuOpen) {
      togglePopMenuOpen(false);
      if (currentNavigator.canPop()) {
        result == null ? currentNavigator.pop() : currentNavigator.pop(result);
      }
      return;
    }

    // Cas 2: Gestion des pages web spécifiques
    if (currentPages != null && currentPages.isNotEmpty) {
      final lastPage = currentPages.last;
      if (currentWebKeys.isNotEmpty && (lastPage is DocumentPage || lastPage is DailyTextPage)) {
        final webViewPageState = currentWebKeys.last.currentState;

        // Un seul bloc pour gérer les deux types de pages WebView
        if (webViewPageState is DocumentPageState) {
          if (!await webViewPageState.handleBackPress(fromPopScope: true)) {
            return; // La WebView a géré le retour, on s'arrête là
          }
          currentWebKeys.removeLast();
        }
        else if (webViewPageState is DailyTextPageState) {
          if (!await webViewPageState.handleBackPress(fromPopScope: true)) {
            return; // La WebView a géré le retour, on s'arrête là
          }
          currentWebKeys.removeLast();
        }
      }
    }

    final canPop = currentNavigator.canPop();

    // Cas 3: La navigation est possible dans l'onglet
    if (canPop) {
      final pageBeforePop = currentPages != null && currentPages.length >= 2 ? currentPages[currentPages.length - 2] : null;

      // Fermeture de la page actuelle
      result == null ? currentNavigator.pop() : currentNavigator.pop(result);

      // Mise à jour de l'UI basée sur la page précédente
      _updateUiBasedOnPreviousPage(pageBeforePop);
      _updateSystemUiMode(true);
    }
    // Cas 4: On est sur la page racine d'un onglet, on change d'onglet
    else if (currentNavigationBottomBarIndex != 0) {
      changeNavBarIndex(0);
    }
    // Cas 5: On est sur la page racine de l'onglet principal, on propose de quitter
    else {
      _showExitConfirmationDialog(context);
    }
  }

  void _updateUiBasedOnPreviousPage(Widget? pageBeforePop) {
    // Gestion de la barre de navigation
    final shouldDisableNavBar = pageBeforePop is DocumentPage ||
        pageBeforePop is DailyTextPage ||
        pageBeforePop is FullScreenImagePage ||
        pageBeforePop is ImagePage ||
        pageBeforePop is VideoPlayerPage;

    setState(() {
      navBarIsDisable[currentNavigationBottomBarIndex] = shouldDisableNavBar;
    });

    // Gestion du clavier si on revient à une NotePage
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
      )
    );

    return Scaffold(
      resizeToAvoidBottomInset: navBarIsDisable[currentNavigationBottomBarIndex] ? false : resizeToAvoidBottomInset[currentNavigationBottomBarIndex],
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

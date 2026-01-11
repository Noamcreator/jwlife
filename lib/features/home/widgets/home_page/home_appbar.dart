import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/uri/utils_uri.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../i18n/i18n.dart';
import '../../../../widgets/dialog/qr_code_dialog.dart';
import '../../../../widgets/multiple_listenable_builder_widget.dart';
import '../../../../widgets/searchfield/searchfield_all_widget.dart';

class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onOpenSettings;

  const HomeAppBar({super.key, required this.onOpenSettings});

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomeAppBarState extends State<HomeAppBar> {
  bool isSearching = false;

  Future<void> onOpenSearch(BuildContext context) async {
    setState(() {
      isSearching = true;
    });
  }

  void onCloseSearch() {
    setState(() {
      isSearching = false;
    });
  }

  void onOpenHistory(BuildContext context) {
    JwLifeApp.history.showHistoryDialog(context);
  }

  Future<void> onOpenQrScanner(BuildContext context) async {
    final Barcode? result = await showQrCodeScanner(context);

    if (result != null) {
      // Le code a été scanné avec succès
      final String? scannedData = result.rawValue;
      print('Code QR scanné : $scannedData');

      JwOrgUri uri = JwOrgUri.parse(scannedData!);
      handleUri(uri);
    }
    else {
      // L'utilisateur a annulé le scanner
      print('Scanner annulé.');
    }
  }

  void onOpenLanguageDialog(BuildContext context) async {
    showLanguageDialog(context).then((language) async {
      if (language != null) {
        await AppSharedPreferences.instance.setLibraryLanguage(language);
        await AppSharedPreferences.instance.setDailyTextLanguage(language);
        await AppSharedPreferences.instance.setArticlesLanguage(language);
        await AppSharedPreferences.instance.setWorkshipLanguage(language);
        await AppSharedPreferences.instance.setTeachingToolboxLanguage(language);
        await AppSharedPreferences.instance.setLatestLanguage(language);
        AppDataService.instance.changeLanguageAndRefreshContent();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return JwLifeAppBar(
        titleWidget: SearchFieldAll(onClose: onCloseSearch),
        handleBackPress: () {
          onCloseSearch();
          return false;
        },
      );
    }

    return JwLifeAppBar(
      canPop: false,
      title: i18n().navigation_home,
      subTitleWidget: MultiValueListenableBuilder(
          listenables: [
            JwLifeSettings.instance.libraryLanguage,
            JwLifeSettings.instance.dailyTextLanguage,
            JwLifeSettings.instance.articlesLanguage,
            JwLifeSettings.instance.workshipLanguage,
            JwLifeSettings.instance.teachingToolboxLanguage,
            JwLifeSettings.instance.latestLanguage
          ],
          builder: (context) {
            // 1. On récupère les valeurs actuelles
            final languages = [
              JwLifeSettings.instance.libraryLanguage.value,
              JwLifeSettings.instance.dailyTextLanguage.value,
              JwLifeSettings.instance.articlesLanguage.value,
              JwLifeSettings.instance.workshipLanguage.value,
              JwLifeSettings.instance.teachingToolboxLanguage.value,
              JwLifeSettings.instance.latestLanguage.value,
            ];

            // 2. On compte l'occurrence de chaque symbole (ex: 'fr', 'en', 'fr' -> {fr: 2, en: 1})
            final counts = <String, int>{};
            for (var lang in languages) {
              counts[lang.symbol] = (counts[lang.symbol] ?? 0) + 1;
            }

            // 3. On trouve le symbole qui a le plus gros score
            final mostUsedSymbol = counts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;

            // 4. On récupère l'objet langue correspondant pour l'affichage
            final favoriteLang = languages.firstWhere((l) => l.symbol == mostUsedSymbol);

            return Text(
              favoriteLang.vernacular,
              style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle,
            );
          }
      ),
      actions: [
        IconTextButton(
          icon: const Icon(JwIcons.magnifying_glass),
          onPressed: onOpenSearch,
        ),
        IconTextButton(
          icon: const Icon(JwIcons.arrow_circular_left_clock),
          onPressed: onOpenHistory,
        ),
        IconTextButton(
          icon: const Icon(JwIcons.language),
          onPressed: onOpenLanguageDialog,
        ),
        IconTextButton(
          icon: const Icon(JwIcons.qr_code),
          onPressed: onOpenQrScanner,
          text: i18n().action_scan_qr_code,
        ),
        IconTextButton(
          icon: const Icon(JwIcons.gear),
          onPressed: (BuildContext context) {
            widget.onOpenSettings();
          },
          text: i18n().action_settings,
        ),
      ],
    );
  }
}

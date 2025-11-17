import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../data/databases/history.dart';
import '../../../../i18n/i18n.dart';
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

  Future<void> onOpenSearch() async {
    setState(() {
      isSearching = true;
    });
  }

  void onCloseSearch() {
    setState(() {
      isSearching = false;
    });
  }

  void onOpenHistory() {
    History.showHistoryDialog(context);
  }

  void onOpenLanguageDialog() async {
    showLanguageDialog(context).then((language) async {
      if (language != null) {
        if (language['Symbol'] != JwLifeSettings().currentLanguage.symbol) {
          await setLibraryLanguage(language);
          GlobalKeyService.homeKey.currentState?.changeLanguageAndRefresh();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    if (isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onCloseSearch,
        ),
        title: SearchFieldAll(onClose: onCloseSearch),
      );
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n().navigation_home, style: textStyleTitle),
          Text(JwLifeSettings().currentLanguage.vernacular, style: textStyleSubtitle),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(JwIcons.magnifying_glass),
          onPressed: onOpenSearch,
        ),
        IconButton(
          icon: const Icon(JwIcons.arrow_circular_left_clock),
          onPressed: onOpenHistory,
        ),
        IconButton(
          icon: const Icon(JwIcons.language),
          onPressed: onOpenLanguageDialog,
        ),
        IconButton(
          icon: const Icon(JwIcons.gear),
          onPressed: widget.onOpenSettings,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/i18n/i18n.dart';

import '../../../app/app_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../publication/pages/local/publication_menu_view.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  BiblePageState createState() => BiblePageState();
}

class BiblePageState extends State<BiblePage> {
  GlobalKey<PublicationMenuViewState>? _bibleMenuPage;
  String? _currentBibleKey;

  void goToTheBooksTab() {
    _bibleMenuPage?.currentState?.goToTheBooksTab();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: JwLifeSettings.instance.lookupBible,
      builder: (context, bibleKey, _) {
        final Publication? currentBible = PublicationRepository().getLookUpBible(bibleKey: bibleKey);

        if (currentBible != null) {
          if (_currentBibleKey != currentBible.getKey()) {
            _currentBibleKey = currentBible.getKey();
            _bibleMenuPage = GlobalKey<PublicationMenuViewState>();
          }

          return ValueListenableBuilder<bool>(
            valueListenable: currentBible.isDownloadedNotifier,
            builder: (context, isDownloaded, _) {
              if (!isDownloaded) {
                return RectanglePublicationItem(publication: currentBible);
              }
              else {
                return PublicationMenuView(
                  key: _bibleMenuPage,
                  publication: currentBible,
                  canPop: false,
                );
              }
            },
          );
        }

        // Aucune Bible sélectionnée
        return AppPage(
          appBar: AppBar(
            title: Text(
              i18n().navigation_bible,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  elevation: 3,
                ),
                onPressed: () async {
                  final bible = await showLanguagePubDialog(context, null);
                  if (bible != null) {
                    final String bibleKey = bible.getKey();
                    JwLifeSettings.instance.lookupBible.value = bibleKey;
                    AppSharedPreferences.instance.setLookUpBible(bibleKey);
                  }
                },
                child: Text(i18n().action_download_bible),
              ),
            ),
          ),
        );
      },
    );
  }
}

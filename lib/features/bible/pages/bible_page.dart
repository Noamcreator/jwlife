import 'package:flutter/material.dart';
import 'package:jwlife/core/shared_preferences/shared_preferences_utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/i18n/localization.dart';

import '../../../app/services/settings_service.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../publication/pages/menu/local/publication_menu_view.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  BiblePageState createState() => BiblePageState();
}

class BiblePageState extends State<BiblePage> {
  Publication? currentBible;
  final GlobalKey<PublicationMenuViewState> _bibleMenuPage = GlobalKey<PublicationMenuViewState>();

  @override
  void initState() {
    super.initState();

    refreshBiblePage();
  }

  void refreshBiblePage() {
    Publication? bible = PublicationRepository().getLookUpBible();
    if (bible != null) {
      setState(() {
        currentBible = bible;
      });
    }
  }

  void goToTheBooksTab() {
    _bibleMenuPage.currentState?.goToTheBooksTab();
  }

  @override
  Widget build(BuildContext context) {
    if (currentBible != null) {
      if(!currentBible!.isDownloadedNotifier.value) {
        return RectanglePublicationItem(publication: currentBible!);
      }
      else {
        return PublicationMenuView(key: _bibleMenuPage, publication: currentBible!, biblePage: true);
      }
    }
    else {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
            title: Text(localization(context).navigation_bible)
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  JwIcons.bible,
                  size: 80,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                    elevation: 3,
                  ),
                  onPressed: () async {
                    showLanguagePubDialog(context, null).then((bible) async {
                      if (bible != null) {
                        String bibleKey = bible.getKey();
                        JwLifeSettings().lookupBible = bibleKey;
                        setLookUpBible(bibleKey);

                        setState(() {
                          currentBible = bible;
                        });
                      }
                    });
                  },
                  icon: const Icon(JwIcons.cloud_arrow_down),
                  label: const Text('Télécharger une Bible'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

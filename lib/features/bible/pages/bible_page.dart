import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/pages/home_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';

import '../../../app/services/global_key_service.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/icons.dart';
import '../../publication/pages/menu/local/publication_menu_view.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  BiblePageState createState() => BiblePageState();
}

class BiblePageState extends State<BiblePage> {
  Publication? _currentBible;
  @override
  void initState() {
    super.initState();

    List<Publication> bibles = PublicationRepository().getAllBibles();
    if (bibles.isNotEmpty) {
      _currentBible = bibles.first;
    }
  }

  void refreshBiblePage() {
    List<Publication> bibles = PublicationRepository().getAllBibles();
    setState(() {
      _currentBible = bibles.firstWhere((element) => element.mepsLanguage.id == JwLifeSettings().currentLanguage.id, orElse: () => bibles.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Build BiblePage');

    if (GlobalKeyService.homeKey.currentState?.isRefreshing ?? true) {
      return getLoadingWidget(Theme.of(context).primaryColor);
    }
    else if (_currentBible != null) {
      return PublicationMenuView(publication: _currentBible!);
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Pour télécharger une Bible, cliquez sur le bouton ci-dessous',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 30),
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
                    LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: null);
                    showDialog(
                      context: context,
                      builder: (context) => languageDialog,
                    ).then((publication) async {
                      if (publication != null && publication is Publication) {
                        if (!publication.isDownloadedNotifier.value) {
                          await publication.download(context);
                        }
                        setState(() {
                          _currentBible = publication;
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

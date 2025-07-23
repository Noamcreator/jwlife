import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/views/home_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';

import '../../publication/pages/menu/local/publication_menu_view.dart';

class BiblePage extends StatefulWidget {
  static late Function() refreshBibleView;
  const BiblePage({super.key});

  @override
  BiblePageState createState() => BiblePageState();
}

class BiblePageState extends State<BiblePage> {
  @override
  void initState() {
    BiblePage.refreshBibleView = () {setState(() {});};
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    print('Build BiblePage');

    List<Publication> bibles = PublicationRepository().getAllBibles();
    if (JwLifePage.getHomeGlobalKey().currentState?.isRefreshing ?? true) {
      return getLoadingWidget(Theme.of(context).primaryColor);
    }
    else if (bibles.isNotEmpty) {
      return PublicationMenuView(publication: bibles.first);
    }
    else {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(localization(context).navigation_bible),
        ),
        body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Pour télécharger une bible, cliquez sur le bouton ci-dessous'),
                const SizedBox(height: 10),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      textStyle: const TextStyle(fontSize: 17),
                    ),
                    onPressed: () async
                    {
                      LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: null);
                      showDialog(
                        context: context,
                        builder: (context) => languageDialog,
                      ).then((value) async {
                        if (value != null) {
                          Publication? publication = await PubCatalog.searchPub(value['KeySymbol'], value['IssueTagNumber'], value['MepsLanguageId']);
                          if(publication != null) {
                            if(!publication.isDownloadedNotifier.value) {
                              await publication.download(context);
                            }
                          }
                        }
                      });
                    },
                    child: Text('Bibles')),
              ],
            )
        ),
      );
    }
  }
}

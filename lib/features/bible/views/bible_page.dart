import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/views/home_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';

import '../../publication/views/menu/local/publication_menu_view.dart';

class BibleView extends StatefulWidget {
  static late Function() refreshBibleView;
  const BibleView({super.key});

  @override
  _BibleViewState createState() => _BibleViewState();
}

class _BibleViewState extends State<BibleView> {
  @override
  void initState() {

    BibleView.refreshBibleView = () {setState(() {});};

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Publication> bibles = PublicationRepository().getAllBibles();
    if (HomePage.isRefreshing) {
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

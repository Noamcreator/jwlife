import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:realm/realm.dart';

import '../../../../app/app_page.dart';
import '../../../../app/services/settings_service.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/audio.dart';
import '../../../../data/realm/realm_library.dart';
import '../../../../i18n/i18n.dart';
import '../../widgets/rectangle_mediaItem_item.dart';

class ConventionItemsView extends StatefulWidget {
  final int indexDay;
  final PublicationCategory category;
  final List<Publication> publications;
  final List<String> medias;

  const ConventionItemsView({super.key, required this.category, required this.indexDay, required this.publications, required this.medias});

  @override
  _ConventionItemsViewState createState() => _ConventionItemsViewState();
}

class _ConventionItemsViewState extends State<ConventionItemsView> {
  List<Publication> publications = [];
  List<String> medias = [];

  @override
  void initState() {
    super.initState();

    setState(() {
      publications = widget.publications;
      medias = widget.medias;
    });
  }

  void loadItems() async {
    List<Publication> pubs = await CatalogDb.instance.fetchPubsFromConventionsDays();
    RealmResults<RealmCategory> convDaysCategories = RealmLibrary.realm.all<RealmCategory>().query("LanguageSymbol == '${JwLifeSettings.instance.currentLanguage.value.symbol}'").query("Key == 'ConvDay1' OR Key == 'ConvDay2' OR Key == 'ConvDay3'");

    setState(() {
      publications = pubs.where((element) => element.conventionReleaseDayNumber == widget.indexDay).toList();
      medias = convDaysCategories.firstWhere((element) => element.key == 'ConvDay${widget.indexDay}').media;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    items.addAll(publications);
    items.addAll(medias);

    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().label_convention_day(widget.indexDay),
        subTitleWidget: ValueListenableBuilder(valueListenable: JwLifeSettings.instance.currentLanguage, builder: (context, value, child) {
          return Text(value.vernacular, style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle);
        }),
        actions: [
          IconTextButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: (BuildContext context) {

            },
          ),
          IconTextButton(
            icon: const Icon(JwIcons.language),
            onPressed: (BuildContext context) {
              showLanguageDialog(context).then((language) async {
                if (language != null) {
                  loadItems();
                  // TODO ajouter la langue pour le raffraichissement comme sur les Audio et les Vidéos
                }
              });
            },
          ),
        ],
      ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Wrap(
            spacing: 3.0,
            runSpacing: 3.0,
            children: items.map((item) {
              String naturalKey = item;
              String languageSymbol = JwLifeSettings.instance.currentLanguage.value.symbol;
              if(item is Publication) {
                return RectanglePublicationItem(publication: item);
              }
              else {
                RealmMediaItem media = RealmLibrary.getMediaItemByNaturalKey(naturalKey, languageSymbol);
                if(media.type == 'AUDIO') {
                  Audio audio = Audio.fromJson(mediaItem: media);
                  return RectangleMediaItemItem(media: audio);
                }
                else {
                  Video video = Video.fromJson(mediaItem: media);
                  return RectangleMediaItemItem(media: video);
                }
              }
            }).toList(),
          )
        )
    );
  }
}
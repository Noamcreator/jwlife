
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:realm/realm.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/audio.dart';
import '../../../../data/realm/realm_library.dart';
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
    List<Publication> pubs = await PubCatalog.fetchPubsFromConventionsDays();
    RealmResults<Category> convDaysCategories = RealmLibrary.realm.all<Category>().query("language == '${JwLifeSettings().currentLanguage.symbol}'").query("key == 'ConvDay1' OR key == 'ConvDay2' OR key == 'ConvDay3'");

    setState(() {
      publications = pubs.where((element) => element.conventionReleaseDayNumber == widget.indexDay).toList();
      medias = convDaysCategories.firstWhere((element) => element.key == 'ConvDay${widget.indexDay}').media;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Styles partagés
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    final boxDecoration = BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF292929)
          : Colors.white,
    );

    List<dynamic> items = [];
    items.addAll(publications);
    items.addAll(medias);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jour ${widget.indexDay}', style: textStyleTitle),
            Text(JwLifeSettings().currentLanguage.vernacular, style: textStyleSubtitle),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () {
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
              if(item is Publication) {
                return RectanglePublicationItem(publication: item);
              }
              else {
                MediaItem media = RealmLibrary.realm.all<MediaItem>().query("naturalKey == '$item'").first;
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
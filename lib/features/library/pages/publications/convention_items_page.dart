import 'package:flutter/material.dart';
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
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/audio.dart';
import '../../../../data/models/meps_language.dart';
import '../../../../data/realm/realm_library.dart';
import '../../../../i18n/i18n.dart';
import '../../widgets/rectangle_mediaItem_item.dart';

class ConventionItemsView extends StatefulWidget {
  final int indexDay;
  final PublicationCategory category;
  final MepsLanguage mepsLanguage;
  final List<Publication> publications;
  final List<String> medias;

  const ConventionItemsView({super.key, required this.category, required this.mepsLanguage, required this.indexDay, required this.publications, required this.medias});

  @override
  _ConventionItemsViewState createState() => _ConventionItemsViewState();
}

class _ConventionItemsViewState extends State<ConventionItemsView> {
  List<Publication> publications = [];
  List<String> medias = [];

  final _pageTitle = ValueNotifier<String>('');
  final _mepsLanguage = ValueNotifier<MepsLanguage>(JwLifeSettings.instance.currentLanguage.value);

  @override
  void initState() {
    super.initState();

    _mepsLanguage.value = widget.mepsLanguage;

    setState(() {
      publications = widget.publications;
      medias = widget.medias;
    });

    _loadTitle();
  }

  Future<void> _loadTitle() async {
    Locale locale = _mepsLanguage.value.getSafeLocale();
    _pageTitle.value = (await i18nLocale(locale)).label_convention_day(formatNumber(widget.indexDay, localeCode: locale.languageCode));
  }

  Future<void> loadItems({Map<String, dynamic>? mepsLanguage}) async {
    String mepsLanguageSymbol = mepsLanguage?['Symbol'] ?? JwLifeSettings.instance.currentLanguage.value.symbol;

    List<Publication> pubs = await CatalogDb.instance.fetchPubsFromConventionsDays(JwLifeSettings.instance.currentLanguage.value);
    RealmResults<RealmCategory> convDaysCategories = RealmLibrary.realm.all<RealmCategory>().query("LanguageSymbol == '$mepsLanguageSymbol'").query("Key == 'ConvDay1' OR Key == 'ConvDay2' OR Key == 'ConvDay3'");

    _mepsLanguage.value = mepsLanguage != null ? MepsLanguage.fromJson(mepsLanguage) : JwLifeSettings.instance.currentLanguage.value;

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

    return ValueListenableBuilder(
      valueListenable: _pageTitle,
      builder: (context, title, child) {
        return AppPage(
          appBar: JwLifeAppBar(
            title: title,
            subTitleWidget: ValueListenableBuilder(valueListenable: _mepsLanguage, builder: (context, value, child) {
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
                  showLanguageDialog(context, selectedLanguageSymbol: _mepsLanguage.value.symbol).then((language) async {
                    if (language != null) {
                      await loadItems(mepsLanguage: language);
                      _loadTitle();
                    }
                  });
                },
              ),
            ],
          ),
            body: Directionality(
              textDirection: _mepsLanguage.value.isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Wrap(
                  spacing: 3.0,
                  runSpacing: 3.0,
                  children: items.map((item) {
                    if(item is Publication) {
                      return RectanglePublicationItem(publication: item);
                    }
                    else {
                      String naturalKey = item;
                      RealmMediaItem media = RealmLibrary.getMediaItemByNaturalKey(naturalKey, _mepsLanguage.value.symbol);
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
              ),
            )
        );
      }
    );
  }
}
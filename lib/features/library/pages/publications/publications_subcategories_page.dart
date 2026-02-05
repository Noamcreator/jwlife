import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:realm/realm.dart';

import '../../../../app/app_page.dart';
import '../../../../app/services/settings_service.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/meps_language.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../data/realm/realm_library.dart';
import '../../../../i18n/i18n.dart';
import '../../../../i18n/localization.dart';
import '../../widgets/responsive_categories_wrap_layout.dart';
import 'convention_items_page.dart';
import 'publications_items_page.dart';

class PublicationSubcategoriesPage extends StatefulWidget {
  final PublicationCategory category;

  const PublicationSubcategoriesPage({super.key, required this.category});

  @override
  _PublicationSubcategoriesPageState createState() => _PublicationSubcategoriesPageState();
}

class _PublicationSubcategoriesPageState extends State<PublicationSubcategoriesPage> {
  List<Map<String, dynamic>> items = [];

  final _pageTitle = ValueNotifier<String>('');
  final _mepsLanguage = ValueNotifier<MepsLanguage>(JwLifeSettings.instance.libraryLanguage.value);

  @override
  void initState() {
    super.initState();
    _loadTitle();
    if(widget.category.type == 'Convention') {
      loadItemsDays();
    }
    else {
      loadItemsYears();
    }
  }

  Future<void> _loadTitle() async {
    _pageTitle.value = await widget.category.getNameAsync(_mepsLanguage.value.getSafeLocale());
  }

  Future<void> loadItemsDays({Map<String, dynamic>? mepsLanguage}) async {
    List<Map<String, dynamic>> days = [];

    String mepsLanguageSymbol = mepsLanguage?['Symbol'] ?? JwLifeSettings.instance.libraryLanguage.value.symbol;
    _mepsLanguage.value = mepsLanguage != null ? MepsLanguage.fromJson(mepsLanguage) : JwLifeSettings.instance.libraryLanguage.value;

    List<Publication> pubs = await CatalogDb.instance.fetchPubsFromConventionsDays(_mepsLanguage.value);
    RealmResults<RealmCategory> convDaysCategories = RealmLibrary.realm.all<RealmCategory>().query("LanguageSymbol == '$mepsLanguageSymbol'").query("Key == 'ConvDay1' OR Key == 'ConvDay2' OR Key == 'ConvDay3'");

    for(int i = 1; i < 3+1; i++) {
      if (pubs.any((element) => element.conventionReleaseDayNumber == i) || convDaysCategories.any((element) => element.key == 'ConvDay$i')) {
        days.add({
          "Day": i,
          "Publications": pubs.where((element) => element.conventionReleaseDayNumber == i).toList(),
          "Medias": convDaysCategories.firstWhereOrNull((element) => element.key == 'ConvDay$i')?.media ?? List<String>.empty(),
        });
      }
    }

    setState(() {
      items = days;
    });
  }

  Future<void> loadItemsYears({Map<String, dynamic>? mepsLanguage}) async {
    int mepsLanguageId = mepsLanguage?['LanguageId'] ?? JwLifeSettings.instance.libraryLanguage.value.id;
    _mepsLanguage.value = mepsLanguage != null ? MepsLanguage.fromJson(mepsLanguage) : JwLifeSettings.instance.libraryLanguage.value;

    final years = await CatalogDb.instance.getItemsYearInCategory(widget.category.id, mepsLanguageId: mepsLanguageId);

    setState(() {
      items = years;
    });
  }

  @override
  Widget build(BuildContext context) {

    // Transforme les catégories en widgets
    final List<Widget> subCategoriesWidgets = items.map((subCategory) {
      int number = subCategory['Year'] ?? subCategory['Day'];
      final ThemeData theme = Theme.of(context);
      final bool isDark = theme.brightness == Brightness.dark;

      final Color backgroundColor = isDark ? const Color(0xFF292929) : Colors.white;
      final Color textColor = isDark ? Colors.white : Colors.grey[800]!;

      return Material(
        color: backgroundColor,
        child: InkWell(
            onTap: () {
              if(widget.category.type == 'Convention') {
                showPage(ConventionItemsView(
                  category: widget.category,
                  mepsLanguage: _mepsLanguage.value,
                  indexDay: subCategory['Day'],
                  publications: subCategory['Publications'],
                  medias: subCategory['Medias'],
                ));
              }
              else {
                showPage(PublicationsItemsPage(
                  category: widget.category,
                    mepsLanguage: _mepsLanguage.value,
                  year: number
                ));
              }
            },
            child: _buildCategoryButton(context, number, textColor)
        ),
      );
    }).toList();

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
                icon: const Icon(JwIcons.language),
                onPressed: (BuildContext context) {
                  showLanguageDialog(context, firstSelectedLanguage: _mepsLanguage.value.symbol, type: widget.category.type == 'Convention' ? 'library' : 'publication').then((language) async {
                    if (language != null) {
                      if(widget.category.type == 'Convention') {
                        await loadItemsDays(mepsLanguage: language);
                      }
                      else {
                        await loadItemsYears(mepsLanguage: language);
                      }
                      _loadTitle();
                    }
                  });
                },
              ),
              IconTextButton(
                icon: const Icon(JwIcons.arrow_circular_left_clock),
                text: i18n().action_history,
                onPressed: (anchorContext) {
                  JwLifeApp.history.showHistoryDialog(context);
                }
              )
            ],
          ),
          body: ValueListenableBuilder(
            valueListenable: _mepsLanguage,
            builder: (context, value, child) {
              return ResponsiveCategoriesWrapLayout(
                textDirection: _mepsLanguage.value.isRtl ? TextDirection.rtl : TextDirection.ltr,
                children: subCategoriesWidgets,
              );
            }
          )
        );
      }
    );
  }

  Widget _buildCategoryButton(BuildContext context, int number, Color textColor) {
    Locale locale = _mepsLanguage.value.getSafeLocale();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Icon(widget.category.icon, size: 38.0, color: textColor),
          const SizedBox(width: 25.0),
          FutureBuilder<AppLocalizations>(
            future: i18nLocale(locale),
            builder: (context, snapshot) {
              // Valeur par défaut tant que la localisation n'est pas chargée
              String titleText = widget.category.type == 'Convention' ? i18n().label_convention_day(number) : formatYear(number, localeCode: locale);

              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                final loc = snapshot.data!;
                titleText = widget.category.type == 'Convention' ? loc.label_convention_day(formatNumber(number, localeCode: locale.languageCode)) : formatYear(number, localeCode: locale);
              }

              return Text(titleText, style: TextStyle(color: textColor));
            },
          )
        ],
      ),
    );
  }
}

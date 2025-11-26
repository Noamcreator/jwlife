import 'package:flutter/material.dart';
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
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../data/realm/realm_library.dart';
import '../../../../i18n/i18n.dart';
import '../../../../i18n/localization.dart';
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
    _pageTitle.value = await widget.category.getNameAsync(Locale(JwLifeSettings.instance.currentLanguage.value.primaryIetfCode));
  }

  void loadItemsDays() async {
    List<Map<String, dynamic>> days = [];

    List<Publication> pubs = await CatalogDb.instance.fetchPubsFromConventionsDays();
    RealmResults<Category> convDaysCategories = RealmLibrary.realm.all<Category>().query("language == '${JwLifeSettings.instance.currentLanguage.value.symbol}'").query("key == 'ConvDay1' OR key == 'ConvDay2' OR key == 'ConvDay3'");

    for(int i = 1; i < 3+1; i++) {
      if (pubs.any((element) => element.conventionReleaseDayNumber == i) || convDaysCategories.any((element) => element.key == 'ConvDay$i')) {
        days.add({
          "Day": i,
          "Publications": pubs.where((element) => element.conventionReleaseDayNumber == i).toList(),
          "Medias": convDaysCategories.firstWhere((element) => element.key == 'ConvDay$i').media
        });
      }
    }

    setState(() {
      items = days;
    });
  }

  Future<void> loadItemsYears({int? mepsLanguageId}) async {
    final years = await CatalogDb.instance.getItemsYearInCategory(widget.category.id, mepsLanguageId: mepsLanguageId);
    setState(() {
      items = years;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _pageTitle,
      builder: (context, title, child) {
        return AppPage(
          appBar: JwLifeAppBar(
            title: title,
            subTitleWidget: ValueListenableBuilder(valueListenable: JwLifeSettings.instance.currentLanguage, builder: (context, value, child) {
              return Text(value.vernacular, style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle);
            }),
            actions: [
              IconTextButton(
                icon: Icon(JwIcons.magnifying_glass),
                onPressed: (BuildContext context) {},
              ),
              IconTextButton(
                icon: const Icon(JwIcons.language),
                onPressed: (BuildContext context) {
                  showLanguageDialog(context).then((language) async {
                    if (language != null) {
                      loadItemsYears(mepsLanguageId: language['LanguageId']);
                    }
                  });
                },
              )
            ],
          ),
          body: Directionality(
            textDirection: JwLifeSettings.instance.currentLanguage.value.isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 7.0, horizontal: 8.0),
              itemCount: items.length,
              itemBuilder: (context, index) {
                int number = items[index]['Year'] ?? items[index]['Day'];

                // Déterminer la couleur de fond en fonction du thème
                Color backgroundColor = Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Colors.white;

                // Déterminer la couleur du texte en fonction du thème
                Color? textColor = Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.white;

                return Padding(
                  padding: const EdgeInsetsGeometry.only(bottom: 2.0),
                  child: Material(
                    color: backgroundColor,
                    child: InkWell(
                      onTap: () {
                        if(widget.category.type == 'Convention') {
                          showPage(ConventionItemsView(
                            category: widget.category,
                            indexDay: items[index]['Day'],
                            publications: items[index]['Publications'],
                            medias: items[index]['Medias'],
                          ));
                        }
                        else {
                          showPage(PublicationsItemsPage(
                            category: widget.category,
                            year: number,
                          ));
                        }
                      },
                      child: _buildCategoryButton(context, number, textColor!)
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    );
  }

  Widget _buildCategoryButton(BuildContext context, int number, Color textColor) {
    Locale locale = Locale(JwLifeSettings.instance.currentLanguage.value.primaryIetfCode);

    return ListTile(
      contentPadding: EdgeInsets.all(12.0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Icon(widget.category.icon, size: 38.0, color: textColor),
      ),
      title: Row(
        children: [
          SizedBox(width: 15.0),
          FutureBuilder<AppLocalizations>(
            future: i18nLocale(locale),
            builder: (context, snapshot) {
              // Valeur par défaut tant que la localisation n'est pas chargée
              String titleText = widget.category.type == 'Convention' ? i18n().label_convention_day(number) : formatYear(number, localeCode: locale);

              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                final loc = snapshot.data!;
                titleText = widget.category.type == 'Convention' ? loc.label_convention_day(formatNumber(number)) : formatYear(number, localeCode: locale);
              }

              return Text(titleText, style: TextStyle(color: textColor));
            },
          )
        ],
      ),
    );
  }
}

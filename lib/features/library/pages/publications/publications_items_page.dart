import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';

import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart';
import '../../../../app/app_page.dart';
import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/widgets_utils.dart';
import '../../../../i18n/i18n.dart';
import '../../models/publications/publication_items_model.dart';

class PublicationsItemsPage extends StatefulWidget {
  final PublicationCategory category;
  final MepsLanguage mepsLanguage;
  final int? year;

  const PublicationsItemsPage({super.key, required this.category, required this.mepsLanguage, this.year});

  @override
  _PublicationsItemsPageState createState() => _PublicationsItemsPageState();
}

class _PublicationsItemsPageState extends State<PublicationsItemsPage> {
  late final PublicationsItemsViewModel _model;
  final TextEditingController _searchController = TextEditingController();

  final _pageTitle = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _model = PublicationsItemsViewModel(
      category: widget.category,
      year: widget.year,
      mepsLanguage: widget.mepsLanguage
    );
    _loadTitle();
    _model.loadItems();
  }

  Future<void> _loadTitle() async {
    MepsLanguage mepsLanguage = _model.mepsLanguage ?? widget.mepsLanguage;

    // Si l'année est fournie, le titre est synchrone (pas besoin d'attendre)
    if (widget.year != null) {
      _pageTitle.value = formatYear(widget.year!, localeCode: mepsLanguage.getSafeLocale());
    }
    else {
      // Sinon, on appelle la méthode asynchrone et on met à jour l'état
      final title = await widget.category.getNameAsync(mepsLanguage.getSafeLocale());
      _pageTitle.value = title;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _model.dispose();
    super.dispose();
  }

  // Méthode d'aide pour le Widget
  Widget _buildCategoryHeader(BuildContext context, PublicationAttribute attribute) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20.0,
        bottom: 0.0,
      ),
      child: FutureBuilder(
        future: attribute.getNameAsync(_model.mepsLanguage!.getSafeLocale()),
        builder: (context, snapshot) {
          String attributeText = attribute.getName();
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            final loc = snapshot.data!;
            attributeText = loc;
          }

          return Text(
            attributeText,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, child) {
        final isSearching = _model.isSearching;

        return ValueListenableBuilder(
          valueListenable: _pageTitle,
          builder: (context, title, child) {
            return AppPage(
              appBar: isSearching
                  ? AppBar(
                title: SearchFieldWidget(
                  query: '',
                  onSearchTextChanged: (text) {
                    _model.filterPublications(text);
                  },
                  onSuggestionTap: (item) {},
                  onSubmit: (item) {
                    setState(() {
                      _model.setIsSearching(false);
                      _searchController.clear();
                    });
                  },
                  onTapOutside: (event) {
                    setState(() {
                      _model.setIsSearching(false);
                      _searchController.clear();
                    });
                  },
                  suggestionsNotifier: ValueNotifier([]),
                ),
                leading: IconButton(
                  icon: const Icon(JwIcons.chevron_left),
                  onPressed: () {
                    _model.setIsSearching(false);
                    _searchController.clear();
                    _model.filterPublications('');
                  },
                ),
              ) : JwLifeAppBar(
                title: title,
                subTitle: _model.mepsLanguage?.vernacular ?? widget.mepsLanguage.vernacular,
                actions: [
                  IconTextButton(
                    icon: const Icon(JwIcons.magnifying_glass),
                    text: i18n().search_bar_search,
                    onPressed: (anchorContext) {
                      _model.setIsSearching(true);
                      _model.filterPublications(_searchController.text);
                    },
                  ),
                  IconTextButton(
                    icon: const Icon(JwIcons.language),
                    text: i18n().action_languages,
                    onPressed: (anchorContext) async {
                      showLanguageDialog(context, selectedLanguageSymbol: _model.currentMepsLanguage?.symbol ?? widget.mepsLanguage.symbol).then((language) async {
                        if (language != null) {
                          await _model.loadItems(mepsLanguageMap: language);
                          _loadTitle();
                        }
                      });
                    },
                  ),
                  IconTextButton(
                      icon: const Icon(JwIcons.arrows_up_down),
                      text: i18n().action_sort_by,
                      onPressed: (anchorContext) {
                        // 1. Définir les options du menu (les `PopupMenuItem`s)
                        final List<PopupMenuEntry> menuItems = [
                          // --- Tri par Titre ---
                          // Option 1.1 : Tri par Titre (A-Z)
                          PopupMenuItem(
                            value: 'title_asc', // champ: title, ordre: ascendant
                            child: Text(i18n().label_sort_title_asc),
                          ),
                          // Option 1.2 : Tri par Titre (Z-A)
                          PopupMenuItem(
                            value: 'title_desc', // champ: title, ordre: descendant
                            child: Text(i18n().label_sort_title_desc),
                          ),

                          // Ajouter un séparateur visuel si vous le souhaitez (non obligatoire)
                          const PopupMenuDivider(),

                          // --- Tri par Année ---
                          // Option 2.1 : Tri par Année (Le plus récent d'abord)
                          PopupMenuItem(
                            value: 'year_desc', // champ: year, ordre: descendant (car année > -> plus récent)
                            child: Text(i18n().label_sort_year_desc),
                          ),
                          // Option 2.2 : Tri par Année (Le plus ancien d'abord)
                          PopupMenuItem(
                            value: 'year_asc', // champ: year, ordre: ascendant
                            child: Text(i18n().label_sort_year_asc),
                          ),

                          // Ajouter un séparateur visuel si vous le souhaitez
                          const PopupMenuDivider(),

                          // --- Tri par Symbole (Exemple) ---
                          // Option 3.1 : Tri par Symbole (A-Z)
                          PopupMenuItem(
                            value: 'symbol_asc',
                            child: Text(i18n().label_sort_symbol_asc),
                          ),
                          // Option 3.2 : Tri par Symbole (Z-A)
                          PopupMenuItem(
                            value: 'symbol_desc',
                            child: Text(i18n().label_sort_symbol_desc),
                          ),
                        ];

                        // 2. Afficher le menu avec les options
                        showMenu(
                          context: context,
                          elevation: 8.0,
                          items: menuItems,
                          initialValue: null,
                          position: RelativeRect.fromDirectional(
                            textDirection: Directionality.of(context),
                            start: MediaQuery.of(context).size.width - 210,
                            top: 40,
                            end: 10,
                            bottom: 0,
                          ),
                        ).then((value) {
                          if (value != null) {
                            _model.sortPublications(value);
                          }
                        });
                      }
                  ),
                  IconTextButton(
                      icon: const Icon(JwIcons.arrow_circular_left_clock),
                      text: i18n().action_history,
                      onPressed: (anchorContext) {
                        History.showHistoryDialog(context);
                      }
                  )
                ]
              ),

              // Le corps utilise un widget dédié pour le défilement
              body: _PublicationsItemsBody(
                viewModel: _model,
                mepsLanguage: widget.mepsLanguage,
                buildCategoryHeader: _buildCategoryHeader,
              ),
            );
          }
        );
      },
    );
  }
}

// --- NOUVEAU WIDGET POUR LE CORPS (OPTIMISATION DU REBUILD) ---

class _PublicationsItemsBody extends StatelessWidget {
  final PublicationsItemsViewModel viewModel;
  final MepsLanguage? mepsLanguage;
  final Widget Function(BuildContext, PublicationAttribute) buildCategoryHeader;

  const _PublicationsItemsBody({
    required this.viewModel,
    required this.mepsLanguage,
    required this.buildCategoryHeader,
  });

  @override
  Widget build(BuildContext context) {
    // On détermine la direction du texte
    final isRtl = viewModel.mepsLanguage?.isRtl ?? mepsLanguage?.isRtl ?? JwLifeSettings.instance.currentLanguage.value.isRtl;

    // Récupérer tous les notifiers pour écouter les changements de téléchargement globalement
    final List<ValueListenable<bool>> downloadNotifiers = [];
    viewModel.filteredPublications.values.forEach((list) {
      for (var pub in list) {
        downloadNotifiers.add(pub.isDownloadedNotifier);
      }
    });

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListenableBuilder(
        // On écoute à la fois le viewModel ET tous les changements de téléchargement
        listenable: Listenable.merge([viewModel, ...downloadNotifiers]),
        builder: (context, child) {
          if (viewModel.isLoading) {
            return getLoadingWidget(Theme.of(context).primaryColor);
          }

          // 1. PRÉ-FILTRAGE des listes pour supprimer les éléments non téléchargés/catalogués
          final Map<PublicationAttribute, List<Publication>> displayMap = {};

          viewModel.filteredPublications.forEach((attribute, list) {
            final visibleList = list.where((pub) =>
            pub.isDownloadedNotifier.value || pub.catalogedOn.isNotEmpty
            ).toList();

            if (visibleList.isNotEmpty) {
              displayMap[attribute] = visibleList;
            }
          });

          // 2. Vérification si vide après filtrage
          if (displayMap.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  i18n().message_no_items_publications,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Theme.of(context).hintColor),
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final double screenWidth = constraints.maxWidth;
              final double contentPadding = getContentPadding(screenWidth);

              // Calcul de la grille
              final int crossAxisCount = (screenWidth / (kMaxItemWidth + kSpacing)).floor();
              final int finalCrossAxisCount = crossAxisCount > 0 ? crossAxisCount : 1;
              final double totalSpacing = kSpacing * (finalCrossAxisCount - 1);
              final double itemWidth = (screenWidth - (contentPadding * 2) - totalSpacing) / finalCrossAxisCount;
              final double childAspectRatio = itemWidth / kItemHeight;

              final List<Widget> slivers = [];

              displayMap.forEach((attribute, publicationList) {
                // Ajout de l'en-tête
                if (attribute.id != 0) {
                  slivers.add(
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: contentPadding),
                        child: buildCategoryHeader(context, attribute),
                      ),
                    ),
                  );
                }

                // Ajout de la grille (sans SizedBox.shrink, tout est rempli)
                slivers.add(
                  SliverPadding(
                    padding: EdgeInsets.all(contentPadding),
                    sliver: SliverGrid.builder(
                      itemCount: publicationList.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: finalCrossAxisCount,
                        mainAxisSpacing: kSpacing,
                        crossAxisSpacing: kSpacing,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        return RectanglePublicationItem(
                          publication: publicationList[index],
                        );
                      },
                    ),
                  ),
                );
              });

              return CustomScrollView(slivers: slivers);
            },
          );
        },
      ),
    );
  }
}
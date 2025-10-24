import 'package:flutter/material.dart';

import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/core/app_dimens.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/data/models/publication_attribute.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart'; // Rendu commenté
import '../../models/publications/publication_items_model.dart'; // Assurez-vous que l'importation est correcte

class PublicationsItemsView extends StatefulWidget {
  final PublicationCategory category;
  final int? year;

  const PublicationsItemsView({super.key, required this.category, this.year});

  @override
  _PublicationsItemsViewState createState() => _PublicationsItemsViewState();
}

class _PublicationsItemsViewState extends State<PublicationsItemsView> {
  late final PublicationsItemsViewModel _model;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = PublicationsItemsViewModel(
      category: widget.category,
      year: widget.year,
    );
    _model.loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _model.dispose();
    super.dispose();
  }

  // Méthode d'aide pour le Widget
  Widget _buildCategoryHeader(BuildContext context, PublicationAttribute attribute, bool isFirst) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0.0 : 40.0,
        bottom: 5.0,
      ),
      child: Text(
        attribute.name,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Styles définis une seule fois
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    // ListenableBuilder n'englobe plus que l'AppBar et le Body
    return ListenableBuilder(
      listenable: _model,
      builder: (context, child) {
        final isSearching = _model.isSearching;

        return Scaffold(
          resizeToAvoidBottomInset: false,
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
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _model.setIsSearching(false);
                _searchController.clear();
                _model.filterPublications('');
              },
            ),
          ) : AppBar(
            // App bar normale
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.year != null ? '${widget.year}' : widget.category.getName(context), style: textStyleTitle),
                Text(_model.language, style: textStyleSubtitle),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(JwIcons.magnifying_glass),
                onPressed: () {
                  _model.setIsSearching(true);
                  _model.filterPublications(_searchController.text);
                },
              ),
              IconButton(
                icon: const Icon(JwIcons.language),
                onPressed: () async {
                  showLanguageDialog(context, selectedLanguageSymbol: _model.languageSymbol).then((language) async {
                    if (language != null) {
                      _model.loadItems(mepsLanguage: language);
                    }
                  });
                },
              ),
            ],
          ),

          // Le corps utilise un widget dédié pour le défilement
          body: _PublicationsItemsBody(
            viewModel: _model,
            buildCategoryHeader: _buildCategoryHeader,
          ),
        );
      },
    );
  }
}

// --- NOUVEAU WIDGET POUR LE CORPS (OPTIMISATION DU REBUILD) ---

class _PublicationsItemsBody extends StatelessWidget {
  final PublicationsItemsViewModel viewModel;
  final Widget Function(BuildContext, PublicationAttribute, bool) buildCategoryHeader;

  const _PublicationsItemsBody({
    required this.viewModel,
    required this.buildCategoryHeader,
  });

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder englobe uniquement la partie du corps qui dépend des publications
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        final filteredPublications = viewModel.filteredPublications;

        // 1. VÉRIFICATION DE L'ÉTAT DE CHARGEMENT
        if (viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(), // Affiche un indicateur de chargement
          );
        }

        // 2. VÉRIFICATION DE L'ABSENCE DE PUBLICATIONS (après le chargement)
        bool hasPublications = filteredPublications.values.any((list) => list.isNotEmpty);

        if (!hasPublications) {
          // Affiche le message s'il n'y a aucune publication du tout
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Il n\'y a pas de publications disponibles dans cette catégorie pour le moment dans cette langue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          );
        }

        // 3. AFFICHAGE DES PUBLICATIONS (si chargées et disponibles)
        return LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double contentPadding = getContentPadding(screenWidth);

            // Calcul de la grille (stable)
            final int crossAxisCount = (screenWidth / (kMaxItemWidth + kSpacing)).floor();
            final int finalCrossAxisCount = crossAxisCount > 0 ? crossAxisCount : 1;
            final double totalSpacing = kSpacing * (finalCrossAxisCount - 1);
            final double itemWidth = (screenWidth - (contentPadding * 2) - totalSpacing) / finalCrossAxisCount;
            // Hauteur fixe (85.0 + 3.0) pour l'élément RectangularPublicationItem
            final double childAspectRatio = itemWidth / kItemHeight;

            final List<Widget> slivers = [];
            bool isFirstGroup = true;

            // Parcourir les groupes d'attributs filtrés
            filteredPublications.forEach((attribute, publicationList) {
              if (publicationList.isEmpty) return; // Cette ligne est toujours utile pour les groupes vides

              // 1. Ajout de l'en-tête (SliverToBoxAdapter)
              if (attribute.id != 0) {
                slivers.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: contentPadding),
                      child: buildCategoryHeader(context, attribute, isFirstGroup),
                    ),
                  ),
                );
                isFirstGroup = false;
              }

              // 2. Ajout de la grille de publications (SliverGrid)
              slivers.add(
                SliverPadding(
                  padding: EdgeInsets.all(contentPadding),
                  sliver: SliverGrid.builder(
                    itemCount: publicationList.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: finalCrossAxisCount,
                      mainAxisSpacing: kSpacing,
                      crossAxisSpacing: kSpacing,
                      childAspectRatio: childAspectRatio, // Ratio optimisé
                    ),
                    // ItemBuilder optimisé
                    itemBuilder: (context, index) {
                      Publication publication = publicationList[index];
                      // ValueListenableBuilder est le plus petit possible, ne reconstruisant
                      // que l'élément affecté par le changement d'état de téléchargement.
                      return ValueListenableBuilder<bool>(
                          valueListenable: publication.isDownloadedNotifier,
                          builder: (context, isDownloaded, _) {
                            // La logique reste ici car elle est dynamique et propre à l'élément de liste.
                            if (isDownloaded || publication.catalogedOn.isNotEmpty) {
                              return RectanglePublicationItem(publication: publication);
                            }
                            else {
                              // Utiliser SizedBox.shrink() est la bonne pratique pour les éléments non visibles.
                              return const SizedBox.shrink();
                            }
                          }
                      );
                    },
                  ),
                ),
              );
            });

            // 3. Le CustomScrollView
            return CustomScrollView(
              slivers: slivers,
            );
          },
        );
      },
    );
  }
}
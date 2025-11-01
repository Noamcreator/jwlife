import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/html_styles.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/bookmark.dart';
import 'package:jwlife/features/publication/models/menu/local/bible_color_group.dart';
import 'package:jwlife/features/publication/pages/menu/local/publication_search_view.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:jwlife/widgets/searchfield/searchfield_widget.dart';

import '../../../../../app/services/global_key_service.dart';
import '../../../../../app/services/settings_service.dart';
import '../../../../../core/app_dimens.dart';
import '../../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../../core/utils/utils_language_dialog.dart';
import '../../../../../core/utils/utils_pub.dart';
import '../../../../bible/pages/bible_chapter_page.dart';
import '../../../../image/image_page.dart';
import '../../../models/menu/local/menu_list_item.dart';
import '../../../models/menu/local/publication_menu_model.dart';
import '../../../models/menu/local/tab_items.dart';
import '../../../models/menu/local/words_suggestions_model.dart';

const double breakpointMedium = 530.0;
const double breakpointLarge = 800.0;
const double breakpointBig = 900.0;

class PublicationMenuView extends StatefulWidget {
  final Publication publication;
  final bool showAppBar;
  final bool biblePage;

  const PublicationMenuView({super.key, required this.publication, this.showAppBar = true, this.biblePage = false});

  @override
  PublicationMenuViewState createState() => PublicationMenuViewState();
}

class PublicationMenuViewState extends State<PublicationMenuView> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late PublicationMenuModel _model;
  bool _isLoading = true;
  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;

  @override
  bool get wantKeepAlive => true; // Maintient l'état de toute la vue

  @override
  void initState() {
    super.initState();
    _model = PublicationMenuModel(widget.publication);
    // Initialise le modèle de suggestion ici ou assurez-vous qu'il est non null
    widget.publication.wordsSuggestionsModel ??= WordsSuggestionsModel(widget.publication);
    init();
  }

  Future<void> init() async {
    await _model.init();

    if (_model.tabsWithItems.isNotEmpty && _model.tabsWithItems.length > 1) {
      _tabController = TabController(
        length: _model.tabsWithItems.length,
        vsync: this,
      );
      // Correction: si on est dans le cas multi-tabs, on se place sur l'index initial
      if (_model.initialTabIndex > 0 && _model.initialTabIndex < _model.tabsWithItems.length) {
        _tabController!.index = _model.initialTabIndex;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    _model.initAudio();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> goToTheBooksTab() async {
    if(_tabController != null) {
      // Assure que l'index 1 existe avant d'animer
      if (_model.tabsWithItems.length > 1) {
        _tabController!.animateTo(1);
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // -----------------------------------------------------------------------------
  // Fonctions de construction des items
  // -----------------------------------------------------------------------------

  Widget _buildNameItem(BuildContext context, bool showImage, ListItem item) {
    String subtitle = item.subTitle.replaceAll('​', '');
    bool showSubTitle = item.subTitle.isNotEmpty && subtitle != item.title;
    // Utilise firstWhereOrNull pour gérer le cas où audios est introuvable
    Audio? audio = widget.publication.audios.firstWhereOrNull((audio) => audio.documentId == item.mepsDocumentId);

    // ✅ CORRECTION 1: Sécurisation du chemin de l'image de l'article (widget.publications.path!)
    final bool hasValidImagePath = showImage &&
        item.imageFilePath.isNotEmpty &&
        widget.publication.path != null && // Vérifie d'abord que path n'est pas null
        widget.publication.path!.isNotEmpty;

    final String imageFullPath = hasValidImagePath ? '${widget.publication.path}/${item.imageFilePath}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () { showPageDocument(widget.publication, item.mepsDocumentId); },
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                showImage ? SizedBox( /* ... Image ... */
                  width: 60.0, height: 60.0,
                  // CORRECTION: Utilisation du chemin sécurisé
                  child: hasValidImagePath
                      ? ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: Image.file(
                          File(imageFullPath),
                          fit: BoxFit.cover
                      )
                  )
                      : Container(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e)),
                ) : Container(),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: showImage ? 8.0 : 0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if(showSubTitle) Text(item.subTitle, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFc0c0c0) : const Color(0xFF626262), fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2.0),
                        Text(item.title, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9fb9e3) : const Color(0xFF4a6da7), fontSize: showSubTitle ? 15.0 : 16.0, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8e8e8e) : const Color(0xFF757575)),
                  itemBuilder: (context) {
                    List<PopupMenuEntry> items = [
                      PopupMenuItem(child: Row(children: [Icon(JwIcons.share, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text('Envoyer le lien', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))]), onTap: () { widget.publication.documentsManager?.getDocumentFromMepsDocumentId(item.mepsDocumentId).share(false); }),
                    ];
                    if (audio != null && audio.fileSize != null) { // Ajout de la vérification audio.fileSize != null
                      items.add(PopupMenuItem(child: Row(children: [Icon(JwIcons.cloud_arrow_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), ValueListenableBuilder<bool>(valueListenable: audio.isDownloadingNotifier, builder: (context, isDownloading, child) { return Text(isDownloading ? "Téléchargement en cours..." : audio.isDownloadedNotifier.value ? "Supprimer l'audio (${formatFileSize(audio.fileSize!)})" : "Télécharger l'audio (${formatFileSize(audio.fileSize!)})", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)); }),]), onTap: () { if (audio.isDownloadedNotifier.value) { audio.remove(context); } else { audio.download(context); } }),
                      );
                      items.add(PopupMenuItem(child: Row(children: [Icon(JwIcons.headphones__simple, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text("Écouter l'audios", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))]), onTap: () { int index = widget.publication.audios.indexWhere((audio) => audio.documentId == item.mepsDocumentId); if (index != -1) { showAudioPlayerPublicationLink(context, widget.publication, index); } }),
                      );
                    }
                    return items;
                  },
                ),
              ],
            ),
            if (audio != null)
              ValueListenableBuilder<bool>(
                valueListenable: audio.isDownloadingNotifier,
                builder: (context, isDownloading, child) {
                  if (isDownloading) {
                    return Positioned(
                      bottom: 0,
                      left: showImage ? 65 : 0,
                      right: 20,
                      child: ValueListenableBuilder<double>(
                        valueListenable: audio.progressNotifier,
                        builder: (context, progress, child) {
                          return LinearProgressIndicator(
                            value: progress, minHeight: 2.0, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberList(BuildContext context, List<ListItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 60).floor();
        return GridView.builder(
          shrinkWrap: true, padding: const EdgeInsets.all(8.0), physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 2.0, mainAxisSpacing: 2.0, childAspectRatio: 1.0),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () { showPageDocument(widget.publication, items[index].mepsDocumentId); },
              child: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFF757575)),
                child: Text(
                  items[index].dataType == 'number' ? items[index].displayTitle ?? '' : items[index].title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ Fonction pour déterminer le titre à afficher selon la largeur d'écran
  String _getBookDisplayTitle(ListItem item, double screenWidth) {
    if (screenWidth >= breakpointLarge && item.largeTitle.isNotEmpty) {
      return item.largeTitle;
    }
    else if (screenWidth >= breakpointMedium && item.mediumTitle.isNotEmpty) {
      return item.mediumTitle;
    }
    return item.title.isNotEmpty ? item.title : item.displayTitle;
  }

  // ✅ Fonction pour construire une tuile de livre
  Widget _buildBookItem(BuildContext context, ListItem item, double screenWidth) {
    final int bibleBookId = item.bibleBookId ?? 0;
    final int groupId = item.groupId ?? 0;
    final bool hasCommentary = item.hasCommentary ?? false;

    // Votre logique hasAudio originale est conservée
    // Note: _model et widget ne sont pas définis dans cet extrait, mais conservés pour la complétude
    final bool hasAudio = _model.publication.audios.any((audio) => audio.track == bibleBookId);

    final String displayTitle = _getBookDisplayTitle(item, screenWidth);

    // Mode Petit écran : Carré 50x50, pas de logos (Largeur < 530.0)
    // La taille exacte 50x50 est assurée par le GridView.
    if (screenWidth < breakpointMedium) {
      return GestureDetector(
        onTap: () {
          // Note: showPage et LocalChapterBiblePage ne sont pas définis, mais conservés pour la complétude
          showPage(BibleChapterPage(bible: widget.publication, book: bibleBookId));
        },
        child: Container(
          decoration: BoxDecoration(
            // Note: BibleColorGroup n'est pas défini, mais conservé pour la complétude
            color: BibleColorGroup.getGroupColorAt(groupId),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Text(
                displayTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16
                ),
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }

    // Mode Moyen et Grand écran : Rectangle avec logos (Largeur >= 530.0)
    final double iconSize = screenWidth >= breakpointLarge ? 15 : 13;

    // Calcul de l'espace total pris par les icônes sur la droite
    final double iconAudioSpace = hasAudio ? iconSize + 4.0 : 0.0;
    final double iconCommentarySpace = hasCommentary ? iconSize + 4.0 : 0.0;

    // Marge droite pour le titre: 8.0 (padding gauche du conteneur) + espace des icônes
    final double titleRightPadding = 8.0 + iconAudioSpace + iconCommentarySpace;

    // Positionnement de l'icône de commentaire (décalé si l'audios est présent)
    final double commentaryRightPosition = hasAudio ? 4.0 + iconSize + 4.0 : 4.0;

    return GestureDetector(
      onTap: () {
        showPage(BibleChapterPage(bible: widget.publication, book: bibleBookId));
      },
      child: Container(
        decoration: BoxDecoration(
          color: BibleColorGroup.getGroupColorAt(groupId),
        ),
        child: Stack(
          children: [
            // Titre aligné à gauche et centré verticalement
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                // Padding ajusté pour garantir l'espace pour les icônes à droite
                padding: EdgeInsets.only(left: 8.0, right: titleRightPadding),
                child: Text(
                  displayTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Indicateur d'Audio (le plus à droite)
            if (hasAudio)
              Positioned(
                right: 4.0, // Toujours le plus à droite
                top: 4,
                child: Center(
                  child: Icon(
                    // Note: JwIcons.headphones__simple n'est pas défini, mais conservé pour la complétude
                    JwIcons.headphones__simple,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),

            // Indicateur de Commentaire (positionné à droite, à côté de l'Audio si présent)
            if (hasCommentary)
              Positioned(
                right: commentaryRightPosition, // Position ajustée
                top: 4,
                child: Center(
                  child: Icon(
                    // Note: JwIcons.gem__simple n'est pas défini, mais conservé pour la complétude
                    JwIcons.gem__simple,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ Fonction pour construire l'onglet des livres
  List<Widget> _buildBooksTab(BuildContext context, TabWithItems tabWithItems) {
    final List<ListItem> topLevelItems = tabWithItems.items;

    return [
      LayoutBuilder(
        builder: (context, constraints) {
          // Détermination de la largeur disponible
          double screenWidth = constraints.maxWidth;

          print(screenWidth);

          final double maxListWidth = screenWidth / 2 / 4 - 3 * kSpacing;

          // Détermination des métriques du GridView selon la taille d'écran
          int crossAxisCount;
          double mainAxisExtent;

          // *** LOGIQUE CARRÉE FIXE (Largeur < 530.0) : 6 colonnes de 60x60 ***
          if (screenWidth < breakpointMedium) {

            crossAxisCount = 6; // Nombre de colonnes FIXE
            mainAxisExtent = 60.0; // Hauteur FIXE à 60.0 (pour un carré 60x60)

          }
          else if (screenWidth < breakpointLarge) {
            // Moyen écran (530px <= Largeur < 800px) : Rectangle
            const double maxWidth = 100.0;
            crossAxisCount = (screenWidth / maxWidth).floor();
            mainAxisExtent = 45.0;
          }
          else {
            // Grand écran (>= 800px) : Rectangle
            const double maxWidth = 150.0;

            // Calcul basé sur 120px max par livre
            crossAxisCount = (screenWidth / maxWidth).floor();
            mainAxisExtent = 45.0;

            // Logique originale : forcer un minimum de 2 colonnes
            crossAxisCount = crossAxisCount < 2 ? 2 : crossAxisCount;
          }

          // S'assurer d'avoir au moins 1 colonne
          crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;

          final List<Widget> listContents = topLevelItems.map((item) {
            final isTitleItem = item.isTitle;
            Widget contentWidget;

            if (isTitleItem) {
              // Cas : TITRE DE SECTION
              contentWidget = Padding(
                padding: const EdgeInsets.only(top: 16.0, left: 8.0, right: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Affichage des Livres de la Bible via GridView
                    if (item.isBibleBooks)
                      if (screenWidth < breakpointMedium)
                      // *** LOGIQUE CARRÉE (Largeur < 530.0) avec largeur fixe 60x60 ***
                        SizedBox(
                          // Largeur totale nécessaire pour 6 colonnes (60px) et 5 espacements (2px)
                          width: (crossAxisCount * mainAxisExtent) + ((crossAxisCount - 1) * kSpacing),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount, // 6
                              crossAxisSpacing: kSpacing,
                              mainAxisSpacing: kSpacing,
                              mainAxisExtent: mainAxisExtent, // 60.0
                            ),
                            itemCount: item.subItems.length,
                            itemBuilder: (context, index) {
                              return _buildBookItem(context, item.subItems[index], screenWidth);
                            },
                          ),
                        )
                      else if (screenWidth < breakpointBig)
                      // Comportement standard pour les écrans Moyen/Grand (< 900px)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount, // Basé sur la largeur pour 530px <= screenWidth < 900px
                            crossAxisSpacing: kSpacing,
                            mainAxisSpacing: kSpacing,
                            mainAxisExtent: mainAxisExtent, // 45.0
                          ),
                          itemCount: item.subItems.length,
                          itemBuilder: (context, index) {
                            return _buildBookItem(context, item.subItems[index], screenWidth);
                          },
                        )
                      else
                      // *** LOGIQUE POUR screenWidth >= 900.0 (Sans SizedBox) ***
                      // Utilise la largeur complète de la colonne Expanded
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: tabWithItems.items.indexOf(item) == 0 ? ((maxListWidth * 4) + kSpacing * 3) : ((maxListWidth * 3) + kSpacing * 2)
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              // Le crossAxisCount est maintenant conditionnel à l'index de l'item (comme vous l'avez spécifié)
                              crossAxisCount: tabWithItems.items.indexOf(item) == 0 ? 4 : 3,
                              crossAxisSpacing: kSpacing,
                              mainAxisSpacing: kSpacing,
                              mainAxisExtent: mainAxisExtent, // 45.0
                            ),
                            itemCount: item.subItems.length,
                            itemBuilder: (context, index) {
                              return _buildBookItem(context, item.subItems[index], screenWidth);
                            },
                          )
                        )
                  ],
                ),
              );
            }
            else {
              contentWidget = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildNameItem(context, item.imageFilePath.isNotEmpty, item),
              );
            }

            return contentWidget;
          }).toList();

          // Affichage final : 2 colonnes seulement si >= 900px
          if (screenWidth >= breakpointBig) {
            final int halfLength = (listContents.length / 2).ceil();
            final List<Widget> firstHalf = listContents.sublist(0, halfLength);
            final List<Widget> secondHalf = listContents.sublist(halfLength);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: firstHalf,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: secondHalf,
                  ),
                ),
              ],
            );
          }
          else {
            // Toujours en une seule colonne pour < 900px
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listContents,
            );
          }
        },
      ),
    ];
  }

  // Fonction _buildTabContent mise à jour :
  List<Widget> _buildTabContent(BuildContext context, TabWithItems tabWithItems) {
    // Cas 1: Type 'number' (liste simple à l'intérieur)
    if (tabWithItems.tab['DataType'] == 'number') {
      return [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxMenuItemWidth),
            child: _buildNumberList(context, tabWithItems.items),
          ),
        )
      ];
    }

    // Cas 2: Listes classiques (Bible Books sous un Titre, ou Listes d'articles)
    bool hasImageFilePath = tabWithItems.items.any((item) => item.imageFilePath != '');

    final List<Widget> tabContentWidgets = tabWithItems.items.map((item) {
      final isTitleItem = item.isTitle;
      final isFirstItem = tabWithItems.items.indexOf(item) == 0;

      Widget contentWidget;

      if (isTitleItem) {
        // Contenu du titre (Titre + Divider + Sous-éléments)
        contentWidget = Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxMenuItemWidth), // Ajout de 'const'
              child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, left: 10.0, right: 10.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Garder .start pour aligner la colonne à gauche
                      children: [
                        Text(
                            item.title,
                            style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold
                            )
                        ), // <-- PARENTHÈSE FERMANTE AJOUTÉE ICI
                        const SizedBox(height: 2),
                        // 2. Centrer la Divider (pour qu'elle ait la même largeur contrainte)
                        const Divider(color: Color(0xFFa7a7a7), height: 1),
                        const SizedBox(height: 10),
                        // 3. Les subItems
                        ...item.subItems.map((subItem) => _buildNameItem(context, item.subItems.any((subItem) => subItem.imageFilePath.isNotEmpty), subItem)),
                      ]
                  )
              )
          )
        );
      }
      else {
        // Contenu d'un item simple (Article)
        contentWidget = Padding(
          padding: EdgeInsets.only(top: isFirstItem ? 10.0 : 0.0, left: 10.0, right: 10.0),
          child: _buildNameItem(context, hasImageFilePath, item),
        );
      }

      // LOGIQUE DE CONTRAINTE DE LARGEUR :
      if (!isTitleItem) {
        return Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxMenuItemWidth),
              child: contentWidget
          ),
        );
      }

      // Pour les autres cas (titres non-article, et Bible Books), le widget reste pleine largeur
      return contentWidget;
    }).toList();

    return tabContentWidgets;
  }

  // -----------------------------------------------------------------------------
  // Widget principal de la publications
  // -----------------------------------------------------------------------------

  Widget _buildPublication() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_model.tabsWithItems.isEmpty) {
      return const Center(child: Text("Aucun contenu disponible ou la publications a un problème."));
    }

    // VRAI: Catégorie Bible (ID 1), VRAI: si la publications est ouverte comme page Bible
    bool isBible = widget.publication.isBible() || widget.biblePage;

    // La largeur maximale est appliquée conditionnellement
    final double? maxContentWidth = isBible ? null : kMaxMenuItemWidth;

    Widget content;

    // 1. Cas : Une seule tab -> PAS de TabController, utilise ListView simple.
    if (_model.tabsWithItems.length == 1) {
      final tabWithItems = _model.tabsWithItems.first;
      final List<Widget> items = [];

      // En-tête (Image + Titre + Description)
      if (!isBible) {
        final imageLsrValue = widget.publication.imageLsr;

        // Correction de la vérification de nullité sur widget.publications.path
        if (imageLsrValue is String && imageLsrValue.isNotEmpty && widget.publication.path?.isNotEmpty == true) {
          final String imagePath = '${widget.publication.path}/${imageLsrValue.split('/').last}';

          items.add(
              GestureDetector(
                  onTap: () { showPage(ImagePage(filePath: imagePath)); },
                  child: Image.file(
                      File(imagePath),
                      fit: BoxFit.fill,
                      width: double.infinity
                  )
              )
          );
        }
        items.add(const SizedBox(height: 15));
        items.add(Text(widget.publication.coverTitle.isNotEmpty ? widget.publication.coverTitle : widget.publication.title, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 25, fontWeight: FontWeight.bold, height: 1.2), textAlign: TextAlign.center));
        items.add(widget.publication.description.isEmpty ? const SizedBox(height: 15) : Padding(padding: const EdgeInsets.all(8.0), child: TextHtmlWidget(text: widget.publication.description, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 15, height: 1.2), textAlign: TextAlign.center, isSearch: false)));
      }

      // Contenu de la tab unique
      items.addAll(_buildTabContent(context, tabWithItems));
      items.add(const SizedBox(height: 20));

      // Utilisation d'un ListView.builder simple
      content = ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      );
    }
    // 2. Cas : Plusieurs tabs -> Utilise NestedScrollView avec TabBar et TabBarView.
    else {
      content = NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final List<Widget> slivers = [];

          // Contenu de l'en-tête (Image, Titre, Description) - PAS pour la Bible
          if (!isBible) {
            slivers.add(
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.publication.imageLsr is String && (widget.publication.imageLsr as String).isNotEmpty && widget.publication.path?.isNotEmpty == true)
                      GestureDetector(
                        onTap: () {
                          final String imageLsr = widget.publication.imageLsr as String;
                          final String imagePath = '${widget.publication.path}/${imageLsr.split('/').last}';
                          showPage(ImagePage(filePath: imagePath));
                        },
                        child: Image.file(
                          File('${widget.publication.path}/${(widget.publication.imageLsr as String).split('/').last}'),
                          fit: BoxFit.fill,
                          width: double.infinity,
                        ),
                      ),

                    const SizedBox(height: 15),
                    Text(
                      widget.publication.coverTitle.isNotEmpty ? widget.publication.coverTitle : widget.publication.title,
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 25, fontWeight: FontWeight.bold, height: 1.2),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.publication.description.isNotEmpty) const SizedBox(height: 15),
                    if (widget.publication.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextHtmlWidget(
                          text: widget.publication.description,
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 15, height: 1.2),
                          textAlign: TextAlign.center,
                          isSearch: false,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          // TabBar
          final TabBar tabBarWidget = isBible ?
          TabBar(
            controller: _tabController,
            isScrollable: true,
            dividerHeight: 1,
            dividerColor: const Color(0xFF686868),
            tabs: _model.tabsWithItems.map((tabWithItems) { return Tab(text: tabWithItems.tab['Title'] ?? 'Tab'); }).toList(),
          )
              :
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.black,
            dividerHeight: 0,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2),
            unselectedLabelStyle: const TextStyle(fontSize: 15, letterSpacing: 2),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorPadding: const EdgeInsets.symmetric(vertical: 5.0),
            labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
            tabs: _model.tabsWithItems.map((tabWithItems) { return Tab(text: tabWithItems.tab['Title'] ?? 'Tab'); }).toList(),
          );

          if (isBible) {
            // Cas BIBLE : Utiliser SliverAppBar avec `pinned: true` pour maintenir la TabBar fixe
            slivers.add(
              SliverAppBar(
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                pinned: true,
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
                bottom: PreferredSize(
                  preferredSize: tabBarWidget.preferredSize,
                  child: tabBarWidget,
                ),
              ),
            );
          } else {
            // Cas NON-BIBLE : La TabBar défile avec le reste du contenu d'en-tête.
            slivers.add(
              SliverToBoxAdapter(
                child: tabBarWidget,
              ),
            );
          }

          return slivers;
        },
        body: TabBarView(
          controller: _tabController,
          children: _model.tabsWithItems.map((tabWithItems) {
            // Envelopper la liste de widgets dans un ListView
            return ListView(
              padding: const EdgeInsets.only(bottom: 20.0),
              children: tabWithItems.items.any((item) => item.isBibleBooks) ? _buildBooksTab(context, tabWithItems) : _buildTabContent(context, tabWithItems),
            );
          }).toList(),
        ),
      );
    }

    // Applique ConstrainedBox uniquement si ce n'est PAS la Bible (maxContentWidth non null)
    return Center(
      child: maxContentWidth != null
          ? ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: content,
      )
          : content, // Affiche directement le contenu (plein écran pour la Bible)
    );
  }


  Widget _buildCircuitMenu() {
    // Récupération de la couleur de texte en fonction du thème
    final textColor = Theme
        .of(context)
        .brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Liste des éléments dans une colonne
        _isLoading ? Center(child: CircularProgressIndicator()) : Column(
          children: _model.tabsWithItems.first.items.map<Widget>((item) {
            bool hasImageFilePath = _model.tabsWithItems.first.items.any((
                item) => item.imageFilePath != '');

            if (item.isTitle) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 19.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Divider(
                          color: Color(0xFFa7a7a7),
                          height: 1,
                        ),
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                  ...item.subItems.map<Widget>((subItem) {
                    return _buildNameItem(context, hasImageFilePath, subItem);
                  }),
                ],
              );
            }
            else {
              return _buildNameItem(context, hasImageFilePath, item);
            }
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Appel obligatoire pour AutomaticKeepAliveClientMixin
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFc3c3c3) : const Color(0xFF626262),
    );

    return !widget.showAppBar
        ? _buildCircuitMenu()
        : Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFf1f1f1),
      resizeToAvoidBottomInset: false,
      appBar: _isSearching
          ? AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { setState(() { _isSearching = false; }); }),

          // BARRE DE RECHERCHE CORRIGÉE
          title: SearchFieldWidget(
            query: '',

            // onSearchTextChanged: Appel du modèle pour lancer la recherche (void)
            onSearchTextChanged: (text) {
              // Vérifie que wordsSuggestionsModel est initialisé lors du clic sur Rechercher
              widget.publication.wordsSuggestionsModel?.fetchSuggestions(text);
            },

            // onSuggestionTap: Utilisation de item.item.caption pour le mot suggéré
            onSuggestionTap: (item) async {
              // item.item est de type SuggestionItem (avec .caption pour le texte du mot)
              final String query = item.item!.query;
              showPage(PublicationSearchView(query: query, publication: widget.publication));
              setState(() { _isSearching = false; });
            },

            onSubmit: (text) async {
              setState(() { _isSearching = false; });
              showPage(PublicationSearchView(query: text, publication: widget.publication));
            },

            onTapOutside: (event) {
              setState(() { _isSearching = false; });
            },

            // suggestionsNotifier: Utilisation du ValueNotifier du modèle
            suggestionsNotifier: widget.publication.wordsSuggestionsModel?.suggestionsNotifier ?? ValueNotifier([]),
          )
      ) : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.publication.getShortTitle(), style: textStyleTitle),
            Text("${widget.publication.mepsLanguage.vernacular} · ${widget.publication.keySymbol}", style: textStyleSubtitle),
          ],
        ),
        leading: widget.biblePage ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { GlobalKeyService.jwLifePageKey.currentState?.handleBack(context); }),
        actions: [
          ResponsiveAppBarActions(
            allActions: [
              IconTextButton(text: "Rechercher", icon: const Icon(JwIcons.magnifying_glass), onPressed: () async {
                // Initialisation du modèle lors du clic sur rechercher
                widget.publication.wordsSuggestionsModel ??= WordsSuggestionsModel(widget.publication);
                setState(() { _isSearching = true; });
              }),
              IconTextButton(text: "Marque-pages", icon: const Icon(JwIcons.bookmark), onPressed: () async {
                Bookmark? bookmark = await showBookmarkDialog(context, widget.publication);
                if (bookmark != null) {
                  // Utilisation de ?? 0 pour éviter le '!'
                  if (bookmark.location.bookNumber != null && bookmark.location.chapterNumber != null) { showPageBibleChapter(widget.publication, bookmark.location.bookNumber ?? 0, bookmark.location.chapterNumber ?? 0, firstVerse: bookmark.blockIdentifier, lastVerse: bookmark.blockIdentifier); }
                  else if (bookmark.location.mepsDocumentId != null) { showPageDocument(widget.publication, bookmark.location.mepsDocumentId ?? 0, startParagraphId: bookmark.blockIdentifier, endParagraphId: bookmark.blockIdentifier); }
                }
              }),
              IconTextButton(text: "Langues", icon: const Icon(JwIcons.language), onPressed: () async {
                if(widget.biblePage) { showLanguagePubDialog(context, null).then((languageBible) async { if (languageBible != null) { String bibleKey = languageBible.getKey(); JwLifeSettings().lookupBible = bibleKey; setLookUpBible(bibleKey); GlobalKeyService.bibleKey.currentState?.refreshBiblePage(); } }); }
                else { showLanguagePubDialog(context, widget.publication).then((languagePub) async { if(languagePub != null) { languagePub.showMenu(context); } }); }
              }),
              IconTextButton(text: "Ajouter un widget sur l'écran d'accueil", icon: const Icon(JwIcons.article), onPressed: () async { /* ... */ }),
              IconTextButton(text: "Télécharger les médias", icon: const Icon(JwIcons.cloud_arrow_down), onPressed: () { showDownloadMediasDialog(context, widget.publication); }),
              IconTextButton(text: "Historique", icon: const Icon(JwIcons.arrow_circular_left_clock), onPressed: () { History.showHistoryDialog(context); }),
              IconTextButton(text: "Envoyer le lien", icon: const Icon(JwIcons.share), onPressed: () { widget.publication.shareLink(); }),
            ],
          ),
        ],
      ),
      body: _buildPublication(),
    );
  }
}
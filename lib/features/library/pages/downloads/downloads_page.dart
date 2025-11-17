import 'package:flutter/material.dart';
import 'package:jwlife/core/app_dimens.dart'; // Importe kItemHeight et kSpacing
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/library/widgets/rectangle_mediaItem_item.dart';
import 'package:jwlife/i18n/i18n.dart';

import '../../../publication/pages/menu/local/publication_menu_view.dart';
import '../../models/downloads/download_model.dart';
import '../../widgets/rectangle_publication_item.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  late final DownloadPageModel _model;

  @override
  void initState() {
    super.initState();
    _model = DownloadPageModel();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // --- Méthode d'aide pour construire un Sliver (remplace _buildSection) ---
  List<Widget> _buildSliverSection<T>(
      String titleKey,
      List<T> items,
      Widget Function(T) buildItem,
      double contentPadding,
      ) {
    if (items.isEmpty) return [];

    // --- Logique de Localisation du Titre ---
    String displayTitle = titleKey;
    if (items.first is Publication) {
      final pub = items.first as Publication;
      // Récupération du nom de catégorie localisé
      displayTitle = pub.category.getName(context);
    }
    else {
      if (titleKey == 'Audios') {
        displayTitle = i18n().pub_type_audio_programs;
      } else if (titleKey == 'Videos') {
        displayTitle = i18n().label_videos;
      }
    }

    // --- Calcul des dimensions pour le SliverGrid (Utilise kItemHeight pour tous) ---
    final screenWidth = MediaQuery.of(context).size.width;
    final isTwoColumn = screenWidth > 800;

    // 🥳 UTILISE kItemHeight pour tous les éléments
    const double itemHeight = kItemHeight;
    final int crossAxisCount = isTwoColumn ? 2 : 1;

    // Recalculer la largeur de l'élément pour garantir l'aspect ratio correct
    const double paddingListView = 10.0; // Le padding de la ListView/CustomScrollView
    const double totalPadding = paddingListView * 2;
    final double totalSpacing = kSpacing * (crossAxisCount - 1);
    final double calculatedItemWidth = (screenWidth - totalPadding - totalSpacing) / crossAxisCount;

    final double childAspectRatio = calculatedItemWidth / itemHeight;

    // --- Construction des Slivers ---
    return [
      // 1. Sliver pour le TITRE
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(left: contentPadding, right: contentPadding, top: 20.0, bottom: 5.0),
          child: Text(
            displayTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),

      // 2. Sliver pour la GRILLE (Contenu virtualisé)
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: kSpacing),
        sliver: SliverGrid.builder(
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: kSpacing,
            crossAxisSpacing: kSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            return GestureDetector(
              onTap: () {
                if (item is Publication) {
                  showPage(PublicationMenuView(publication: item));
                }
                else if (item is Media) {
                  item.showPlayer(context);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF292929)
                      : Colors.white,
                ),
                child: buildItem(item),
              ),
            );
          },
        ),
      ),
    ];
  }

  // --- Méthodes de Construction des Items ---

  Widget _buildPublicationItem(Publication publication) {
    return RectanglePublicationItem(
      publication: publication,
    );
  }

  Widget _buildMediaButton(Media media) {
    return RectangleMediaItemItem(
      media: media,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 10.0 correspond au padding horizontal total de la ListView/CustomScrollView
    final screenWidth = MediaQuery.of(context).size.width;
    final double contentPadding = getContentPadding(screenWidth);

    return ListenableBuilder(
      listenable: _model,
      builder: (context, child) {
        if (_model.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final groupedPublications = _model.groupedPublications;
        final groupedMedias = _model.groupedMedias;

        final List<Widget> slivers = [];

        // 1. Bouton d'import (SliverToBoxAdapter)
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: OutlinedButton.icon(
                onPressed: () => _model.importJwpub(context),
                icon: const Icon(JwIcons.document),
                label: Text(i18n().label_import_jwpub),
                style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder()),
              ),
            ),
          ),
        );

        // 2. Sections des publications
        if (groupedPublications.isNotEmpty) {
          groupedPublications.entries.map((entry) {
            slivers.addAll(_buildSliverSection<Publication>(
                entry.key,
                entry.value,
                _buildPublicationItem,
                contentPadding
            ));
          }).toList();
        }

        // 3. Sections des médias
        if (groupedMedias.isNotEmpty) {
          groupedMedias.entries.map((entry) {
            slivers.addAll(_buildSliverSection<Media>(
                entry.key,
                entry.value,
                _buildMediaButton,
                contentPadding
            ));
          }).toList();
        }

        // ajouter un padding
        slivers.add(
          SliverToBoxAdapter(
            child: SizedBox(height: contentPadding),
          ),
        );

        // 4. CustomScrollView pour un défilement fluide
        return CustomScrollView(
          slivers: slivers,
        );
      },
    );
  }
}
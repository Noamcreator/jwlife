import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/icons.dart'; // Import pour les icônes
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/library/widgets/rectangle_mediaItem_item.dart';
import 'package:jwlife/i18n/i18n.dart'; // Import pour i18n

import '../../../../core/utils/widgets_utils.dart';
import '../../../../widgets/multiple_listenable_builder_widget.dart';
import '../../../publication/pages/local/publication_menu_view.dart';
import '../../models/pending_update/pending_update_model.dart';
import '../../widgets/rectangle_publication_item.dart';

class PendingUpdatesWidget extends StatefulWidget {
  final PendingUpdatesPageModel model;
  const PendingUpdatesWidget({super.key, required this.model});

  @override
  _PendingUpdatesWidgetState createState() => _PendingUpdatesWidgetState();
}

class _PendingUpdatesWidgetState extends State<PendingUpdatesWidget> {
  late final PendingUpdatesPageModel _model;

  @override
  void initState() {
    super.initState();
    _model = widget.model;
  }

  /// Message affiché lorsqu'il n'y a aucune mise à jour en attente
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: emptyStateWidget(i18n().messages_empty_downloads, JwIcons.arrows_circular),
    );
  }

  List<Widget> _buildSliverSection<T>(List<T> items, double contentPadding) {
    // FILTRE : On ne garde que les éléments qui ont réellement une mise à jour
    final visibleItems = items.where((item) {
      if (item is Publication) return item.hasUpdateNotifier.value;
      if (item is Media) return item.hasUpdateNotifier.value;
      return false;
    }).toList();

    if (visibleItems.isEmpty) return [];

    final screenWidth = MediaQuery.of(context).size.width;
    final isTwoColumn = screenWidth > 800;
    final int crossAxisCount = isTwoColumn ? 2 : 1;
    final double calculatedItemWidth = (screenWidth - (getContentPadding(screenWidth) * 2) - (kSpacing * (crossAxisCount - 1))) / crossAxisCount;

    return [
      SliverPadding(
        padding: EdgeInsets.all(contentPadding),
        sliver: SliverGrid.builder(
          itemCount: visibleItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: kSpacing,
            crossAxisSpacing: kSpacing,
            childAspectRatio: calculatedItemWidth / kItemHeight,
          ),
          itemBuilder: (context, index) {
            final item = visibleItems[index];
            return GestureDetector(
              onTap: () {
                if (item is Publication) {
                  showPage(PublicationMenuPage(publication: item));
                }
              },
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                child: item is Publication
                    ? RectanglePublicationItem(publication: item)
                    : RectangleMediaItemItem(media: item as Media),
              ),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double contentPadding = getContentPadding(MediaQuery.of(context).size.width);

    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        if (_model.isLoading) return getLoadingWidget(Theme.of(context).primaryColor);

        // Récupération de tous les notifiers pour vider la liste en temps réel dès qu'une MAJ est faite
        final allUpdateNotifiers = <ValueNotifier<bool>>[];
        for (var item in _model.mixedItems) {
          if (item is Publication) allUpdateNotifiers.add(item.hasUpdateNotifier);
          if (item is Media) allUpdateNotifiers.add(item.hasUpdateNotifier);
        }

        return MultiValueListenableBuilder(
          listenables: allUpdateNotifiers,
          builder: (context) {
            final List<Widget> slivers = [];
            final List<Widget> contentSections = [];

            // 1. Construction des sections de contenu
            if (_model.mixedItems.isNotEmpty) {
              contentSections.addAll(_buildSliverSection(_model.mixedItems, contentPadding));
            } 

            // 2. Vérification si on a du contenu après filtrage
            if (contentSections.isEmpty) {
              slivers.add(_buildEmptyState());
            } else {
              slivers.addAll(contentSections);
            }

            // Petit espacement en bas pour le scroll
            slivers.add(SliverToBoxAdapter(child: SizedBox(height: contentPadding)));

            return CustomScrollView(slivers: slivers);
          },
        );
      },
    );
  }
}
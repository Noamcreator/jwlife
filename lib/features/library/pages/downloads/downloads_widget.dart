import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/library/widgets/rectangle_mediaItem_item.dart';
import 'package:jwlife/i18n/i18n.dart';

import '../../../../core/utils/widgets_utils.dart';
import '../../../../data/models/audio.dart';
import '../../../../widgets/multiple_listenable_builder_widget.dart';
import '../../../publication/pages/local/publication_menu_view.dart';
import '../../models/downloads/download_model.dart';
import '../../widgets/rectangle_publication_item.dart';

class DownloadWidget extends StatefulWidget {
  final DownloadPageModel model;
  const DownloadWidget({super.key, required this.model});

  @override
  _DownloadWidgetState createState() => _DownloadWidgetState();
}

class _DownloadWidgetState extends State<DownloadWidget> {
  late final DownloadPageModel _model;

  @override
  void initState() {
    super.initState();
    _model = widget.model;
  }

  /// Affiche un message et une icône quand la liste est vide
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              JwIcons.publication_video_music,
              size: 100,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              i18n().messages_empty_downloads, // Assure-toi que cette clé existe ou utilise "Aucun téléchargement"
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSliverSection<T>(String? title, List<T> items, double contentPadding) {
    // Filtrage strict : on ne garde que ce qui est réellement sur l'appareil
    final visibleItems = items.where((item) {
      if (item is Publication) {
        return item.isDownloadedNotifier.value;
      } else if (item is Media) {
        return item.isDownloadedNotifier.value;
      }
      return false;
    }).toList();

    if (visibleItems.isEmpty) return [];

    final screenWidth = MediaQuery.of(context).size.width;
    final isTwoColumn = screenWidth > 800;
    final int crossAxisCount = isTwoColumn ? 2 : 1;

    const double paddingListView = 10.0;
    const double totalPadding = paddingListView * 2;
    final double totalSpacing = kSpacing * (crossAxisCount - 1);
    final double calculatedItemWidth = (screenWidth - totalPadding - totalSpacing) / crossAxisCount;
    final double childAspectRatio = calculatedItemWidth / kItemHeight;

    return [
      if (title != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(left: contentPadding, right: contentPadding, top: 20.0, bottom: 5.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: kSpacing),
        sliver: SliverGrid.builder(
          itemCount: visibleItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: kSpacing,
            crossAxisSpacing: kSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = visibleItems[index];

            return GestureDetector(
              onTap: () {
                if (item is Publication) {
                  showPage(PublicationMenuView(publication: item));
                } else if (item is Media) {
                  item.showPlayer(context);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF292929)
                      : Colors.white,
                ),
                child: item is Publication
                    ? RectanglePublicationItem(publication: item, showSize: true)
                    : RectangleMediaItemItem(media: item as Media, showSize: true),
              ),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double contentPadding = getContentPadding(screenWidth);

    return ListenableBuilder(
      listenable: _model,
      builder: (context, child) {
        if (_model.isLoading) return getLoadingWidget(Theme.of(context).primaryColor);

        // Récupération des notifiers pour réagir aux suppressions en temps réel
        final List<ValueNotifier<bool>> allNotifiers = [];
        for (var item in [..._model.mixedItems, ..._model.groupedItems.values.expand((e) => e)]) {
          if (item is Publication) allNotifiers.add(item.isDownloadedNotifier);
          if (item is Media) allNotifiers.add(item.isDownloadedNotifier);
        }

        return MultiValueListenableBuilder(
          listenables: allNotifiers,
          builder: (context) {
            final List<Widget> slivers = [];

            // 1. Bouton d'import (Toujours affiché)
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

            // 2. Construction des sections de contenu
            final List<Widget> contentSlivers = [];
            if (_model.mixedItems.isNotEmpty) {
              contentSlivers.addAll(_buildSliverSection<dynamic>(null, _model.mixedItems, contentPadding));
            } else {
              _model.groupedItems.forEach((key, list) {
                if (list.isNotEmpty) {
                  String title = "";
                  if (list.first is Publication) {
                    title = (list.first as Publication).category.getName();
                  }
                  else if (list.first is Media) {
                    title = list.first is Audio ? i18n().pub_type_audio_programs : i18n().label_videos;
                  }
                  contentSlivers.addAll(_buildSliverSection<dynamic>(title, list, contentPadding));
                }
              });
            }

            // 3. Affichage du contenu ou du message "Vide"
            if (contentSlivers.isEmpty) {
              slivers.add(_buildEmptyState());
            } else {
              slivers.addAll(contentSlivers);
            }

            slivers.add(SliverToBoxAdapter(child: SizedBox(height: contentPadding)));
            return CustomScrollView(slivers: slivers);
          },
        );
      },
    );
  }
}
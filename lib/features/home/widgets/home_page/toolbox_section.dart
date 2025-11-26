import 'package:flutter/material.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../core/app_data/app_data_service.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../data/models/media.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';

class ToolboxSection extends StatelessWidget {
  const ToolboxSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// ------------------------------------------------------------
        /// 🔹 Toolbox – Médias en premier, puis Publications
        /// ------------------------------------------------------------
        ValueListenableBuilder<List<Media>>(
          valueListenable: AppDataService.instance.teachingToolboxMedias,
          builder: (context, medias, _) {
            return ValueListenableBuilder<List<Publication?>>(
              valueListenable:
              AppDataService.instance.teachingToolboxPublications,
              builder: (context, pubs, _) {
                final combined = [
                  ...medias,
                  ...pubs,
                ];

                if (combined.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n().navigation_ministry,
                      style: Theme.of(context)
                          .extension<JwLifeThemeStyles>()!
                          .labelTitle,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        scrollDirection: Axis.horizontal,
                        itemCount: combined.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 2),
                        itemBuilder: (context, index) {
                          final item = combined[index];
                          return _buildToolboxItem(item, context);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 8),

        /// ------------------------------------------------------------
        /// 🔹 Tracts Publications
        /// ------------------------------------------------------------
        ValueListenableBuilder<List<Publication?>>(
          valueListenable:
          AppDataService.instance.teachingToolboxTractsPublications,
          builder: (context, tractsList, _) {
            if (tractsList.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 100,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemCount: tractsList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 2),
                itemBuilder: (context, index) {
                  final pub = tractsList[index];
                  return _buildToolboxItem(pub, context);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolboxItem(dynamic item, BuildContext context) {
    if (item is Media) {
      return HomeSquareMediaItemItem(media: item);
    }
    else if (item is Publication) {
      return HomeSquarePublicationItem(pub: item, toolbox: true);
    }
    return const SizedBox(width: 20);
  }
}

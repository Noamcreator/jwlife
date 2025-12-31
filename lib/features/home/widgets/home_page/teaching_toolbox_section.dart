import 'package:flutter/material.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../core/app_data/app_data_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/media.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';

class TeachingToolboxSection extends StatelessWidget {
  const TeachingToolboxSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Toolbox – Médias en premier, puis Publications
        ValueListenableBuilder<List<Media>>(
          valueListenable: AppDataService.instance.teachingToolboxMedias,
          builder: (context, medias, _) {
            return ValueListenableBuilder<List<Publication?>>(
              valueListenable: AppDataService.instance.teachingToolboxPublications,
              builder: (context, pubs, _) {
                final combined = [
                  ...medias,
                  ...pubs,
                ];

                if (combined.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            //showPage(NotesTagsPage());
                          },
                          child: Row(
                            children: [
                              Text(
                                i18n().navigation_ministry,
                                style: Theme.of(context).extension<
                                    JwLifeThemeStyles>()!.labelTitle,
                              ),
                              SizedBox(width: 2),
                              Icon(
                                JwIcons.chevron_right,
                                color: Theme.of(context).secondaryHeaderColor,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                        ValueListenableBuilder(
                            valueListenable: JwLifeSettings.instance.teachingToolboxLanguage,
                            builder: (context, mepsLanguage, child) {
                              return GestureDetector(
                                  onTap: () {
                                    showLanguageDialog(context, firstSelectedLanguage: mepsLanguage.symbol).then((language) async {
                                      if (language != null) {
                                        if (language['Symbol'] != mepsLanguage.symbol) {
                                          await AppSharedPreferences.instance.setTeachingToolboxLanguage(language);
                                          AppDataService.instance.changeTeachingToolboxLanguageAndRefresh();
                                        }
                                      }
                                    });
                                  },
                                  child: Text(
                                      mepsLanguage.vernacular,
                                      style: TextStyle(color: Theme.of(context).primaryColor)
                                  )
                              );
                            }
                        )
                      ],
                    ),
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

        // Tracts Publications
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
      return HomeSquarePublicationItem(publication: item, toolbox: true);
    }
    return const SizedBox(width: 20);
  }
}

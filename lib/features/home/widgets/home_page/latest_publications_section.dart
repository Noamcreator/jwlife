import 'package:flutter/material.dart';
import 'package:jwlife/features/home/widgets/home_page/rectangle_publication_item.dart';
import '../../../../app/services/settings_service.dart';
import '../../../../core/app_data/app_data_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';

class LatestPublicationSection extends StatelessWidget {
  const LatestPublicationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: AppDataService.instance.latestPublications,
      builder: (context, latestList, _) {
        // Convert dynamic → Publication si nécessaire
        final latestPublications = latestList
            .whereType<Publication>()
            .toList();

        if (latestPublications.isEmpty) {
          return const SizedBox.shrink();
        }

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
                        i18n().navigation_whats_new,
                        style: Theme.of(context).extension<JwLifeThemeStyles>()!.labelTitle
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
                    valueListenable: JwLifeSettings.instance.latestLanguage,
                    builder: (context, mepsLanguage, child) {
                      return GestureDetector(
                          onTap: () {
                            showLanguageDialog(context, firstSelectedLanguage: mepsLanguage.symbol).then((language) async {
                              if (language != null) {
                                if (language['Symbol'] != mepsLanguage.symbol) {
                                  await AppSharedPreferences.instance.setLatestLanguage(language);
                                  AppDataService.instance.changeLatestLanguageAndRefresh();
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
              height: 80, // Ajuster la hauteur si besoin
              child: ListView.builder(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemCount: latestPublications.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 2.0),
                    child: HomeRectanglePublicationItem(
                      pub: latestPublications[index],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
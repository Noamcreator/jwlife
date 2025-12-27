import 'package:flutter/material.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../core/app_data/app_data_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/ui/text_styles.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';

class FrequentlyUsedSection extends StatelessWidget {
  const FrequentlyUsedSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Publication>>(
      valueListenable: AppDataService.instance.frequentlyUsed,
      builder: (context, frequentlyUsed, _) {

        if (frequentlyUsed.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                //showPage(NotesTagsPage());
              },
              child: Row(
                children: [
                  Text(
                      i18n().navigation_frequently_used,
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
            SizedBox(
              height: 120,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemCount: frequentlyUsed.length,
                itemBuilder: (context, index) {
                  final publication = frequentlyUsed[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 2.0),
                    child: HomeSquarePublicationItem(publication: publication),
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
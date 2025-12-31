import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/features/home/widgets/home_page/alerts_banner.dart';
import 'package:jwlife/features/home/widgets/home_page/articles_widget.dart';
import 'package:jwlife/features/home/widgets/home_page/daily_text_widget.dart';
import 'package:jwlife/features/home/widgets/home_page/favorite_section.dart';
import 'package:jwlife/features/home/widgets/home_page/frequently_used_section.dart';
import 'package:jwlife/features/home/widgets/home_page/latest_medias_section.dart';
import 'package:jwlife/features/home/widgets/home_page/latest_publications_section.dart';
import 'package:jwlife/features/home/widgets/home_page/linear_progress.dart';
import 'package:jwlife/features/home/widgets/home_page/online_section.dart';
import 'package:jwlife/features/home/widgets/home_page/teaching_toolbox_section.dart';

class HomeContent extends StatelessWidget {
  final double horizontalPadding;
  final double sizeDivider;

  // Le constructeur const est la clé
  const HomeContent({
    super.key,
    required this.horizontalPadding,
    required this.sizeDivider,
  });

  @override
  Widget build(BuildContext context) {
    // Cette liste ne sera construite qu'une seule fois
    final List<Widget> items = [
      const LinearProgress(),
      const AlertsBanner(),
      const DailyTextWidget(),
      const ArticlesWidget(),
      const SizedBox(height: 30),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          children: [
            FavoritesSection(
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                JwLifeApp.userdata.reorderFavorites(oldIndex, newIndex);
              },
            ),
            const FrequentlyUsedSection(),
            SizedBox(height: sizeDivider),
            const TeachingToolboxSection(),
            SizedBox(height: sizeDivider),
            const LatestPublicationSection(),
            const SizedBox(height: 4),
            const LatestMediasSection(),
            SizedBox(height: sizeDivider),
            const OnlineSection(),
            const SizedBox(height: 25),
          ],
        ),
      ),
    ];

    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(), // Important pour le refresh
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}
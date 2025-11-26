import 'package:flutter/material.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/widgets/mediaitem_item_widget.dart';
import '../../../../core/app_data/app_data_service.dart';

class LatestMediasSection extends StatelessWidget {
  const LatestMediasSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Media>>(
      valueListenable: AppDataService.instance.latestMedias,
      builder: (context, latestMedias, _) {
        if (latestMedias.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 140,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: latestMedias.length,
            itemBuilder: (context, index) {
              final media = latestMedias[index];
              return MediaItemItemWidget(
                media: media,
                timeAgoText: true,
              );
            },
          ),
        );
      },
    );
  }
}

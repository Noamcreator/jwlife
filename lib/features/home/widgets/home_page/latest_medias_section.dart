import 'package:flutter/material.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/widgets/mediaitem_item_widget.dart';
import '../../../../core/app_data/app_data_service.dart';

class LatestMediasSection extends StatelessWidget {
  const LatestMediasSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Media>>(
      valueListenable: AppDataService.instance.latestMedias,
      builder: (context, latestMedias, _) {
        if (latestMedias.isEmpty) {
          return SizedBox(
            height: 50,
            child: Center(
              child: Text(
                i18n().message_no_media_items,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFFc3c3c3)
                      : Color(0xFF626262),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }

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

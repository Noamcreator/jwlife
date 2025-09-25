import 'package:flutter/material.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/realm/realm_library.dart';

import '../../../../widgets/mediaitem_item_widget.dart';

class LatestMediasSection extends StatefulWidget {
  const LatestMediasSection({super.key});

  @override
  State<LatestMediasSection> createState() => LatestMediasSectionState();
}

class LatestMediasSectionState extends State<LatestMediasSection> {
  List<Media> _latestMedias = [];

  void refreshLatestMedias() {
    setState(() {
      _latestMedias = RealmLibrary.loadLatestMedias();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _latestMedias.isEmpty ? const SizedBox.shrink() : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.all(0.0),
            scrollDirection: Axis.horizontal,
            itemCount: _latestMedias.length,
            itemBuilder: (context, mediaIndex) {
              return MediaItemItemWidget(
                  media: _latestMedias[mediaIndex],
                  timeAgoText: true
              );
            },
          ),
        ),
      ],
    );
  }
}

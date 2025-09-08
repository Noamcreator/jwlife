import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/realm/realm_library.dart';
import 'package:jwlife/features/home/widgets/home_page/rectangle_publication_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../core/icons.dart';
import '../../../../data/databases/catalog.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../i18n/localization.dart';
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

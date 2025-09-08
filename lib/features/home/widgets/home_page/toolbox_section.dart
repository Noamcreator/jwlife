import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../core/icons.dart';
import '../../../../data/databases/catalog.dart';
import '../../../../data/models/media.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../data/realm/realm_library.dart';
import '../../../../i18n/localization.dart';

class ToolboxSection extends StatefulWidget {
  const ToolboxSection({super.key});

  @override
  State<ToolboxSection> createState() => ToolboxSectionState();
}

class ToolboxSectionState extends State<ToolboxSection> {
  final List<dynamic> _toolbox = [];

  void refreshToolbox() {
    setState(() {
      _toolbox.clear();
      _toolbox.addAll(RealmLibrary.loadTeachingToolboxVideos());
      _toolbox.addAll(PubCatalog.teachingToolboxPublications);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _toolbox.isEmpty ? const SizedBox.shrink() : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localization(context).navigation_ministry,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 120,
          child: ListView.builder(
            padding: const EdgeInsets.all(0.0),
            scrollDirection: Axis.horizontal,
            itemCount: _toolbox.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 2.0),
                child: _buildToolboxItem(_toolbox[index], context),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolboxItem(dynamic item, BuildContext context) {
    if (item is Publication) {
      return HomeSquarePublicationItem(pub: item);
    }
    if (item is Media) {
      return HomeSquareMediaItemItem(media: item);
    }
    else {
      return const SizedBox(width: 20);
    }
  }
}

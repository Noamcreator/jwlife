import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/features/home/widgets/home_page/rectangle_publication_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../core/icons.dart';
import '../../../../data/databases/catalog.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../i18n/localization.dart';

class LatestPublicationSection extends StatefulWidget {
  const LatestPublicationSection({super.key});

  @override
  State<LatestPublicationSection> createState() => LatestPublicationsSectionState();
}

class LatestPublicationsSectionState extends State<LatestPublicationSection> {
  List<Publication> _latestPublications = [];

  void refreshLatestPublications() {
    setState(() {
      _latestPublications = PubCatalog.latestPublications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _latestPublications.isEmpty ? const SizedBox.shrink() : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localization(context).navigation_whats_new,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 80, // Adjust height as needed
          child: ListView.builder(
            padding: const EdgeInsets.all(0.0),
            scrollDirection: Axis.horizontal, // Définit le scroll en horizontal
            itemCount: _latestPublications.length,
            itemBuilder: (context, index) {
              return Padding(
                  padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                  child: HomeRectanglePublicationItem(pub: _latestPublications[index])
              );
            },
          ),
        ),
      ],
    );
  }
}

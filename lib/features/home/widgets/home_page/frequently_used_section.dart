import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/features/home/widgets/home_page/square_mediaitem_item.dart';
import 'package:jwlife/features/home/widgets/home_page/square_publication_item.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../core/icons.dart';
import '../../../../data/databases/catalog.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/realm/catalog.dart';
import '../../../../i18n/localization.dart';

class FrequentlyUsedSection extends StatefulWidget {
  const FrequentlyUsedSection({super.key});

  @override
  State<FrequentlyUsedSection> createState() => FrequentlyUsedSectionState();
}

class FrequentlyUsedSectionState extends State<FrequentlyUsedSection> {
  List<dynamic> _frequentlyUsed = [];

  void refreshFrequentlyUsed() {
    setState(() {
      _frequentlyUsed = PubCatalog.recentPublications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _frequentlyUsed.isEmpty ? const SizedBox.shrink() : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Souvent utilisé', // frequently used
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 120, // Hauteur à ajuster selon votre besoin
          child: ListView.builder(
            padding: const EdgeInsets.all(0.0),
            scrollDirection: Axis.horizontal,
            itemCount: _frequentlyUsed.length,
            itemBuilder: (context, index) {
              Publication publication = _frequentlyUsed[index];
              return Padding(
                padding: const EdgeInsets.only(right: 2.0), // Espacement entre les items
                child: HomeSquarePublicationItem(pub: publication),
              );
            },
          ),
        ),
      ],
    );
  }
}

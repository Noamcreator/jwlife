import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/databases/publication_category.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/library/widgets/RectanglePublicationItem.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../data/databases/publication_attribute.dart';

class PublicationsItemsView extends StatefulWidget {
  final PublicationCategory category;
  final int? year;

  const PublicationsItemsView({super.key, required this.category, this.year});

  @override
  _PublicationsItemsViewState createState() => _PublicationsItemsViewState();
}

class _PublicationsItemsViewState extends State<PublicationsItemsView> {
  Map<PublicationAttribute, List<Publication>> publications = {};

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  void loadItems() async {
    Map<PublicationAttribute, List<Publication>> publications;

    if (widget.year != null) {
      // Récupération des publications pour une année spécifique
      publications = await PubCatalog.getPublicationsFromCategory(
        widget.category.id,
        year: widget.year,
      );
    }
    else {
      // Récupération de toutes les publications sans filtrage par année
      publications = await PubCatalog.getPublicationsFromCategory(widget.category.id);
    }

    // Remplace les publications existantes
    this.publications = publications;

    // Ajoute les publications manquantes provenant des collections personnelles
    for (var pub in PublicationRepository().getAllDownloadedPublications()) {
      if (pub.category.id == widget.category.id && pub.mepsLanguage.id == JwLifeSettings().currentLanguage.id && (widget.year == null || pub.year == widget.year) && !this.publications.values.expand((list) => list).any((p) => p.symbol == pub.symbol && p.issueTagNumber == pub.issueTagNumber)) {
        this.publications.putIfAbsent(pub.attribute, () => []).add(pub);
      }
    }

    var sortedEntries = this.publications.keys.toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // Trie par ordre croissant des clés

    // Rafraîchit l'interface
    setState(() {
      this.publications = Map.fromEntries(
          sortedEntries.map((key) => MapEntry(key, this.publications[key]!))
      );
    });

  }

  @override
  Widget build(BuildContext context) {
    // Styles partagés
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    final boxDecoration = BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF292929)
          : Colors.white,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.category.getName(context), style: textStyleTitle),
            Text(JwLifeSettings().currentLanguage.vernacular, style: textStyleSubtitle),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => const LanguageDialog(),
              ).then((_) => loadItems());
            },
          ),
        ],
      ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListView.builder(
            itemCount: publications.length,
            itemBuilder: (context, index) {
              PublicationAttribute attribute = publications.keys.elementAt(index);
              List<Publication> publicationsFromAttribute = publications[attribute]!;

              // Tri des publications selon la logique appropriée
              if (widget.category.hasYears) {
                publicationsFromAttribute.sort((a, b) => a.issueTagNumber.compareTo(b.issueTagNumber));
              }
              else {
                bool shouldSortByYear = attribute.id != -1 && attribute.order == 1;

                if (shouldSortByYear) {
                  publicationsFromAttribute.sort((a, b) => b.year.compareTo(a.year));
                } else {
                  publicationsFromAttribute.sort((a, b) {
                    String titleA = a.title.toLowerCase();
                    String titleB = b.title.toLowerCase();
                    bool isSpecialA = RegExp(r'^[^a-zA-Z]').hasMatch(titleA);
                    bool isSpecialB = RegExp(r'^[^a-zA-Z]').hasMatch(titleB);
                    return isSpecialA == isSpecialB ? titleA.compareTo(titleB) : (isSpecialA ? -1 : 1);
                  });
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (attribute.id != 0)
                    Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0.0 : 40.0, bottom: 5.0),
                      child: Text(
                        attribute.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 3.0,
                    runSpacing: 3.0,
                    children: publicationsFromAttribute.map((publication) {
                      return RectanglePublicationItem(pub: publication);
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        )
    );
  }
}
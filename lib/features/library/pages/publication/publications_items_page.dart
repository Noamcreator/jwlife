import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../data/models/publication_attribute.dart';

class PublicationsItemsView extends StatefulWidget {
  final PublicationCategory category;
  final int? year;

  const PublicationsItemsView({super.key, required this.category, this.year});

  @override
  _PublicationsItemsViewState createState() => _PublicationsItemsViewState();
}

class _PublicationsItemsViewState extends State<PublicationsItemsView> {
  Map<PublicationAttribute, List<Publication>> publications = {};
  List<dynamic> flattenedItems = []; // Liste plate contenant les titres et publications

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

    var sortedEntries = this.publications.keys.toList()..sort((a, b) => a.id.compareTo(b.id));
    this.publications = Map.fromEntries(sortedEntries.map((key) => MapEntry(key, this.publications[key]!)));

    // Création de la liste plate
    _createFlattenedList();

    // Rafraîchit l'interface
    setState(() {});
  }

  void _createFlattenedList() {
    flattenedItems.clear();

    publications.forEach((attribute, publicationsFromAttribute) {
      // Tri des publications selon la logique appropriée
      if (widget.category.hasYears) {
        publicationsFromAttribute.sort((a, b) => a.issueTagNumber.compareTo(b.issueTagNumber));
      }
      else {
        bool shouldSortByYear = attribute.id != -1 && attribute.order == 1;

        if (shouldSortByYear) {
          publicationsFromAttribute.sort((a, b) => b.year.compareTo(a.year));
        }
        else {
          publicationsFromAttribute.sort((a, b) {
            String titleA = a.title.toLowerCase();
            String titleB = b.title.toLowerCase();
            bool isSpecialA = RegExp(r'^[^a-zA-Z]').hasMatch(titleA);
            bool isSpecialB = RegExp(r'^[^a-zA-Z]').hasMatch(titleB);
            return isSpecialA == isSpecialB ? titleA.compareTo(titleB) : (isSpecialA ? -1 : 1);
          });
        }
      }

      // Ajouter le titre de la section si nécessaire
      if (attribute.id != 0) {
        flattenedItems.add({
          'type': 'header',
          'attribute': attribute,
          'isFirst': flattenedItems.isEmpty,
        });
      }

      // Ajouter toutes les publications de cette section
      for (var publication in publicationsFromAttribute) {
        flattenedItems.add({
          'type': 'publication',
          'publication': publication,
        });
      }
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.year != null ? '${widget.year}' : widget.category.getName(context), style: textStyleTitle),
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
          itemCount: flattenedItems.length,
          itemBuilder: (context, index) {
            final item = flattenedItems[index];

            if (item['type'] == 'header') {
              return Padding(
                padding: EdgeInsets.only(
                  top: item['isFirst'] ? 0.0 : 40.0,
                  bottom: 5.0,
                ),
                child: Text(
                  item['attribute'].name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 3.0),
                child: RectanglePublicationItem(pub: item['publication']),
              );
            }
          },
        ),
      ),
    );
  }
}
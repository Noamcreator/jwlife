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
import '../../../../widgets/searchfield/searchfield_widget.dart';

class PublicationsItemsView extends StatefulWidget {
  final PublicationCategory category;
  final int? year;

  const PublicationsItemsView({super.key, required this.category, this.year});

  @override
  _PublicationsItemsViewState createState() => _PublicationsItemsViewState();
}

class _PublicationsItemsViewState extends State<PublicationsItemsView> {
  String _language = '';
  // Liste complète des publications, telle que chargée depuis la base de données
  Map<PublicationAttribute, List<Publication>> _publications = {};

  // Liste plate (titres et publications)
  final List<dynamic> _flattenedItems = [];

  // Variables pour la recherche
  final TextEditingController _searchController = TextEditingController();
  Map<PublicationAttribute, List<Publication>> _filteredPublications = {};
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void loadItems({Map<String, dynamic>? mepsLanguage}) async {
    Map<PublicationAttribute, List<Publication>> publications;

    int mepsLanguageId = mepsLanguage?['LanguageId'] ?? JwLifeSettings().currentLanguage.id;

    if (widget.year != null) {
      publications = await PubCatalog.getPublicationsFromCategory(
        widget.category.id,
        year: widget.year,
        mepsLanguageId: mepsLanguageId
      );
    }
    else {
      publications = await PubCatalog.getPublicationsFromCategory(
          widget.category.id,
          mepsLanguageId: mepsLanguageId
      );
    }

    _publications = publications;

    for (var pub in PublicationRepository().getAllDownloadedPublications()) {
      if (pub.category.id == widget.category.id && pub.mepsLanguage.id == mepsLanguageId && (widget.year == null || pub.year == widget.year) && !_publications.values.expand((list) => list).any((p) => p.symbol == pub.symbol && p.issueTagNumber == pub.issueTagNumber)) {
        _publications.putIfAbsent(pub.attribute, () => []).add(pub);
      }
    }

    var sortedEntries = _publications.keys.toList()..sort((a, b) => a.id.compareTo(b.id));
    _publications = Map.fromEntries(sortedEntries.map((key) => MapEntry(key, _publications[key]!)));

    // Initialise la liste filtrée avec toutes les publications
    _filteredPublications = Map.from(_publications);
    _createFlattenedList();
    setState(() {
      _language = mepsLanguage?['VernacularName'] ?? JwLifeSettings().currentLanguage.vernacular;
    });
  }

  void _filterPublications(String query) {
    setState(() {
      _filteredPublications = {}; // Réinitialise la carte filtrée
      if (query.isEmpty) {
        // Si la recherche est vide, on affiche toutes les publications
        _filteredPublications = Map.from(_publications);
      } else {
        // Sinon, on filtre les publications
        _publications.forEach((attribute, publicationList) {
          final filteredList = publicationList.where((pub) {
            return pub.title.toLowerCase().contains(query.toLowerCase()) || pub.symbol.toLowerCase().contains(query.toLowerCase());
          }).toList();

          if (filteredList.isNotEmpty) {
            _filteredPublications[attribute] = filteredList;
          }
        });
      }
      _createFlattenedList();
    });
  }

  void _createFlattenedList() {
    _flattenedItems.clear();

    _filteredPublications.forEach((attribute, publicationsFromAttribute) {
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

      if (attribute.id != 0) {
        _flattenedItems.add({
          'type': 'header',
          'attribute': attribute,
          'isFirst': _flattenedItems.isEmpty,
        });
      }

      for (var publication in publicationsFromAttribute) {
        _flattenedItems.add({
          'type': 'publication',
          'publication': publication,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _isSearching
          ? AppBar(
        title: SearchFieldWidget(
          query: '',
          onSearchTextChanged: (text) {
            setState(() {
              _filterPublications(text);
            });
            return null;
          },
          onSuggestionTap: (item) {},
          onSubmit: (item) {
            setState(() {
              _isSearching = false;
            });
          },
          onTapOutside: (event) {
            setState(() {
              _isSearching = false;
            });
          },
          suggestions: [],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _filterPublications('');
            });
          },
        ),
      ) : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.year != null ? '${widget.year}' : widget.category.getName(context), style: textStyleTitle),
            Text(_language, style: textStyleSubtitle),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {
              setState(() {
                setState(() {
                  _isSearching = true;
                  _filterPublications('');
                });
              });
            },
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              LanguageDialog languageDialog = LanguageDialog();
              showDialog(
                context: context,
                builder: (context) => languageDialog,
              ).then((value) async {
                if (value != null) {
                  loadItems(mepsLanguage: value);
                }
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView.builder(
          itemCount: _flattenedItems.length,
          itemBuilder: (context, index) {
            final item = _flattenedItems[index];

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
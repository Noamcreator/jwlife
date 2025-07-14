import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/PublicationCategory.dart';
import 'package:jwlife/data/databases/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/modules/library/widgets/RectanglePublicationItem.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/image_widget.dart';

import '../../../../data/databases/PublicationAttribute.dart';

class PublicationsItemsView extends StatefulWidget {
  final PublicationCategory category;
  final int? year;

  PublicationsItemsView({Key? key, required this.category, this.year}) : super(key: key);

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
      if (pub.category.id == widget.category.id && pub.mepsLanguage.id == JwLifeApp.settings.currentLanguage.id && (widget.year == null || pub.year == widget.year) && !this.publications.values.expand((list) => list).any((p) => p.symbol == pub.symbol && p.issueTagNumber == pub.issueTagNumber)) {
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
            Text(JwLifeApp.settings.currentLanguage.vernacular, style: textStyleSubtitle),
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

// La définition de votre map d'attributs reste inchangée.
Map<int, Map<String, dynamic>> attributes = {
  0: {'key': 'null', 'attribute': '', 'name': '', 'order': 0},
  1: {'key': 'assembly_convention', 'attribute': 'Cast', 'name': 'ASSEMBLÉE RÉGIONALE ET DE CIRCONSCRIPTION', 'order': 1},
  2: {'key': 'circuit_assembly', 'attribute': 'Circuit Assembly', 'name': 'ASSEMBLÉE DE CIRCONSCRIPTION', 'order': 1},
  3: {'key': 'convention', 'attribute': 'Convention', 'name': 'ASSEMBLÉE RÉGIONALE', 'order': 1},
  4: {'key': 'drama', 'attribute': 'Drama', 'name': 'REPRÉSENTATIONS THÉÂTRALES', 'order': 0},
  5: {'key': 'dramatic_bible_reading', 'attribute': 'Dramatic Bible Reading', 'name': 'LECTURES BIBLIQUES THÉÂTRALES', 'order': 0},
  6: {'key': 'envelope', 'attribute': 'Envelope', 'name': 'ENVELOPPE', 'order': 0},
  7: {'key': 'examining_the_scriptures', 'attribute': 'Examining the Scriptures', 'name': 'EXAMINONS LES ÉCRITURES', 'order': 1},
  8: {'key': 'insert', 'attribute': 'Insert', 'name': 'ENCART', 'order': 0},
  9: {'key': 'convention_invitation', 'attribute': 'Invitation', 'name': 'INVITATIONS À L\'ASSEMBLÉE RÉGIONALE', 'order': 0},
  10: {'key': 'kingdom_news', 'attribute': 'Kingdom News', 'name': 'NOUVELLES DU ROYAUME', 'order': 0},
  11: {'key': 'large_print', 'attribute': 'Large Print', 'name': 'GROS CARACTÈRES', 'order': 0},
  12: {'key': 'music', 'attribute': 'Music', 'name': 'MUSIQUE', 'order': 0},
  13: {'key': 'ost', 'attribute': 'OST', 'name': 'BANDE ORIGINALE', 'order': 0},
  14: {'key': 'outline', 'attribute': 'Outline', 'name': 'PLAN', 'order': 0},
  15: {'key': 'poster', 'attribute': 'Poster', 'name': 'AFFICHE', 'order': 0},
  16: {'key': 'public', 'attribute': 'Public', 'name': 'ÉDITION PUBLIQUE', 'order': 1},
  17: {'key': 'reprint', 'attribute': 'Reprint', 'name': 'RÉIMPRESSION', 'order': 0},
  18: {'key': 'sad', 'attribute': 'SAD', 'name': 'ASSEMBLÉE SPÉCIALE', 'order': 0},
  19: {'key': 'script', 'attribute': 'Script', 'name': 'SCRIPT', 'order': 0},
  20: {'key': 'sign_language', 'attribute': 'Sign Language', 'name': 'LANGUE DES SIGNES', 'order': 0},
  21: {'key': 'study_simplified', 'attribute': 'Simplified', 'name': 'ÉDITION D’ÉTUDE (FACILE)', 'order': 1},
  22: {'key': 'study', 'attribute': 'Study', 'name': 'ÉDITION D’ÉTUDE', 'order': 1},
  23: {'key': 'transcript', 'attribute': 'Transcript', 'name': 'TRANSCRIPTION', 'order': 0},
  24: {'key': 'vocal_rendition', 'attribute': 'Vocal Rendition', 'name': 'VERSION CHANTÉE', 'order': 0},
  25: {'key': 'web', 'attribute': 'Web', 'name': 'WEB', 'order': 0},
  26: {'key': 'yearbook', 'attribute': 'Yearbook', 'name': 'ANNUAIRES ET RAPPORTS DES ANNÉES DE SERVICE', 'order': 1},
  27: {'key': 'simplified', 'attribute': 'In-house', 'name': 'VERSION FACILE', 'order': 1},
  28: {'key': 'study_questions', 'attribute': 'Study Questions', 'name': 'QUESTIONS D\'ÉTUDE', 'order': 0},
  29: {'key': 'bethel', 'attribute': 'Bethel', 'name': 'BÉTHEL', 'order': 0},
  30: {'key': 'circuit_overseer', 'attribute': 'Circuit Overseer', 'name': 'RESPONSABLE DE CIRCONSCRIPTION', 'order': 0},
  31: {'key': 'congregation', 'attribute': 'Congregation', 'name': 'ASSEMBLÉE LOCALE', 'order': 0},
  32: {'key': 'archive', 'attribute': 'Archive', 'name': 'PUBLICATIONS PLUS ANCIENNES', 'order': 0},
  33: {'key': 'congregation_circuit_overseer', 'attribute': 'A-Form', 'name': 'ASSEMBLÉE LOCALE ET RESPONSABLE DE CIRCONSCRIPTION', 'order': 0},
  34: {'key': 'ao_form', 'attribute': 'AO-Form', 'name': 'FORMULAIRE AO', 'order': 0},
  35: {'key': 'b_form', 'attribute': 'B-Form', 'name': 'FORMULAIRE B', 'order': 0},
  36: {'key': 'ca_form', 'attribute': 'CA-Form', 'name': 'FORMULAIRE CA', 'order': 0},
  37: {'key': 'cn_form', 'attribute': 'CN-Form', 'name': 'FORMULAIRE CN', 'order': 0},
  38: {'key': 'co_form', 'attribute': 'CO-Form', 'name': 'FORMULAIRE CO', 'order': 0},
  39: {'key': 'dc_form', 'attribute': 'DC-Form', 'name': 'FORMULAIRE DC', 'order': 0},
  40: {'key': 'f_form', 'attribute': 'F-Form', 'name': 'FORMULAIRE F', 'order': 0},
  41: {'key': 'invitation', 'attribute': 'G-Form', 'name': 'INVITATIONS', 'order': 0},
  42: {'key': 'h_form', 'attribute': 'H-Form', 'name': 'FORMULAIRE H', 'order': 0},
  43: {'key': 'm_form', 'attribute': 'M-Form', 'name': 'FORMULAIRE M', 'order': 0},
  44: {'key': 'pd_form', 'attribute': 'PD-Form', 'name': 'FORMULAIRE PD', 'order': 0},
  45: {'key': 's_form', 'attribute': 'S-Form', 'name': 'FORMULAIRE S', 'order': 0},
  46: {'key': 't_form', 'attribute': 'T-Form', 'name': 'FORMULAIRE T', 'order': 0},
  47: {'key': 'to_form', 'attribute': 'TO-Form', 'name': 'FORMULAIRE TO', 'order': 0},
  48: {'key': 'assembly_hall', 'attribute': 'Assembly Hall', 'name': 'SALLE D’ASSEMBLÉE', 'order': 0},
  49: {'key': 'design_construction', 'attribute': 'Design/Construction', 'name': 'DÉVELOPPEMENT-CONSTRUCTION', 'order': 0},
  50: {'key': 'financial', 'attribute': 'Financial', 'name': 'COMPTABILITÉ', 'order': 0},
  51: {'key': 'medical', 'attribute': 'Medical', 'name': 'MÉDICAL', 'order': 0},
  52: {'key': 'ministry', 'attribute': 'Ministry', 'name': 'MINISTÈRE', 'order': 0},
  53: {'key': 'purchasing', 'attribute': 'Purchasing', 'name': 'ACHATS', 'order': 0},
  54: {'key': 'safety', 'attribute': 'Safety', 'name': 'SÉCURITÉ', 'order': 0},
  55: {'key': 'schools', 'attribute': 'Schools', 'name': 'ÉCOLES', 'order': 0},
  56: {'key': 'writing_translation', 'attribute': 'Writing/Translation', 'name': 'RÉDACTION / TRADUCTION', 'order': 0},
  57: {'key': 'meetings', 'attribute': 'Meetings', 'name': 'RÉUNIONS', 'order': 0},
};

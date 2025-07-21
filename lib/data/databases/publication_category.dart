import 'package:flutter/material.dart' show BuildContext, IconData;
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/i18n/localization.dart';

class PublicationCategory {
  static final List<PublicationCategory> _categories = [];

  final int id;
  final List<String> symbols;
  final String type;
  final String? type2;
  final IconData icon;
  final String image;
  final bool hasYears;

  PublicationCategory._({
    required this.id,
    required this.symbols,
    required this.type,
    this.type2,
    required this.icon,
    required this.image,
    required this.hasYears,
  });

  /// Initialise les catégories si ce n’est pas déjà fait
  static void initialize() {
    if (_categories.isNotEmpty) return;

    _categories.addAll([
      PublicationCategory._(id: 1, symbols: ['bi'], type: 'Bible', icon: JwIcons.bible, image: "pub_type_bible", hasYears: false),
      PublicationCategory._(id: 2, symbols: ['bk', 'gloss'], type: 'Book', type2: 'Glossary', icon: JwIcons.book_stack, image: "pub_type_book", hasYears: false),
      PublicationCategory._(id: 4, symbols: ['brch'], type: 'Brochure', type2: 'Booklet', icon: JwIcons.brochure_stack, image: "pub_type_booklet_brochure", hasYears: false),
      PublicationCategory._(id: 10, symbols: ['trct'], type: 'Tract', icon: JwIcons.tract_stack, image: "pub_type_tract", hasYears: false),
      PublicationCategory._(id: 22, symbols: ['web'], type: 'Web', icon: JwIcons.article_stack, image: "pub_type_article_series", hasYears: false),
      PublicationCategory._(id: 14, symbols: ['w'], type: 'Watchtower', icon: JwIcons.watchtower, image: "pub_type_watchtower", hasYears: true),
      PublicationCategory._(id: 13, symbols: ['g'], type: 'Awake!', icon: JwIcons.awake_exclamation_mark, image: "pub_type_awake", hasYears: true),
      PublicationCategory._(id: 30, symbols: ['mwb'], type: 'Meeting Workbook', icon: JwIcons.meeting_workbook_stack, image: "pub_type_meeting_workbook", hasYears: true),
      PublicationCategory._(id: 7, symbols: ['km'], type: 'Kingdom Ministry', icon: JwIcons.kingdom_ministry, image: "pub_type_kingdom_ministry", hasYears: true),
      PublicationCategory._(id: 31, symbols: ['pgm'], type: 'Program', icon: JwIcons.clock, image: "pub_type_program", hasYears: false),
      PublicationCategory._(id: 6, symbols: ['dx'], type: 'Index', icon: JwIcons.publications_pile, image: "pub_type_index", hasYears: false),
      PublicationCategory._(id: 0, symbols: ['talk'], type: 'Talk', icon: JwIcons.document_speaker, image: "pub_type_talk_outline", hasYears: false),
      PublicationCategory._(id: 17, symbols: ['manual'], type: 'Manual/Guidelines', icon: JwIcons.checklist, image: "pub_type_manual_guidelines", hasYears: false),
      PublicationCategory._(id: 3, symbols: ['manual'], type: 'Information Packet', icon: JwIcons.document, image: "pub_type_information_packet", hasYears: false),
      PublicationCategory._(id: 5, symbols: ['fm'], type: 'Form', icon: JwIcons.text_pencil, image: "pub_type_form", hasYears: false),
      PublicationCategory._(id: 8, symbols: ['lt'], type: 'Letter', icon: JwIcons.envelope, image: "pub_type_letter", hasYears: false),
      PublicationCategory._(id: -1, symbols: ['conv'], type: 'Convention', icon: JwIcons.arena, image: "pub_type_convention", hasYears: false),
    ]);
  }

  static List<PublicationCategory> get all => _categories;

  String getName(BuildContext context) {
    switch (type) {
      case 'Bible': return 'Bibles';
      case 'Book': return localization(context).pub_type_books;
      case 'Brochure': return localization(context).pub_type_brochures_booklets;
      case 'Tract': return localization(context).pub_type_tracts;
      case 'Web': return localization(context).pub_type_web;
      case 'Watchtower': return localization(context).pub_type_watchtower;
      case 'Awake!': return localization(context).pub_type_awake;
      case 'Meeting Workbook': return localization(context).pub_type_meeting_workbook;
      case 'Kingdom Ministry': return localization(context).pub_type_kingdom_ministry;
      case 'Program': return localization(context).pub_type_programs;
      case 'Index': return localization(context).pub_type_index;
      case 'Talk': return localization(context).pub_type_talks;
      case 'Manual/Guidelines': return localization(context).pub_type_manuals_guidelines;
      case 'Information Packet': return localization(context).pub_type_information_packets;
      case 'Form': return localization(context).pub_type_forms;
      case 'Letter': return localization(context).pub_type_letters;
      case 'Convention': return 'Nouveautés (assemblée régionale)';
      default: return '';
    }
  }
}
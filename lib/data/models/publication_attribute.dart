import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../i18n/i18n.dart';
import '../../i18n/localization.dart';

class PublicationAttribute {
  static final List<PublicationAttribute> _attributes = [];

  final int id;
  final String key;
  final String type;
  final int order;

  PublicationAttribute._({
    required this.id,
    required this.key,
    required this.type,
    required this.order,
  });

  static void initialize() {
    if (_attributes.isNotEmpty) return;

    _attributes.addAll([
      PublicationAttribute._(id: 0, key: "null", type: "", order: 0),
      PublicationAttribute._(id: 1, key: "assembly_convention", type: "Cast", order: 1),
      PublicationAttribute._(id: 2, key: "circuit_assembly", type: "Circuit Assembly", order: 1),
      PublicationAttribute._(id: 3, key: "convention", type: "Convention", order: 1),
      PublicationAttribute._(id: 4, key: "drama", type: "Drama", order: 0),
      PublicationAttribute._(id: 5, key: "dramatic_bible_reading", type: "Dramatic Bible Reading", order: 0),
      PublicationAttribute._(id: 6, key: "envelope", type: "Envelope", order: 0),
      PublicationAttribute._(id: 7, key: "examining_the_scriptures", type: "Examining the Scriptures", order: 1),
      PublicationAttribute._(id: 8, key: "insert", type: "Insert", order: 0),
      PublicationAttribute._(id: 9, key: "invitation", type: "Invitation", order: 0),
      PublicationAttribute._(id: 10, key: "kingdom_news", type: "Kingdom News", order: 0),
      PublicationAttribute._(id: 11, key: "large_print", type: "Large Print", order: 0),
      PublicationAttribute._(id: 12, key: "music", type: "Music", order: 0),
      PublicationAttribute._(id: 13, key: "ost", type: "OST", order: 0),
      PublicationAttribute._(id: 14, key: "outline", type: "Outline", order: 0),
      PublicationAttribute._(id: 15, key: "poster", type: "Poster", order: 0),
      PublicationAttribute._(id: 16, key: "public", type: "Public", order: 1),
      PublicationAttribute._(id: 17, key: "reprint", type: "Reprint", order: 0),
      PublicationAttribute._(id: 18, key: "sad", type: "SAD", order: 0),
      PublicationAttribute._(id: 19, key: "script", type: "Script", order: 0),
      PublicationAttribute._(id: 20, key: "sign_language", type: "Sign Language", order: 0),
      PublicationAttribute._(id: 21, key: "study_simplified", type: "Simplified", order: 1),
      PublicationAttribute._(id: 22, key: "study", type: "Study", order: 1),
      PublicationAttribute._(id: 23, key: "transcript", type: "Transcript", order: 0),
      PublicationAttribute._(id: 24, key: "vocal_rendition", type: "Vocal Rendition", order: 0),
      PublicationAttribute._(id: 25, key: "web", type: "Web", order: 0),
      PublicationAttribute._(id: 26, key: "yearbook", type: "Yearbook", order: 1),
      PublicationAttribute._(id: 27, key: "simplified", type: "In-house", order: 1),
      PublicationAttribute._(id: 28, key: "study_questions", type: "Study Questions", order: 0),
      PublicationAttribute._(id: 29, key: "bethel", type: "Bethel", order: 0),
      PublicationAttribute._(id: 30, key: "circuit_overseer", type: "Circuit Overseer", order: 0),
      PublicationAttribute._(id: 31, key: "congregation", type: "Congregation", order: 0),
      PublicationAttribute._(id: 32, key: "archive", type: "Archive", order: 0),
      PublicationAttribute._(id: 33, key: "congregation_circuit_overseer", type: "A-Form", order: 0),
      PublicationAttribute._(id: 34, key: "ao_form", type: "AO-Form", order: 0),
      PublicationAttribute._(id: 35, key: "b_form", type: "B-Form", order: 0),
      PublicationAttribute._(id: 36, key: "ca_form", type: "CA-Form", order: 0),
      PublicationAttribute._(id: 37, key: "cn_form", type: "CN-Form", order: 0),
      PublicationAttribute._(id: 38, key: "co_form", type: "CO-Form", order: 0),
      PublicationAttribute._(id: 39, key: "dc_form", type: "DC-Form", order: 0),
      PublicationAttribute._(id: 40, key: "f_form", type: "F-Form", order: 0),
      PublicationAttribute._(id: 41, key: "invitation", type: "G-Form", order: 0),
      PublicationAttribute._(id: 42, key: "h_form", type: "H-Form", order: 0),
      PublicationAttribute._(id: 43, key: "m_form", type: "M-Form", order: 0),
      PublicationAttribute._(id: 44, key: "pd_form", type: "PD-Form", order: 0),
      PublicationAttribute._(id: 45, key: "s_form", type: "S-Form", order: 0),
      PublicationAttribute._(id: 46, key: "t_form", type: "T-Form", order: 0),
      PublicationAttribute._(id: 47, key: "to_form", type: "TO-Form", order: 0),
      PublicationAttribute._(id: 48, key: "assembly_hall", type: "Assembly Hall", order: 0),
      PublicationAttribute._(id: 49, key: "design_construction", type: "Design/Construction", order: 0),
      PublicationAttribute._(id: 50, key: "financial", type: "Financial", order: 0),
      PublicationAttribute._(id: 51, key: "medical", type: "Medical", order: 0),
      PublicationAttribute._(id: 52, key: "ministry", type: "Ministry", order: 0),
      PublicationAttribute._(id: 53, key: "purchasing", type: "Purchasing", order: 0),
      PublicationAttribute._(id: 54, key: "safety", type: "Safety", order: 0),
      PublicationAttribute._(id: 55, key: "schools", type: "Schools", order: 0),
      PublicationAttribute._(id: 56, key: "writing_translation", type: "Writing/Translation", order: 0),
      PublicationAttribute._(id: 57, key: "meetings", type: "Meetings", order: 0),
      PublicationAttribute._(id: 58, key: "convention_invitation", type: "Convention Invitation", order: 0)
    ]);
  }

  static List<PublicationAttribute> get all => _attributes;

  Future<String> getNameAsync(Locale locale, {PublicationAttribute? attribute}) async {
    // Construit la clé de la même manière que getName()
    final String switchKey = attribute?.key != null ? '${key}_${attribute?.key}' : key;

    // Assurez-vous d'avoir accès aux localisations asynchrones (AppLocalizations)
    // NOTE: La fonction logLocaleString doit être définie ailleurs pour charger AppLocalizations.
    final AppLocalizations appLocalizations = await i18nLocale(locale);

    switch (switchKey) {
      case 'assembly_convention':
        return appLocalizations.pub_attributes_assembly_convention;
      case 'circuit_assembly':
        return appLocalizations.pub_attributes_circuit_assembly;
      case 'convention':
        return appLocalizations.pub_attributes_convention;
      case 'drama':
        return appLocalizations.pub_attributes_drama;
      case 'dramatic_bible_reading':
        return appLocalizations.pub_attributes_dramatic_bible_reading;
      case 'envelope':
        return "ENVELOPPE";
      case 'examining_the_scriptures':
        return appLocalizations.pub_attributes_examining_the_scriptures;
      case 'insert':
        return "ENCART";
      case 'convention_invitation':
        return appLocalizations.pub_attributes_convention_invitation;
      case 'invitation': // Pour G-Form
        return appLocalizations.pub_attributes_invitation;
      case 'kingdom_news':
        return appLocalizations.pub_attributes_kingdom_news;
      case 'large_print':
        return "GROS CARACTÈRES";
      case 'music':
        return appLocalizations.pub_attributes_music;
      case 'ost':
        return "BANDE ORIGINALE";
      case 'outline':
        return "PLAN";
      case 'poster':
        return "AFFICHE";
      case 'public':
        return appLocalizations.pub_attributes_public;
      case 'reprint':
        return "RÉIMPRESSION";
      case 'sad':
        return "ASSEMBLÉE SPÉCIALE";
      case 'script':
        return "SCRIPT";
      case 'sign_language':
        return "LANGUE DES SIGNES";
      case 'study_simplified':
        return appLocalizations.pub_attributes_study_simplified;
      case 'study':
        return appLocalizations.pub_attributes_study;
      case 'study_questions':
        return appLocalizations.pub_attributes_study_questions;
      case 'transcript':
        return "TRANSCRIPTION";
      case 'vocal_rendition':
        return appLocalizations.pub_attributes_vocal_rendition;
      case 'web':
        return "WEB";
      case 'yearbook':
        return appLocalizations.pub_attributes_yearbook;
      case 'simplified': // Clé pour In-house
        return appLocalizations.pub_attributes_simplified;
      case 'bethel':
        return appLocalizations.pub_attributes_bethel;
      case 'circuit_overseer':
        return appLocalizations.pub_attributes_circuit_overseer;
      case 'congregation':
        return appLocalizations.pub_attributes_congregation;
      case 'archive':
        return appLocalizations.pub_attributes_archive;
      case 'congregation_circuit_overseer': // Clé pour A-Form
        return appLocalizations.pub_attributes_congregation_circuit_overseer;
      case 'ao_form':
        return "FORMULAIRE AO";
      case 'b_form':
        return "FORMULAIRE B";
      case 'ca_form':
        return "FORMULAIRE CA";
      case 'cn_form':
        return "FORMULAIRE CN";
      case 'co_form':
        return "FORMULAIRE CO";
      case 'dc_form':
        return "FORMULAIRE DC";
      case 'f_form':
        return "FORMULAIRE F";
      case 'h_form':
        return "FORMULAIRE H";
      case 'm_form':
        return "FORMULAIRE M";
      case 'pd_form':
        return "FORMULAIRE PD";
      case 's_form':
        return "FORMULAIRE S";
      case 't_form':
        return "FORMULAIRE T";
      case 'to_form':
        return "FORMULAIRE TO";
      case 'assembly_hall':
        return "SALLE D’ASSEMBLÉE";
      case 'design_construction':
        return appLocalizations.pub_attributes_design_construction;
      case 'financial':
        return appLocalizations.pub_attributes_financial;
      case 'medical':
        return appLocalizations.pub_attributes_medical;
      case 'ministry':
        return appLocalizations.pub_attributes_ministry;
      case 'purchasing':
        return appLocalizations.pub_attributes_purchasing;
      case 'safety':
        return appLocalizations.pub_attributes_safety;
      case 'schools':
        return appLocalizations.pub_attributes_schools;
      case 'writing_translation':
        return appLocalizations.pub_attributes_writing_translation;
      case 'meetings':
        return appLocalizations.pub_attributes_meetings;
      default:
        return '';
    }
  }

  String getName() {
    switch (key) {
      case 'assembly_convention':
        return i18n().pub_attributes_assembly_convention;
      case 'circuit_assembly':
        return i18n().pub_attributes_circuit_assembly;
      case 'convention':
        return i18n().pub_attributes_convention;
      case 'drama':
        return i18n().pub_attributes_drama;
      case 'dramatic_bible_reading':
        return i18n().pub_attributes_dramatic_bible_reading;
      case 'envelope':
        return "ENVELOPPE";
      case 'examining_the_scriptures':
        return i18n().pub_attributes_examining_the_scriptures;
      case 'insert':
        return "ENCART";
      case 'convention_invitation':
        return i18n().pub_attributes_convention_invitation;
      case 'invitation': // Pour G-Form
        return i18n().pub_attributes_invitation;
      case 'kingdom_news':
        return i18n().pub_attributes_kingdom_news;
      case 'large_print':
        return "GROS CARACTÈRES";
      case 'music':
        return i18n().pub_attributes_music;
      case 'ost':
        return "BANDE ORIGINALE";
      case 'outline':
        return "PLAN";
      case 'poster':
        return "AFFICHE";
      case 'public':
        return i18n().pub_attributes_public;
      case 'reprint':
        return "RÉIMPRESSION";
      case 'sad':
        return "ASSEMBLÉE SPÉCIALE";
      case 'script':
        return "SCRIPT";
      case 'sign_language':
        return "LANGUE DES SIGNES";
      case 'study_simplified':
        return i18n().pub_attributes_study_simplified;
      case 'study':
        return i18n().pub_attributes_study;
      case 'study_questions':
        return i18n().pub_attributes_study_questions;
      case 'transcript':
        return "TRANSCRIPTION";
      case 'vocal_rendition':
        return i18n().pub_attributes_vocal_rendition;
      case 'web':
        return "WEB";
      case 'yearbook':
        return i18n().pub_attributes_yearbook;
      case 'simplified': // Clé pour In-house
        return i18n().pub_attributes_simplified;
      case 'bethel':
        return i18n().pub_attributes_bethel;
      case 'circuit_overseer':
        return i18n().pub_attributes_circuit_overseer;
      case 'congregation':
        return i18n().pub_attributes_congregation;
      case 'archive':
        return i18n().pub_attributes_archive;
      case 'congregation_circuit_overseer': // Clé pour A-Form
        return i18n().pub_attributes_congregation_circuit_overseer;
      case 'ao_form':
        return "FORMULAIRE AO";
      case 'b_form':
        return "FORMULAIRE B";
      case 'ca_form':
        return "FORMULAIRE CA";
      case 'cn_form':
        return "FORMULAIRE CN";
      case 'co_form':
        return "FORMULAIRE CO";
      case 'dc_form':
        return "FORMULAIRE DC";
      case 'f_form':
        return "FORMULAIRE F";
      case 'h_form':
        return "FORMULAIRE H";
      case 'm_form':
        return "FORMULAIRE M";
      case 'pd_form':
        return "FORMULAIRE PD";
      case 's_form':
        return "FORMULAIRE S";
      case 't_form':
        return "FORMULAIRE T";
      case 'to_form':
        return "FORMULAIRE TO";
      case 'assembly_hall':
        return "SALLE D’ASSEMBLÉE";
      case 'design_construction':
        return i18n().pub_attributes_design_construction;
      case 'financial':
        return i18n().pub_attributes_financial;
      case 'medical':
        return i18n().pub_attributes_medical;
      case 'ministry':
        return i18n().pub_attributes_ministry;
      case 'purchasing':
        return i18n().pub_attributes_purchasing;
      case 'safety':
        return i18n().pub_attributes_safety;
      case 'schools':
        return i18n().pub_attributes_schools;
      case 'writing_translation':
        return i18n().pub_attributes_writing_translation;
      case 'meetings':
        return i18n().pub_attributes_meetings;
      default:
        return '';
    }
  }

  static PublicationAttribute? getAttributeById(int id) {
    return _attributes.firstWhereOrNull((attr) => attr.id == id);
  }

  static PublicationAttribute? getAttributeByType(String type) {
    return _attributes.firstWhereOrNull((attr) => attr.type == type);
  }

  static PublicationAttribute? getAttributeByKey(String key) {
    return _attributes.firstWhereOrNull((attr) => attr.key == key);
  }
}

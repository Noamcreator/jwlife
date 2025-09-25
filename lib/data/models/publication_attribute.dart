import 'package:collection/collection.dart';

class PublicationAttribute {
  static final List<PublicationAttribute> _attributes = [];

  final int id;
  final String key;
  final String type;
  final String name;
  final int order;

  PublicationAttribute._({
    required this.id,
    required this.key,
    required this.type,
    required this.name,
    required this.order,
  });

  static void initialize() {
    if (_attributes.isNotEmpty) return;

    _attributes.addAll([
      PublicationAttribute._(id: 0, key: "null", type: "", name: "", order: 0),
      PublicationAttribute._(id: 1, key: "assembly_convention", type: "Cast", name: "ASSEMBLÉE RÉGIONALE ET DE CIRCONSCRIPTION", order: 1),
      PublicationAttribute._(id: 2, key: "circuit_assembly", type: "Circuit Assembly", name: "ASSEMBLÉE DE CIRCONSCRIPTION", order: 1),
      PublicationAttribute._(id: 3, key: "convention", type: "Convention", name: "ASSEMBLÉE RÉGIONALE", order: 1),
      PublicationAttribute._(id: 4, key: "drama", type: "Drama", name: "REPRÉSENTATIONS THÉÂTRALES", order: 0),
      PublicationAttribute._(id: 5, key: "dramatic_bible_reading", type: "Dramatic Bible Reading", name: "LECTURES BIBLIQUES THÉÂTRALES", order: 0),
      PublicationAttribute._(id: 6, key: "envelope", type: "Envelope", name: "ENVELOPPE", order: 0),
      PublicationAttribute._(id: 7, key: "examining_the_scriptures", type: "Examining the Scriptures", name: "EXAMINONS LES ÉCRITURES", order: 1),
      PublicationAttribute._(id: 8, key: "insert", type: "Insert", name: "ENCART", order: 0),
      PublicationAttribute._(id: 9, key: "convention_invitation", type: "Invitation", name: "INVITATIONS À L'ASSEMBLÉE RÉGIONALE", order: 0),
      PublicationAttribute._(id: 10, key: "kingdom_news", type: "Kingdom News", name: "NOUVELLES DU ROYAUME", order: 0),
      PublicationAttribute._(id: 11, key: "large_print", type: "Large Print", name: "GROS CARACTÈRES", order: 0),
      PublicationAttribute._(id: 12, key: "music", type: "Music", name: "MUSIQUE", order: 0),
      PublicationAttribute._(id: 13, key: "ost", type: "OST", name: "BANDE ORIGINALE", order: 0),
      PublicationAttribute._(id: 14, key: "outline", type: "Outline", name: "PLAN", order: 0),
      PublicationAttribute._(id: 15, key: "poster", type: "Poster", name: "AFFICHE", order: 0),
      PublicationAttribute._(id: 16, key: "public", type: "Public", name: "ÉDITION PUBLIQUE", order: 1),
      PublicationAttribute._(id: 17, key: "reprint", type: "Reprint", name: "RÉIMPRESSION", order: 0),
      PublicationAttribute._(id: 18, key: "sad", type: "SAD", name: "ASSEMBLÉE SPÉCIALE", order: 0),
      PublicationAttribute._(id: 19, key: "script", type: "Script", name: "SCRIPT", order: 0),
      PublicationAttribute._(id: 20, key: "sign_language", type: "Sign Language", name: "LANGUE DES SIGNES", order: 0),
      PublicationAttribute._(id: 21, key: "study_simplified", type: "Simplified", name: "ÉDITION D’ÉTUDE (FACILE)", order: 1),
      PublicationAttribute._(id: 22, key: "study", type: "Study", name: "ÉDITION D’ÉTUDE", order: 1),
      PublicationAttribute._(id: 23, key: "transcript", type: "Transcript", name: "TRANSCRIPTION", order: 0),
      PublicationAttribute._(id: 24, key: "vocal_rendition", type: "Vocal Rendition", name: "VERSION CHANTÉE", order: 0),
      PublicationAttribute._(id: 25, key: "web", type: "Web", name: "WEB", order: 0),
      PublicationAttribute._(id: 26, key: "yearbook", type: "Yearbook", name: "ANNUAIRES ET RAPPORTS DES ANNÉES DE SERVICE", order: 1),
      PublicationAttribute._(id: 27, key: "simplified", type: "In-house", name: "VERSION FACILE", order: 1),
      PublicationAttribute._(id: 28, key: "study_questions", type: "Study Questions", name: "QUESTIONS D'ÉTUDE", order: 0),
      PublicationAttribute._(id: 29, key: "bethel", type: "Bethel", name: "BÉTHEL", order: 0),
      PublicationAttribute._(id: 30, key: "circuit_overseer", type: "Circuit Overseer", name: "RESPONSABLE DE CIRCONSCRIPTION", order: 0),
      PublicationAttribute._(id: 31, key: "congregation", type: "Congregation", name: "ASSEMBLÉE LOCALE", order: 0),
      PublicationAttribute._(id: 32, key: "archive", type: "Archive", name: "PUBLICATIONS PLUS ANCIENNES", order: 0),
      PublicationAttribute._(id: 33, key: "congregation_circuit_overseer", type: "A-Form", name: "ASSEMBLÉE LOCALE ET RESPONSABLE DE CIRCONSCRIPTION", order: 0),
      PublicationAttribute._(id: 34, key: "ao_form", type: "AO-Form", name: "FORMULAIRE AO", order: 0),
      PublicationAttribute._(id: 35, key: "b_form", type: "B-Form", name: "FORMULAIRE B", order: 0),
      PublicationAttribute._(id: 36, key: "ca_form", type: "CA-Form", name: "FORMULAIRE CA", order: 0),
      PublicationAttribute._(id: 37, key: "cn_form", type: "CN-Form", name: "FORMULAIRE CN", order: 0),
      PublicationAttribute._(id: 38, key: "co_form", type: "CO-Form", name: "FORMULAIRE CO", order: 0),
      PublicationAttribute._(id: 39, key: "dc_form", type: "DC-Form", name: "FORMULAIRE DC", order: 0),
      PublicationAttribute._(id: 40, key: "f_form", type: "F-Form", name: "FORMULAIRE F", order: 0),
      PublicationAttribute._(id: 41, key: "invitation", type: "G-Form", name: "INVITATIONS", order: 0),
      PublicationAttribute._(id: 42, key: "h_form", type: "H-Form", name: "FORMULAIRE H", order: 0),
      PublicationAttribute._(id: 43, key: "m_form", type: "M-Form", name: "FORMULAIRE M", order: 0),
      PublicationAttribute._(id: 44, key: "pd_form", type: "PD-Form", name: "FORMULAIRE PD", order: 0),
      PublicationAttribute._(id: 45, key: "s_form", type: "S-Form", name: "FORMULAIRE S", order: 0),
      PublicationAttribute._(id: 46, key: "t_form", type: "T-Form", name: "FORMULAIRE T", order: 0),
      PublicationAttribute._(id: 47, key: "to_form", type: "TO-Form", name: "FORMULAIRE TO", order: 0),
      PublicationAttribute._(id: 48, key: "assembly_hall", type: "Assembly Hall", name: "SALLE D’ASSEMBLÉE", order: 0),
      PublicationAttribute._(id: 49, key: "design_construction", type: "Design/Construction", name: "DÉVELOPPEMENT-CONSTRUCTION", order: 0),
      PublicationAttribute._(id: 50, key: "financial", type: "Financial", name: "COMPTABILITÉ", order: 0),
      PublicationAttribute._(id: 51, key: "medical", type: "Medical", name: "MÉDICAL", order: 0),
      PublicationAttribute._(id: 52, key: "ministry", type: "Ministry", name: "MINISTÈRE", order: 0),
      PublicationAttribute._(id: 53, key: "purchasing", type: "Purchasing", name: "ACHATS", order: 0),
      PublicationAttribute._(id: 54, key: "safety", type: "Safety", name: "SÉCURITÉ", order: 0),
      PublicationAttribute._(id: 55, key: "schools", type: "Schools", name: "ÉCOLES", order: 0),
      PublicationAttribute._(id: 56, key: "writing_translation", type: "Writing/Translation", name: "RÉDACTION / TRADUCTION", order: 0),
      PublicationAttribute._(id: 57, key: "meetings", type: "Meetings", name: "RÉUNIONS", order: 0)
    ]);
  }

  static List<PublicationAttribute> get all => _attributes;

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

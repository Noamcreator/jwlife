import '../constants.dart';

class JwOrgUri {
  static JwOrgUri? startUri; // ← rendre static

  final String wtlocale; // ex: F
  final String? pub;     // ex: lff
  final int? issue;      // ex: 202510
  final int? docid;      // ex: 102025003
  final String? par;        // ex: 2
  final int? book;
  final String? bible;
  final String? lank;
  final String? ts;
  final String? alias;   // ex: daily-text / meetings
  final String? date;    // ex: 20250814
  final String? srcid;   // ex: jwlshare

  JwOrgUri({
    required this.wtlocale,
    this.pub,
    this.issue,
    this.docid,
    this.par,
    this.book,
    this.bible,
    this.lank,
    this.ts,
    this.alias,
    this.date,
    this.srcid,
  });

  /// Normalise vers 8 chiffres (ex: 202510 → 20251000)
  static int _expandIssue(String? raw) {
    if (raw == null || raw.isEmpty) return 0;

    // Étape 1 : Nettoyer la chaîne. On retire tous les caractères non numériques,
    // ce qui gère '1983-12-15' -> '19831215'
    String cleanRaw = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanRaw.isEmpty) return 0;

    if (cleanRaw.length < 8) {
      // Étape 2 : Si la chaîne nettoyée est courte (ex: "202510"), on pad.
      // Résultat : 20251000
      return int.parse(cleanRaw.padRight(8, '0'));
    }

    // Étape 3 (Correction Logique) : Si la chaîne nettoyée a 8 chiffres ou plus
    // (ex: "19831215"), on prend les 8 premiers pour le parsing.
    // **NOTE** : Votre code original retournait 0 ici. Cette correction
    // suppose que vous voulez parsez la date si elle est complète.
    try {
      return int.parse(cleanRaw.substring(0, 8));
    } catch (e) {
      // En cas d'erreur de parsing (très peu probable ici), on retourne 0
      return 0;
    }
  }

  /// Réduit si fin "00" (ex: 20251000 → 202510), ou null si 0
  static int? _shrinkIssue(int? value) {
    if (value == null || value == 0) return null;
    if (value % 100 == 0) {
      return value ~/ 100;
    }
    return value;
  }

  static Duration? parseDuration(String value) {
    // On sépare d'abord les millisecondes (après le point) du reste
    final timeParts = value.split('.');
    int milliseconds = 0;

    if (timeParts.length > 1) {
      // On prend les millisecondes et on s'assure qu'elles sont sur 3 chiffres si besoin
      final msString = timeParts[1].padRight(3, '0').substring(0, 3);
      milliseconds = int.tryParse(msString) ?? 0;
    }

    // On traite les H:M:S normalement
    final hms = timeParts[0].split(':').map(int.tryParse).toList();
    
    if (hms.length == 3 && hms.every((e) => e != null)) {
      return Duration(
        hours: hms[0]!,
        minutes: hms[1]!,
        seconds: hms[2]!,
        milliseconds: milliseconds,
      );
    }
    return null;
  }

  /// Analyse un lien JW.org
  factory JwOrgUri.parse(String url) {
    final uri = Uri.parse(url);

    if (uri.host != 'www.jw.org' || uri.path != '/finder') {
      throw FormatException("URL invalide, attendu https://www.jw.org/finder");
    }

    final qp = uri.queryParameters;

    return JwOrgUri(
      wtlocale: qp['wtlocale'] ?? '',
      pub: qp['pub'],
      issue: _expandIssue(qp['issue']),
      docid: int.tryParse(qp['docid'] ?? ''),
      par: qp['par'],
      book: int.tryParse(qp['book'] ?? ''),
      bible: qp['bible'],
      lank: qp['lank'],
      ts: qp['ts'],
      alias: qp['alias'],
      date: qp['date'],
      srcid: qp['srcid'],
    );
  }

  /// Création depuis une publication
  factory JwOrgUri.publication({
    required String wtlocale,
    required String pub,
    int? issue,
    String srcid = Constants.jwlifeShare,
  }) {
    return JwOrgUri(
      wtlocale: wtlocale,
      pub: pub,
      issue: _shrinkIssue(issue),
      srcid: srcid,
    );
  }

  /// Création depuis un document
  factory JwOrgUri.document({
    required String wtlocale,
    required int docid,
    String? par,
    String srcid = Constants.jwlifeShare,
  }) {
    return JwOrgUri(
      wtlocale: wtlocale,
      docid: docid,
      par: par,
      srcid: srcid,
    );
  }

  factory JwOrgUri.bibleBook({
    required String wtlocale,
    required String pub,
    required int book,
    String srcid = Constants.jwlifeShare,
  }) {
    return JwOrgUri(
      wtlocale: wtlocale,
      pub: pub,
      book: book,
      srcid: srcid,
    );
  }

  factory JwOrgUri.bibleChapter({
    required String wtlocale,
    required String pub,
    required String bible,
    String srcid = Constants.jwlifeShare,
  }) {
    return JwOrgUri(
      wtlocale: wtlocale,
      pub: pub,
      bible: bible,
      srcid: srcid,
    );
  }

  factory JwOrgUri.mediaItem({
    required String wtlocale,
    required String lank,
    String? ts,
    String srcid = Constants.jwlifeShare,
  }) {
    return JwOrgUri(
      wtlocale: wtlocale,
      lank: lank,
      ts: ts,
      srcid: srcid,
    );
  }

  /// Création depuis le texte du jour
  factory JwOrgUri.dailyText({
    required String wtlocale,
    required String date,
    String srcid = Constants.jwlifeShare,
  }) {
    return JwOrgUri(
      wtlocale: wtlocale,
      alias: 'daily-text',
      date: date,
      srcid: srcid,
    );
  }

  /// Création depuis les réunions
  factory JwOrgUri.meetings({
    required String wtlocale,
    required String date,
    String srcid = Constants.jwlifeShare,
  }) {
    return JwOrgUri(
      wtlocale: wtlocale,
      alias: 'meetings',
      date: date,
      srcid: srcid,
    );
  }

  /// Helpers
  bool get isPublication => pub != null && alias == null && docid == null && book == null && bible == null;
  bool get isDocument => docid != null && alias == null && bible == null && book == null;
  bool get isBibleBook => book != null && bible == null && alias == null && docid == null;
  bool get isBibleChapter => bible != null && alias == null && docid == null && book == null;
  bool get isMediaItem => lank != null && alias == null;
  bool get isDailyText => alias == 'daily-text';
  bool get isMeetings => alias == 'meetings';

  /// Génération d'un lien complet
  @override
  String toString() {
    final qp = {
      if (srcid != null) 'srcid': srcid,
      'wtlocale': wtlocale,
      if (bible != null) 'bible': bible,
      if (pub != null) 'pub': pub,
      if (issue != null) 'issue': issue.toString(),
      if (docid != null) 'docid': docid.toString(),
      if (par != null) 'par': par,
      if (book != null) 'book': book.toString(),
      if (lank != null) 'lank': lank,
      if (ts != null) 'ts': ts,
      if (alias != null) 'alias': alias,
      if (date != null) 'date': date,
    };

    return Uri(
      scheme: 'https',
      host: 'www.jw.org',
      path: '/finder',
      queryParameters: qp,
    ).toString();
  }
}

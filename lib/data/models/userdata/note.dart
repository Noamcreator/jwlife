import 'package:flutter/material.dart';
import 'package:jwlife/data/models/userdata/location.dart';

class Note {
  int noteId;
  String guid;
  String? title;
  String? content;
  String? lastModified;
  String? created;
  int blockType;
  int? blockIdentifier;
  int colorIndex;
  int? userMarkId;
  String? userMarkGuid;
  Location location;
  List<int> tagsId;

  Note({
    required this.noteId,
    required this.guid,
    this.title,
    this.content,
    this.lastModified,
    this.created,
    required this.blockType,
    this.blockIdentifier,
    required this.colorIndex,
    this.userMarkId,
    this.userMarkGuid,
    required this.location,
    required this.tagsId,
  });

  /// Retourne une couleur selon l'index et le thème (clair/sombre)
  Color getColor(BuildContext context, {int? colorId}) {
    switch (colorId ?? colorIndex % 9) {
      case 0:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Color(0xFFf1f1f1);
      case 1:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF49400e) : Color(0xFFfffce6);
      case 2:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF233315) : Color(0xFFeffbe6);
      case 3:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF203646) : Color(0xFFe6f7ff);
      case 4:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF401f2c) : Color(0xFFffe6f0);
      case 5:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF49290e) : Color(0xFFfff0e6);
      case 6:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF2d2438) : Color(0xFFf1eafa);
      case 7:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF441A1B) : Color(0xFFFED6D6);
      case 8:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF382B18) : Color(0xFFF1E0CE);
      default:
        return Theme.of(context).brightness == Brightness.dark ? Color(0xFF292929) : Color(0xFFf1f1f1);
    }
  }

  /// Créé une instance Note à partir d'une map (ex: JSON)
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      noteId: map['NoteId'],
      guid: map['Guid'],
      title: map['Title'],
      content: map['Content'],
      lastModified: map['LastModified'],
      created: map['Created'],
      blockType: map['BlockType'],
      blockIdentifier: map['BlockIdentifier'],
      colorIndex: map['ColorIndex'] ?? 0,
      userMarkId: map['UserMarkId'],
      userMarkGuid: map['UserMarkGuid'],
      location: Location.fromMap(map),
      tagsId: map['TagsId'] == null
          ? [] // Si la clé est absente ou nulle, retourne une liste vide.
          : (map['TagsId'] is List<int>)
          ? map['TagsId'] // Si c'est déjà une List<int>, on la garde.
          : (map['TagsId'] is String)
          ? (map['TagsId'] as String) // On s'assure que c'est bien une chaîne.
          .split(',')
          .map((e) => int.tryParse(e.trim())) // Tente de convertir chaque partie en int.
          .where((e) => e != null) // Filtre les null (ceux qui n'ont pas pu être convertis).
          .cast<int>()
          .toList()
          : [], // Dans tout autre cas (par exemple, si c'est un seul int, bool, etc.), retourne une liste vide.
    );
  }

  String getRelativeTime() {
    String? dateStr = lastModified ?? created;
    if (dateStr == null || dateStr.isEmpty) return '';

    DateTime date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {
      return lastModified ?? ''; // date invalide
    }

    Duration diff = DateTime.now().difference(date);
    if (diff.isNegative) {
      return 'à l\'instant · ${_formatDate(date)}';
    }

    String relative;
    if (diff.inSeconds < 60) {
      int s = diff.inSeconds;
      relative = 'il y a $s seconde${s > 1 ? 's' : ''}';
    } else if (diff.inMinutes < 60) {
      int m = diff.inMinutes;
      relative = 'il y a $m minute${m > 1 ? 's' : ''}';
    } else if (diff.inHours < 24) {
      int h = diff.inHours;
      relative = 'il y a $h heure${h > 1 ? 's' : ''}';
    } else if (diff.inDays < 30) {
      int j = diff.inDays;
      relative = 'il y a $j jour${j > 1 ? 's' : ''}';
    } else if (diff.inDays < 365) {
      int mois = (diff.inDays / 30).floor();
      relative = 'il y a $mois mois';
    } else {
      int annee = (diff.inDays / 365).floor();
      relative = 'il y a $annee an${annee > 1 ? 's' : ''}';
    }

    return '$relative · ${_formatDate(date)}';
  }

// Fonction utilitaire pour formater la date en jj/mm/aaaa
  String _formatDate(DateTime date) {
    String jour = date.day.toString().padLeft(2, '0');
    String mois = date.month.toString().padLeft(2, '0');
    String annee = date.year.toString();
    return '$jour/$mois/$annee';
  }
}

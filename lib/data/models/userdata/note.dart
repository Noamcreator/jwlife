import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/userdata/location.dart';

import '../../../app/services/global_key_service.dart';

class Note {
  String guid;
  String? title;
  String? content;
  String? lastModified;
  String? created;
  int blockType;
  int? blockIdentifier;
  int colorIndex;
  String? userMarkGuid;
  Location location;
  List<int> tagsId;

  Note({
    required this.guid,
    this.title,
    this.content,
    this.lastModified,
    this.created,
    required this.blockType,
    this.blockIdentifier,
    required this.colorIndex,
    this.userMarkGuid,
    required this.location,
    required this.tagsId,
  });

  /// Retourne une couleur selon l'index et le thème (clair/sombre)
  Color getColor(BuildContext context, {int? colorId}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (colorId ?? colorIndex % 9) {
      case 0:
        return isDark ? Color(0xFF292929) : Color(0xFFf1f1f1);
      case 1:
        return isDark ? Color(0xFF49400e) : Color(0xFFfffce6);
      case 2:
        return isDark ? Color(0xFF233315) : Color(0xFFeffbe6);
      case 3:
        return isDark ? Color(0xFF203646) : Color(0xFFe6f7ff);
      case 4:
        return isDark ? Color(0xFF401f2c) : Color(0xFFffe6f0);
      case 5:
        return isDark ? Color(0xFF49290e) : Color(0xFFfff0e6);
      case 6:
        return isDark ? Color(0xFF2d2438) : Color(0xFFf1eafa);
      case 7:
        return isDark ? Color(0xFF441A1B) : Color(0xFFFED6D6);
      case 8:
        return isDark ? Color(0xFF382B18) : Color(0xFFF1E0CE);
      default:
        return isDark ? Color(0xFF292929) : Color(0xFFf1f1f1);
    }
  }

  Color getIndicatorColor(BuildContext context, {int? colorId}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    switch (colorId ?? colorIndex % 9) {
      case 0:
        return isDark ? Color(0xFF626262) : Color(0xFFC0C0C0);
      case 1:
        return isDark ? Color(0xFFE9C600) : Color(0xFFFFF37A);
      case 2:
        return isDark ? Color(0xFF66A333) : Color(0xFFB7E492);
      case 3:
        return isDark ? Color(0xFF4AA1DD) : Color(0xFF98D8FF);
      case 4:
        return isDark ? Color(0xFFC64677) : Color(0xFFF698BC);
      case 5:
        return isDark ? Color(0xFFE96D00) : Color(0xFFFFBA8A);
      case 6:
        return isDark ? Color(0xFF7B57A7) : Color(0xFFC1A7E2);
      case 7:
        return isDark ? Color.fromARGB(255, 134, 27, 29) : Color.fromARGB(255, 185, 94, 94);
      case 8:
        return isDark ? Color.fromARGB(255, 68, 51, 25) : Color.fromARGB(255, 146, 113, 79);
      default:
        return isDark ? Color(0xFF626262) : Color(0xFFC0C0C0);
    }
  }

  /// Créé une instance Note à partir d'une map (ex: JSON)
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      guid: map['Guid'],
      title: map['Title'],
      content: map['Content'],
      lastModified: map['LastModified'],
      created: map['Created'],
      blockType: map['BlockType'],
      blockIdentifier: map['BlockIdentifier'],
      colorIndex: map['ColorIndex'] ?? 0,
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

  /// Convertit l'instance Note en une map (ex: JSON)
  Map<String, dynamic> toMap() {
    return {
      'Guid': guid,
      'Title': title,
      'Content': content,
      'LastModified': lastModified,
      'Created': created,
      'BlockType': blockType,
      'BlockIdentifier': blockIdentifier,
      'ColorIndex': colorIndex,
      'UserMarkGuid': userMarkGuid,
      'Location': location.toMap(),
      'TagsId': tagsId.join(','),
    };
  }

  Note copyWith({
    String? guid,
    String? title,
    String? content,
    String? lastModified,
    String? created,
    int? blockType,
    int? blockIdentifier,
    int? colorIndex,
    String? userMarkGuid,
    Location? location,
    List<int>? tagsId,
  }) {
    return Note(
      guid: guid ?? this.guid,
      title: title ?? this.title,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      created: created ?? this.created,
      blockType: blockType ?? this.blockType,
      blockIdentifier: blockIdentifier ?? this.blockIdentifier,
      colorIndex: colorIndex ?? this.colorIndex,
      userMarkGuid: userMarkGuid ?? this.userMarkGuid,
      location: location ?? this.location,
      tagsId: tagsId ?? List.from(this.tagsId),
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

    String relative = timeAgo(date);

    return '$relative · ${_formatDate(date)}';
  }

  // Fonction utilitaire pour formater la date en jj/mm/aaaa
  String _formatDate(DateTime date) {
    BuildContext context = GlobalKeyService.jwLifePageKey.currentContext!;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).format(date);
  }

  void addTagId(int tagId) {
    if (!tagsId.contains(tagId)) {
      tagsId.add(tagId);
    }
  }

  void removeTagId(int tagId) {
    if (tagsId.contains(tagId)) {
      tagsId.remove(tagId);
    }
  }
}

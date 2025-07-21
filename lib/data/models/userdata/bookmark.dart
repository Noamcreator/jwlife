import 'location.dart';

class Bookmark {
  final int slot;
  final String title;
  final String snippet;
  final int blockType;
  final int? blockIdentifier;
  final Location location;

  Bookmark({
    required this.slot,
    required this.title,
    required this.snippet,
    required this.blockType,
    this.blockIdentifier,
    required this.location,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      slot: map['Slot'] ?? 0,
      title: map['Title'] ?? '',
      snippet: map['Snippet'] ?? '',
      blockType: map['BlockType'] ?? 1,
      blockIdentifier: map['BlockIdentifier'],
      location: Location.fromMap(map),
    );
  }
}

import 'package:jwlife/data/models/userdata/location.dart';

class BlockRange {
  String userMarkGuid;
  int blockType;
  int identifier;
  int startToken;
  int endToken;
  int colorIndex;
  int styleIndex;
  int version;
  Location location;

  BlockRange({
    required this.userMarkGuid,
    required this.blockType,
    required this.identifier,
    required this.startToken,
    required this.endToken,
    required this.colorIndex,
    required this.styleIndex,
    this.version = 1,
    required this.location,
  });

  /// Créé une instance de BlockRange à partir d'une map
  factory BlockRange.fromMap(Map<String, dynamic> map) {
    return BlockRange(
      userMarkGuid: map['UserMarkGuid'],
      blockType: map['BlockType'],
      identifier: map['Identifier'],
      startToken: map['StartToken'],
      endToken: map['EndToken'],
      colorIndex: map['ColorIndex'],
      styleIndex: map['StyleIndex'],
      version: map['Version'],
      location: Location.fromMap(map),
    );
  }

  /// Convertit l'instance de BlockRange en map
  Map<String, dynamic> toMap() {
    return {
      'UserMarkGuid': userMarkGuid,
      'BlockType': blockType,
      'Identifier': identifier,
      'StartToken': startToken,
      'EndToken': endToken,
      'ColorIndex': colorIndex,
      'StyleIndex': styleIndex,
      'Version': version
    };
  }

  BlockRange copyWith({
    String? userMarkGuid,
    int? blockType,
    int? identifier,
    int? startToken,
    int? endToken,
    int? colorIndex,
    int? styleIndex,
    int? version,
    Location? location,
  }) {
    return BlockRange(
      userMarkGuid: userMarkGuid ?? this.userMarkGuid,
      blockType: blockType ?? this.blockType,
      identifier: identifier ?? this.identifier,
      startToken: startToken ?? this.startToken,
      endToken: endToken ?? this.endToken,
      colorIndex: colorIndex ?? this.colorIndex,
      styleIndex: styleIndex ?? this.styleIndex,
      version: version ?? this.version,
      location: location ?? this.location,
    );
  }
}

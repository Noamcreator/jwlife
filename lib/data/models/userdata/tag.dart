class Tag {
  final int id;
  final int type;
  final String name;

  Tag({
    required this.id,
    required this.type,
    required this.name,
  });

  factory Tag.fromMap(Map<String, dynamic> map, {int? type}) {
    return Tag(
      id: map['TagId'],
      type: map['Type'] ?? type,
      name: map['Name'],
    );
  }
}

import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/data/models/userdata/location.dart';

class InputField {
  String textTag;
  String? content;
  Location location;

  InputField({
    required this.textTag,
    this.content,
    required this.location,
  });

  /// Créé une instance InputField à partir d'une map (ex: JSON)
  factory InputField.fromMap(Map<String, dynamic> map) {
    // 1. Créer une copie mutable de la map.
    final mutableMap = Map<String, dynamic>.from(map);

    mutableMap['MepsLanguage'] = JwLifeSettings.instance.currentLanguage.value.id;

    return InputField(
      textTag: mutableMap['TextTag'],
      content: mutableMap['Value'],
      location: Location.fromMap(mutableMap),
    );
  }
}
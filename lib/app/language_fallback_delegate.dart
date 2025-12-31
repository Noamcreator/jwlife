import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FallbackLocalizationDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  @override
  bool isSupported(Locale locale) => true; // On accepte tout, même 'ay'

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // Si la langue est 'ay', on charge l'espagnol (es) ou l'anglais (en) comme secours
    return await GlobalMaterialLocalizations.delegate.load(const Locale('es'));
  }

  @override
  bool shouldReload(FallbackLocalizationDelegate old) => false;
}
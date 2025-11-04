import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'app_localizations.dart';

AppLocalizations localization(BuildContext context) {
  return AppLocalizations.of(context)!;
}

AppLocalizations loc() {
  BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.context;
  return AppLocalizations.of(context)!;
}

// Classe de service (sans widget)
class LocalizationService {
  // Note: Ceci doit être un Future car le chargement est asynchrone
  static Future<AppLocalizations> getLocalizationsFor(Locale locale) async {
    // Appelle directement le délégué pour charger la locale souhaitée
    return AppLocalizations.delegate.load(locale);
  }
}

// Exemple : Utilisation dans une classe de service/modèle
Future<AppLocalizations> logLocaleString(Locale locale) async {
  // Ici, on force l'allemand ('de')
  final localization = await AppLocalizations.delegate.load(locale);
  return localization;
}
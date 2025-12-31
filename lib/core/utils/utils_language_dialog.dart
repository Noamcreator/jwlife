import 'package:flutter/material.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/dialog/languages_app_dialog.dart';

import '../../widgets/dialog/language_dialog.dart';

Future<dynamic> showLanguageDialog(BuildContext context, {String? firstSelectedLanguage, Map<String, dynamic> languagesListJson = const {}, Media? media}) async {
  LanguageDialog languageDialog = LanguageDialog(selectedLanguageSymbol: firstSelectedLanguage, languagesListJson: languagesListJson, media: media);
  return await showDialog(
    context: context,
    builder: (context) => languageDialog
  );
}

Future<Publication?> showLanguagePubDialog(BuildContext context, Publication? publication) async {
  LanguagesPubDialog languagePubDialog = LanguagesPubDialog(publication: publication);
  return await showDialog(
      context: context,
      builder: (context) => languagePubDialog
  );
}

Future<Map<String, dynamic>?> showLanguagesAppDialog(BuildContext context) async {
  LanguagesAppDialog languagesAppDialog = LanguagesAppDialog();
  return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => languagesAppDialog
  );
}
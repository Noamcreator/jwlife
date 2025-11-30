import 'package:flutter/material.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';

import '../../widgets/dialog/language_dialog.dart';

Future<dynamic> showLanguageDialog(BuildContext context, {String? selectedLanguageSymbol, Map<String, dynamic> languagesListJson = const {}, Media? media}) async {
  LanguageDialog languageDialog = LanguageDialog(selectedLanguageSymbol: selectedLanguageSymbol, languagesListJson: languagesListJson, media: media);
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
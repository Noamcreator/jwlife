
// Fonction pour mettre la première lettre en majuscule
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../jwlife.dart';
import 'files_helper.dart';

String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

String formatDuration(double duration) {
  // Convertir la durée en secondes
  int totalSeconds = duration.toInt(); // Supposons que 'duration' est en secondes

  // Calculer les heures, minutes et secondes
  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int seconds = totalSeconds % 60;

  // Formater les secondes pour avoir deux chiffres
  String formattedSeconds = seconds.toString().padLeft(2, '0');
  String formattedMinutes = minutes.toString().padLeft(2, '0');

  // Retourner la durée formatée avec ou sans les heures
  if (hours > 0) {
    return '$hours:$formattedMinutes:$formattedSeconds';
  } else {
    return '$minutes:$formattedSeconds';
  }
}

String convertHtmlToText(String html) {
  return html == '' ? '' : html.replaceAll(RegExp(r"<[^>]*>"), '').trim();
}

bool isPortrait(BuildContext context) {
  return MediaQuery.of(context).orientation == Orientation.portrait;
}

Future<Map<String, dynamic>?> searchPub(String pub) async {
  File catalogFile = await getCatalogFile();
  File mepsFile = await getMepsFile();

  if (await catalogFile.exists() && await mepsFile.exists()) {
    // Ouvrir la base de données catalogue et attacher la base de données meps
    Database catalog = await openDatabase(catalogFile.path);
    await catalog.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");

    // Exécuter la requête SQL pour récupérer les publications et leurs images associées
    List<Map<String, dynamic>> publications = await catalog.rawQuery('''
      SELECT
        p.Id AS PublicationId,
        p.MepsLanguageId,
        meps.Language.Symbol AS LanguageSymbol,
        p.PublicationTypeId,
        p.IssueTagNumber,
        p.Title,
        p.IssueTitle,
        p.ShortTitle,
        p.CoverTitle,
        p.KeySymbol,
        p.Symbol,
        (SELECT ia.NameFragment
          FROM ImageAsset ia
          JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
          WHERE paim.PublicationAssetId = pa.Id AND ia.NameFragment LIKE '%_sqr-%'
          ORDER BY ia.Width DESC
          LIMIT 1) AS ImageSqr,
        (SELECT ia.NameFragment
          FROM ImageAsset ia
          JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
          WHERE paim.PublicationAssetId = pa.Id AND ia.NameFragment LIKE '%_lsr-%'
          ORDER BY ia.Width DESC
          LIMIT 1) AS ImageLsr
      FROM
        Publication p
      LEFT JOIN
        PublicationAsset pa ON p.Id = pa.PublicationId
      LEFT JOIN
        PublicationRootKey prk ON p.PublicationRootKeyId = prk.Id
      LEFT JOIN
        PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
      LEFT JOIN
        ImageAsset ia ON paim.ImageAssetId = ia.Id
      LEFT JOIN
        meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
      WHERE 
        pa.MepsLanguageId = ? AND p.KeySymbol = ?
      GROUP BY 
        p.Id
      LIMIT 1
      ''', [JwLifeApp.currentLanguage.id, pub]);

    // Détacher la base de données meps et fermer la base de données catalogue
    await catalog.execute("DETACH DATABASE meps");
    await catalog.close();

    // Retourner la première publication si elle existe, sinon retourner null
    if (publications.isNotEmpty) {
      return publications.first;
    } else {
      return null;
    }
  }

  // Retourner null si les fichiers n'existent pas
  return null;
}

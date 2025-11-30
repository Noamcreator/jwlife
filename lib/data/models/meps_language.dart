import 'dart:io';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/services/settings_service.dart';
import '../../core/api/api.dart';
import '../../core/shared_preferences/shared_preferences_utils.dart';
import '../../core/utils/utils.dart';

class MepsLanguage {
  final int id;
  final String symbol;
  final String vernacular;
  final String primaryIetfCode;
  final bool isSignLanguage;
  final String internalScriptName;
  final String displayScriptName;
  final bool isBidirectional;
  final bool isRtl;
  final bool isCharacterSpaced;
  final bool isCharacterBreakable;
  final bool hasSystemDigits;
  final String fallbackPrimaryIetfCode;
  late String rsConf;
  late String lib;

  MepsLanguage({
    required this.id,
    required this.symbol,
    required this.vernacular,
    required this.primaryIetfCode,
    required this.isSignLanguage,
    this.internalScriptName = 'ROMAN',
    this.displayScriptName = 'Roman',
    this.isBidirectional = false,
    this.isRtl = false,
    this.isCharacterSpaced = false,
    this.isCharacterBreakable = false,
    this.hasSystemDigits = true,
    this.fallbackPrimaryIetfCode = 'en',
    this.rsConf = 'r1',
    this.lib = 'lp-e',
  });

  MepsLanguage.fromJson(Map<String, dynamic> json)
      : id = json['MepsLanguageId'] ?? json['LanguageId'],
        symbol = json['LanguageSymbol'] ?? json['Symbol'],
        vernacular = json['LanguageVernacularName'] ?? json['VernacularName'],
        primaryIetfCode = json['LanguagePrimaryIetfCode'] ?? json['PrimaryIetfCode'],
        isSignLanguage = json['IsSignLanguage'] != null ? json['IsSignLanguage'] == 1 : false,
        internalScriptName = json['ScriptInternalName'] ?? json['InternalName'] ?? 'ROMAN',
        displayScriptName = json['ScriptDisplayName'] ?? json['DisplayName'] ?? 'Roman',
        isBidirectional = json['IsBidirectional'] != null ? json['IsBidirectional'] == 1 : false,
        isRtl = json['IsRTL'] != null ? json['IsRTL'] == 1 : false,
        isCharacterSpaced = json['IsCharacterSpaced'] != null ? json['IsCharacterSpaced'] == 1 : false,
        isCharacterBreakable = json['IsCharacterBreakable'] != null ? json['IsCharacterBreakable'] == 1 : false,
        hasSystemDigits = json['HasSystemDigits'] != null ? json['HasSystemDigits'] == 1 : true,
        fallbackPrimaryIetfCode = json['FallbackPrimaryIetfCode'] ?? 'en',
        rsConf = json['RsConf'] ?? 'r1',
        lib = json['Lib'] ?? 'lp-e';


  void setRsConf(String newRsConf) {
    rsConf = newRsConf;
  }

  void setLib(String newLib) {
    lib = newLib;
  }

  static Future<String> fromId(int mepsLanguageId) async {
    File mepsFile = await getMepsUnitDatabaseFile();

    Database database = await openDatabase(mepsFile.path, readOnly: true);

    List<Map<String, dynamic>> results = await database.query(
      'Language',
      where: 'LanguageId = ?',
      whereArgs: [mepsLanguageId]);

    await database.close();

    return results.first['Symbol'];
  }

  Future<void> loadWolInfo() async {
    if(JwLifeSettings.instance.currentLanguage.value.rsConf.isEmpty || JwLifeSettings.instance.currentLanguage.value.lib.isEmpty) {
      final wolLink = 'https://wol.jw.org/wol/finder?wtlocale=${JwLifeSettings.instance.currentLanguage.value.symbol}';
      printTime('WOL link: $wolLink');

      try {
        final headers = Api.getHeaders();

        final response = await Api.dio.get(
          wolLink,
          options: Options(
            headers: headers,
            followRedirects: false, // Bloque la redirection automatique
            maxRedirects: 0,
            validateStatus: (status) => true,
          ),
        );

        // Afficher tous les headers de la réponse
        printTime('All headers: ${response.headers}');

        // Gestion des codes de redirection (301, 302, 307, 308)
        if ([301, 302, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value('location');
          if (location != null && location.isNotEmpty) {
            // Analyse de l'URL de redirection
            final parts = location.split('/');
            if (parts.length >= 6) {
              final rCode = parts[4];
              final lpCode = parts[5];
              printTime('rCode: $rCode');
              printTime('lpCode: $lpCode');

              JwLifeSettings.instance.currentLanguage.value.setRsConf(rCode);
              JwLifeSettings.instance.currentLanguage.value.setLib(lpCode);

              AppSharedPreferences.instance.setLibraryLanguage(JwLifeSettings.instance.currentLanguage);
            }
          } else {
            printTime('No location header found in redirect response');
          }
        } else if (response.statusCode == 200) {
          printTime('Direct response (no redirect)');
          // Traitement si pas de redirection
        } else {
          printTime('Unexpected status code: ${response.statusCode}');
        }

      } catch (e, stack) {
        printTime('Error loading WOL info: $e');
        print(stack);
      }
    }
  }

  Locale getSafeLocale() {
    final supported = WidgetsBinding.instance.platformDispatcher.locales;

    String extractLang(String c) => c.split('-').first;

    String lang = extractLang(primaryIetfCode);
    String secureLang = extractLang(fallbackPrimaryIetfCode);

    // 1️⃣ Tester le code principal
    final matchPrimary = supported.firstWhereOrNull((loc) => loc.languageCode == lang);

    if (matchPrimary != null) {
      return matchPrimary;
    }

    // 2️⃣ Tester le secureCode
    final matchSecure = supported.firstWhereOrNull((loc) => loc.languageCode == secureLang
    );

    if (matchSecure != null) {
      return matchSecure;
    }

    // 3️⃣ Fallback anglais
    return const Locale('en');
  }
}
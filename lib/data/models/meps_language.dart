import 'dart:io';

import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite/sqflite.dart';

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
    this.rsConf = '',
    this.lib = '',
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
        rsConf = json['RsConf'] ?? '',
        lib = json['Lib'] ?? '';


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
}
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
      : id = json['LanguageId'],
        symbol = json['Symbol'],
        vernacular = json['VernacularName'],
        primaryIetfCode = json['PrimaryIetfCode'],
        isSignLanguage = json['IsSignLanguage'] != null ? json['IsSignLanguage'] == 1 : false,
        internalScriptName = json['InternalName'] ?? 'ROMAN',
        displayScriptName = json['DisplayName'] ?? 'Roman',
        isBidirectional = json['IsBidirectional'] != null ? json['IsBidirectional'] == 1 : false,
        isRtl = json['IsRtl'] != null ? json['IsRtl'] == 1 : false,
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
}
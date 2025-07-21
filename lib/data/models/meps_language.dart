class MepsLanguage {
  final int id;
  final String symbol;
  final String vernacular;
  final String primaryIetfCode;
  late String rsConf;
  late String lib;

  MepsLanguage({
    required this.id,
    required this.symbol,
    required this.vernacular,
    required this.primaryIetfCode,
    String? rsConf,
    String? lib,
  }) {
    this.rsConf = rsConf ?? '';
    this.lib = lib ?? '';
  }

  MepsLanguage.fromJson(Map<String, dynamic> json)
      : id = json['LanguageId'],
        symbol = json['Symbol'],
        vernacular = json['VernacularName'],
        primaryIetfCode = json['PrimaryIetfCode'];

  void setRsConf(String newRsConf) {
    rsConf = newRsConf;
  }

  void setLib(String newLib) {
    lib = newLib;
  }
}
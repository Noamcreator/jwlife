class Congregation {
  String guid;
  String name;
  String? address;
  String languageCode;
  double latitude;
  double longitude;
  int? weekendWeekday;
  String? weekendTime;
  int? midweekWeekday;
  String? midweekTime;

  Congregation({
    required this.guid,
    required this.name,
    this.address,
    required this.languageCode,
    required this.latitude,
    required this.longitude,
    this.weekendWeekday,
    this.weekendTime,
    this.midweekWeekday,
    this.midweekTime,
  });

  factory Congregation.fromMap(Map<String, dynamic> map) {
    return Congregation(
      guid: map['Guid'],
      name: map['Name'],
      address: map['Address'],
      languageCode: map['LanguageCode'],
      latitude: map['Latitude'],
      longitude: map['Longitude'],
      weekendWeekday: map['WeekendWeekday'],
      weekendTime: map['WeekendTime'],
      midweekWeekday: map['MidweekWeekday'],
      midweekTime: map['MidweekTime'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Guid': guid,
      'Name': name,
      'Address': address,
      'LanguageCode': languageCode,
      'Latitude': latitude,
      'Longitude': longitude,
      'WeekendWeekday': weekendWeekday,
      'WeekendTime': weekendTime,
      'MidweekWeekday': midweekWeekday,
      'MidweekTime': midweekTime,
    };
  }
}

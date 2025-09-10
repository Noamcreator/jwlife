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

  /// Retourne la prochaine réunion : { "date": DateTime, "type": "midweek"|"weekend" }
  Map<String, dynamic>? nextMeeting() {
    final midweek = getMidweekMeeting();
    final weekend = getWeekendMeeting();

    if (midweek == null && weekend == null) return null;
    if (midweek == null) return {"date": weekend, "type": "weekend"};
    if (weekend == null) return {"date": midweek, "type": "midweek"};

    return midweek.isBefore(weekend) ? {"date": midweek, "type": "midweek"} : {"date": weekend, "type": "weekend"};
  }

  DateTime? getMidweekMeeting() =>
      (midweekWeekday == null || midweekTime == null)
          ? null
          : _computeNextMeeting(midweekWeekday!, midweekTime!);

  DateTime? getWeekendMeeting() =>
      (weekendWeekday == null || weekendTime == null)
          ? null
          : _computeNextMeeting(weekendWeekday!, weekendTime!);

  DateTime? _computeNextMeeting(int weekday, String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final now = DateTime.now();
    final todayWeekday = now.weekday;

    var daysToAdd = weekday - todayWeekday;
    if (daysToAdd < 0) daysToAdd += 7;

    var meeting = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(days: daysToAdd));

    // Fin de la réunion (1h45 après le début)
    final meetingEnd = meeting.add(const Duration(hours: 1, minutes: 45));

    // Si on est déjà après la fin -> prendre la semaine suivante
    if (now.isAfter(meetingEnd)) {
      meeting = meeting.add(const Duration(days: 7));
    }

    return meeting;
  }
}

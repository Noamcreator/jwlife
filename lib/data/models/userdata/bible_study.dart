class BibleStudy {
  final int bibleStudyId;
  final int studentId;
  final int teacherId;
  final int durationTicks;
  final String date;

  BibleStudy({
    required this.bibleStudyId,
    required this.studentId,
    required this.teacherId,
    required this.durationTicks,
    required this.date,
  });

  factory BibleStudy.fromMap(Map<String, dynamic> map) {
    return BibleStudy(
      bibleStudyId: map['BibleStudyId'] as int,
      studentId: map['StudentId'] as int,
      teacherId: map['TeacherId'] as int,
      durationTicks: map['DurationTicks'] as int,
      date: map['Date'] as String,
    );
  }
}
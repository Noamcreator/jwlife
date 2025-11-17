class PersonStatus {
  final int personStatusId;
  final int personId;
  final int statusType; // 0: Bible student, 1: Unbaptized Proclaimer, etc.
  final String startDate;
  final String? endDate;

  PersonStatus({
    required this.personStatusId,
    required this.personId,
    required this.statusType,
    required this.startDate,
    this.endDate,
  });

  factory PersonStatus.fromMap(Map<String, dynamic> map) {
    return PersonStatus(
      personStatusId: map['PersonStatusId'] as int,
      personId: map['PersonId'] as int,
      statusType: map['StatusType'] as int,
      startDate: map['StartDate'] as String,
      endDate: map['EndDate'] as String?,
    );
  }
}
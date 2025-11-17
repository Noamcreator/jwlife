class PersonRole {
  final int personRoleId;
  final int personId;
  final int roleType; // 0: MinisterialServant, 1: Elder, etc.
  final String startDate;
  final String? endDate;

  PersonRole({
    required this.personRoleId,
    required this.personId,
    required this.roleType,
    required this.startDate,
    this.endDate,
  });

  factory PersonRole.fromMap(Map<String, dynamic> map) {
    return PersonRole(
      personRoleId: map['PersonRoleId'] as int,
      personId: map['PersonId'] as int,
      roleType: map['RoleType'] as int,
      startDate: map['StartDate'] as String,
      endDate: map['EndDate'] as String?,
    );
  }
}
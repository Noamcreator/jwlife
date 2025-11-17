class Person {
  final int personId;
  final String firstName;
  final String lastName;
  final String? dateOfBirthDay;
  final int? congregationId;
  final String? address;
  final String? phoneNumber;
  final String? email;
  final String? dateBaptism;
  final String? comment;
  final bool me;

  Person({
    required this.personId,
    required this.firstName,
    required this.lastName,
    this.dateOfBirthDay,
    this.congregationId,
    this.address,
    this.phoneNumber,
    this.email,
    this.dateBaptism,
    this.comment,
    required this.me,
  });

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      personId: map['PersonId'] as int,
      firstName: map['FirstName'] as String,
      lastName: map['LastName'] as String,
      dateOfBirthDay: map['DateOfBirthDay'] as String?,
      congregationId: map['CongregationId'] as int?,
      address: map['Address'] as String?,
      phoneNumber: map['PhoneNumber'] as String?,
      email: map['Email'] as String?,
      dateBaptism: map['DateBaptism'] as String?,
      comment: map['Comment'] as String?,
      me: map['Me'] as int == 1 ? true : false,
    );
  }
}
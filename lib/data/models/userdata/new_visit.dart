class NewVisit {
  final int newVisitId;
  final int personId;     // La personne visitée
  final int proclaimerId; // Le proclamateur qui fait la visite

  NewVisit({
    required this.newVisitId,
    required this.personId,
    required this.proclaimerId,
  });

  factory NewVisit.fromMap(Map<String, dynamic> map) {
    return NewVisit(
      newVisitId: map['NewVisitId'] as int,
      personId: map['PersonId'] as int,
      proclaimerId: map['ProclaimerId'] as int,
    );
  }
}
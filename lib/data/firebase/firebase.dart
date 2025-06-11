
/*
String? getUserDocId() {
  final user = FirebaseAuth.instance.currentUser;
  return user?.uid; // Utilisez cette valeur pour accéder à Firestore
}

Future<DocumentReference<dynamic>> getUserCollection() async {
  return FirebaseFirestore.instance.collection('users').doc(getUserDocId());
}

Future<CollectionReference> getCongregationCollection() async {
  DocumentReference userDoc = await getUserCollection();
  return userDoc.collection('congregations');
}

 */


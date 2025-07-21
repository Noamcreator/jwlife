import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/services/settings_service.dart';

class VisitsView extends StatefulWidget {
  const VisitsView({super.key});

  @override
  _VisitsViewState createState() => _VisitsViewState();
}

class _VisitsViewState extends State<VisitsView> {
  final List<Map<String, dynamic>> _visits = [];
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _selectedPublication = {};
  Map<String, dynamic> _selectedDocument = {};

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Charger les données depuis Firestore
  Future<void> _loadVisits() async {
    /*
    // Charger les rapports depuis Firestore
    DocumentReference userDoc = await getUserCollection();

    final snapshot = await userDoc.collection('visits').get();
    final visitsList = snapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    setState(() {
      _visits.addAll(visitsList);
    });

     */
  }

  // Enregistrer les données dans Firestore
  Future<void> _addVisit() async {
    /*
    // Enregistrer ou mettre à jour le rapport dans Firestore
    DocumentReference userDoc = await getUserCollection();

    // Ajouter une nouvelle visite
    await userDoc.collection('visits').add({
      'first_name': _nameController.text,
      'last_name': _lastNameController.text,
      'address': _addressController.text,
      'date': DateTime.now(),
    });

    // Réinitialiser les champs du formulaire
    _nameController.clear();
    _lastNameController.clear();
    _addressController.clear();

    // Recharger les visites après l'ajout
    _loadVisits();

     */
  }

  Future<void> _showAddVisitDialog() async {
    File catalogFile = await getCatalogFile();
    Database catalogDb = await openDatabase(catalogFile.path);
    List<Map<String, dynamic>> publications = await catalogDb.rawQuery('''
    SELECT * FROM Publication
    WHERE MepsLanguageId = ? AND IssueTagNumber = 0
  ''', [JwLifeSettings().currentLanguage.id]);
    await catalogDb.close();

    File pubCollectionsFile = await getPubCollectionsFile();
    Database pubCollectionDb = await openDatabase(pubCollectionsFile.path);
    List<Map<String, dynamic>> downloadPublications = await pubCollectionDb.rawQuery('''
    SELECT * FROM Publication
    WHERE MepsLanguageId = ? AND IssueTagNumber = 0
  ''', [JwLifeSettings().currentLanguage.id]);
    await pubCollectionDb.close();

    List<Map<String, dynamic>> _documents = [];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Coins arrondis
          ),
          child: SingleChildScrollView(  // Ajout du SingleChildScrollView pour permettre le défilement
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ajouter une Visite',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(labelText: 'Prénom'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un prénom';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(labelText: 'Nom'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un nom';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(labelText: 'Adresse'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer une adresse';
                            }
                            return null;
                          },
                        ),
                        // ComboBox pour choisir une publication
                        DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: InputDecoration(labelText: 'Publication'),
                          items: publications.map((publication) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: publication,
                              child: Text(publication['Title']),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              // Trouver la publication correspondante dans la liste des publications téléchargées
                              Map<String, dynamic> publication = downloadPublications.firstWhere(
                                    (pub) => pub['KeySymbol'] == value['KeySymbol'],
                                orElse: () => {},
                              );

                              List<Map<String, dynamic>> docs = [];
                              if (publication.isNotEmpty) {
                                // Si une publication correspondante est trouvée
                                Database pubDb = await openDatabase(publication['DatabasePath']);
                                docs = await pubDb.rawQuery('SELECT * FROM Document');
                                await pubDb.close();
                              }

                              setState(() {
                                _selectedPublication = publication;
                                _documents = docs;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Veuillez choisir une publication';
                            }
                            return null;
                          },
                        ),
                        // ComboBox pour choisir un document
                        if (_documents.isNotEmpty)
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: _selectedDocument,
                            decoration: InputDecoration(labelText: 'Document'),
                            items: _documents.map((document) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: document,
                                child: Text(document['Title']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDocument = value!;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Veuillez choisir un document';
                              }
                              return null;
                            },
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _addVisit();
                            Navigator.pop(context);
                          }
                        },
                        child: Text('Ajouter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _visits.length,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text(
                '${_visits[index]['first_name']} ${_visits[index]['last_name']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_visits[index]['address']),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  _nameController.text = _visits[index]['first_name'];
                  _lastNameController.text = _visits[index]['last_name'];
                  _addressController.text = _visits[index]['address'];
                  _showAddVisitDialog();
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVisitDialog,
        elevation: 6.0,
        shape: const CircleBorder(),
        tooltip: 'Ajouter une visite',
        child: Icon(
          JwIcons.plus,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
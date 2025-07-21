import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';

import 'contact_editor_page.dart';

class BrothersAndSistersPage extends StatefulWidget {
  const BrothersAndSistersPage({super.key});

  @override
  _BrothersAndSistersPageState createState() => _BrothersAndSistersPageState();
}

class _BrothersAndSistersPageState extends State<BrothersAndSistersPage> {
  List<Map<String, dynamic>> _congregations = [];
  List<Map<String, dynamic>> _brothersAndSisters = [];
  bool _isLoading = true;
  String? _selectedCongregationId;

  @override
  void initState() {
    super.initState();
    _fetchCongregationsFromFirestore();
  }

  Future<void> _fetchCongregationsFromFirestore() async {
    /*
    try {
      CollectionReference congregationCollection = await getCongregationCollection();
      final querySnapshot = await congregationCollection.get();

      setState(() {
        _congregations = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            ...data,
            'id': doc.id,
          };
        }).toList();
        _congregations.sort((a, b) {
          String nameA = a['name']?.toString().toLowerCase() ?? '';
          String nameB = b['name']?.toString().toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });


      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des congrégations : $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

     */
  }

  Future<void> _loadSelectedCongregation() async {
    /*
    try {
      // Récupérer la référence de l'utilisateur
      CollectionReference usersRef = FirebaseFirestore.instance.collection('users');
      DocumentSnapshot userDoc = await usersRef.doc("utilisateur_id_unique").get(); // Remplace par l'ID réel

      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          _selectedCongregationId = userDoc['selected_congregation'];
        });

        // Charger les frères et sœurs après avoir récupéré la congrégation
        _fetchBrothersAndSisters();
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement de la congrégation : $e");
    }

     */
  }



  /*
  Future<void> _saveSelectedCongregation(String congregationId) async {
    if (congregationId.isNotEmpty) {
      try {
        CollectionReference congregationCollection = await getCongregationCollection();

        final docRef = await congregationCollection.add(data);
        debugPrint('Congrégation enregistrée avec succès.');
      } catch (e) {
        debugPrint('Erreur lors de l\'enregistrement : $e');
      }
    }
  }

   */

  // Méthode pour importer des contacts
  Future<void> _importContacts() async {
    // Request contact permission
    if (await FlutterContacts.requestPermission()) {
      try {
        List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);

        // Convertir les contacts en SelectableContact
        List<SelectableContact> selectableContacts = contacts
            .map((contact) => SelectableContact(contact: contact))
            .toList();

        // Afficher la fenêtre de sélection multiple de contacts
        List<SelectableContact>? selectedContacts = await showDialog<List<SelectableContact>>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Sélectionnez des contacts'),
              content: SingleChildScrollView(
                child: Column(
                  children: selectableContacts.map((selectableContact) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: Text(selectableContact.contact.displayName),
                          value: selectableContact.isSelected,
                          onChanged: (bool? selected) {
                            setState(() {
                              selectableContact.isSelected = selected ?? false;
                            });
                          },
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Filtrer les contacts sélectionnés avant de les renvoyer
                    List<SelectableContact> selected = selectableContacts
                        .where((selectableContact) => selectableContact.isSelected)
                        .toList();
                    Navigator.pop(context, selected);
                  },
                  child: const Text('Valider'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Fermer la boîte de dialogue sans sélectionner
                  },
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );

        // Vérifie si des contacts ont été sélectionnés
        if (selectedContacts != null && selectedContacts.isNotEmpty) {
          for (var selectableContact in selectedContacts) {
            // Ajoute chaque contact sélectionné à ta congrégation
            await _addContactToCongregation(selectableContact.contact);
          }
        }
      }
      catch (e) {
        debugPrint('Erreur lors de l\'importation des contacts : $e');
      }
    }
  }

  Future<void> _addContactToCongregation(Contact contact) async {
    /*
    if (_selectedCongregationId != null) {
      try {
        // Récupérer la collection des frères et sœurs dans la congrégation sélectionnée
        CollectionReference congregationRef = await getCongregationCollection();
        DocumentReference congregationDoc = congregationRef.doc(_selectedCongregationId);
        CollectionReference brothersAndSisters = congregationDoc.collection('brothers_and_sisters');

        // Préparer les données
        Map<String, dynamic> data = {
          'first_name': contact.name.first,
          'last_name': contact.name.last,
          'phones': contact.phones.map((phone) => phone.number).toList(),
          'address': contact.addresses.map((address) => address.address).toList(),
          'emails': contact.emails.map((email) => email.address).toList(),
        };

        // Ajouter le contact dans la base de données
        await brothersAndSisters.doc(contact.id).set(data);

        // Rafraîchir la liste des frères et sœurs
        _fetchBrothersAndSisters();
      } catch (e) {
        debugPrint('Erreur lors de l\'ajout du contact : $e');
      }
    }

     */
  }

  // Méthode pour récupérer les frères et sœurs de la congrégation sélectionnée
  Future<void> _fetchBrothersAndSisters() async {
    /*
    if (_selectedCongregationId != null) {
      try {
        CollectionReference congregationRef = await getCongregationCollection();
        DocumentReference congregationDoc = congregationRef.doc(_selectedCongregationId);
        CollectionReference brothersAndSisters = congregationDoc.collection('brothers_and_sisters');

        final querySnapshot = await brothersAndSisters.get();

        setState(() {
          _brothersAndSisters = querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              ...data,
              'id': doc.id,
            };
          }).toList();
        });
      } catch (e) {
        debugPrint('Erreur lors du chargement des frères et sœurs : $e');
      }
    }

     */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // DropdownButton pour sélectionner une congrégation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(JwIcons.kingdom_hall, size: 25),
              const SizedBox(width: 8),
              DropdownButton<String>(
                hint: const Text('Sélectionnez une congrégation'),
                value: _selectedCongregationId,
                items: _congregations.map((congregation) {
                  return DropdownMenuItem<String>(
                    value: congregation['id'],
                    child: Text(congregation['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCongregationId = value;

                  });
                  _fetchBrothersAndSisters(); // Rafraîchir la liste des frères et sœurs
                },
              ),
            ]
          ),
          // Liste des frères et sœurs
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _brothersAndSisters.map((brother) {
                  return GestureDetector(
                    onTap: () {
                      showPage(context, ContactEditorPage(congregationId: _selectedCongregationId!, id: brother['id']));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Card(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1f1f1f)
                            : Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar ou icône
                              CircleAvatar(
                                radius: 30,
                                child: Text(
                                  brother['first_name'] != null
                                      ? brother['first_name'][0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              // Détails du contact
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Afficher le prénom et le nom
                                    Text(
                                      '${brother['first_name'] ?? 'Prénom inconnu'} ${brother['last_name'] ?? ''}'.trim(),
                                      style: const TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    // Liste des numéros de téléphone
                                    if ((brother['phones'] as List).isNotEmpty)
                                      ...List<Widget>.from(
                                        (brother['phones'] as List).map((phone) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone, size: 18),
                                              const SizedBox(width: 8.0),
                                              Text(
                                                phone,
                                                style: const TextStyle(
                                                  fontSize: 16.0,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                      )
                                    else
                                      Row(
                                        children: [
                                          const Icon(Icons.phone, size: 18),
                                          const SizedBox(width: 8.0),
                                          const Text(
                                            'Pas de numéro',
                                            style: TextStyle(
                                              fontSize: 16.0,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 8.0),
                                    // Liste des adresses
                                    if ((brother['address'] as List).isNotEmpty)
                                      ...List<Widget>.from(
                                        (brother['address'] as List).map((address) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 18),
                                              const SizedBox(width: 8.0),
                                              Expanded(
                                                child: Text(
                                                  address,
                                                  style: const TextStyle(
                                                    fontSize: 16.0,
                                                    color: Colors.grey,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                      )
                                    else
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 18),
                                          const SizedBox(width: 8.0),
                                          const Text(
                                            'Pas d\'adresse',
                                            style: TextStyle(
                                              fontSize: 16.0,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 8.0),
                                    // Liste des emails
                                    if ((brother['emails'] as List).isNotEmpty)
                                      ...List<Widget>.from(
                                        (brother['emails'] as List).map((email) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.email, size: 18),
                                              const SizedBox(width: 8.0),
                                              Expanded(
                                                child: Text(
                                                  email,
                                                  style: const TextStyle(
                                                    fontSize: 16.0,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                      )
                                    else
                                      Row(
                                        children: [
                                          const Icon(Icons.email, size: 18),
                                          const SizedBox(width: 8.0),
                                          const Text(
                                            'Pas d\'email',
                                            style: TextStyle(
                                              fontSize: 16.0,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(JwIcons.plus),
        onPressed: () => _importContacts(),
      )
    );
  }
}

class SelectableContact {
  Contact contact;
  bool isSelected;

  SelectableContact({required this.contact, this.isSelected = false});
}

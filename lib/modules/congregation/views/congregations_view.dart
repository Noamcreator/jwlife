import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/i18n/localization.dart';
import 'dart:convert';
import 'package:searchfield/searchfield.dart';
import 'package:url_launcher/url_launcher.dart';

class CongregationsView extends StatefulWidget {
  const CongregationsView({super.key});

  @override
  _CongregationsViewState createState() => _CongregationsViewState();
}

class _CongregationsViewState extends State<CongregationsView> {
  List<dynamic> _suggestions = [];
  List<Map<String, dynamic>> _congregations = [];
  bool _isLoading = true;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    //_fetchCongregationsFromFirestore();
  }

  /*
  Future<CollectionReference> getCongregationCollection() async {
    DocumentReference userDoc = await getUserCollection();
    return userDoc.collection('congregations');
  }

  Future<void> _fetchCongregationsFromFirestore() async {
    try {
      // Récupérer la collection des congrégations
      CollectionReference congregationCollection = await getCongregationCollection();

      // Effectuer la requête pour obtenir les documents
      final querySnapshot = await congregationCollection.get();

      setState(() {
        // Récupérer les données et ajouter l'ID du document à chaque item
        _congregations = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            ...data,
            'id': doc.id,
          };
        }).toList();

        // Tri des congrégations par nom (si le champ 'name' existe)
        _congregations.sort((a, b) {
          String nameA = a['name']?.toString().toLowerCase() ?? '';
          String nameB = b['name']?.toString().toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des congrégations : $e');
    } finally {
      // Mettre à jour l'état de chargement une fois l'opération terminée
      setState(() {
        _isLoading = false;
      });
    }
  }

   */

  Future<List<dynamic>> _fetchCongregations(String query) async {
    /*
    final queryParams = {
      'includeSuggestions': 'true',
      'keywords': query,
      'latitude': '0',
      'longitude': '0',
      'searchLanguageCode': JwLifeApp.settings.currentLanguage.symbol
    };

    final url = Uri.https(
        'apps.jw.org',
        '/api/public/meeting-search/weekly-meetings',
        queryParams
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if(data['geoLocationList'] is List) {
        return data['geoLocationList'].map((item) => _convertSuggestionToCongregation(item)).toList();
      }
    }
     */
    return [];
  }

  Future<void> _fetchCongregationSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = []; // Clear suggestions if the query is empty
      });
      return;
    }

    List<dynamic> congregations = await _fetchCongregations(query);

    setState(() {
      _suggestions = congregations;
    });
  }

  dynamic _convertSuggestionToCongregation(dynamic suggestion) {
    final properties = suggestion['properties'];
    final location = suggestion['location'];

    return {
      'name': properties['orgName'],
      'address': properties['address'].replaceAll('\r\n', ' '),
      'languageCode': properties['languageCode'],
      'schedule': properties['schedule']['current'],
      'phone': properties['phones'][0]['phone'],
      'location': {
        'latitude': location['latitude'],
        'longitude': location['longitude'],
      },
    };
  }

  Future<void> _saveCongregationToFirestore(dynamic data) async {
    /*
    try {
      CollectionReference congregationCollection = await getCongregationCollection();

      final docRef = await congregationCollection.add(data);
      setState(() {
        _congregations.add({
          ...data,
          'id': docRef.id,
        });
        _showSearchBar = false;
      });
      debugPrint('Congrégation enregistrée avec succès.');
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement : $e');
    }

     */
  }

  void _showEditDialog(Map<String, dynamic> congregation) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController =
        TextEditingController(text: congregation['name']);
        final TextEditingController addressController =
        TextEditingController(text: congregation['address']);

        return AlertDialog(
          title: const Text('Modifier la congrégation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                /*
                try {
                  CollectionReference congregationCollection = await getCongregationCollection();

                  congregationCollection.doc(congregation['id'])
                      .update({
                    'name': nameController.text,
                    'address': addressController.text,
                  });
                  setState(() {
                    congregation['name'] = nameController.text;
                    congregation['address'] = addressController.text;
                  });
                  Navigator.pop(context);
                } catch (e) {
                  debugPrint('Erreur lors de la mise à jour : $e');
                }

                 */
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateCongregation(Map<String, dynamic> congregation) async {
    /*
    try {
      List<dynamic> congregations = await _fetchCongregations(congregation['name']);
      dynamic data = congregations.first;

      // Mise à jour des champs dans Firestore
      CollectionReference congregationCollection = await getCongregationCollection();

      congregationCollection
          .doc(congregation['id'])
          .update({
        'name': data['name'],
        'address': data['address'],
        'languageCode': data['languageCode'],
        'schedule': data['schedule'],
        'phone': data['phone'],
        'location': data['location'],
      });

      // Mise à jour de l'UI pour refléter les changements
      setState(() {
        // Recherche de la congrégation mise à jour et remplacement dans la liste
        int index = _congregations.indexWhere((item) => item['id'] == congregation['id']);
        if (index != -1) {
          _congregations[index] = data; // Mise à jour de la congrégation dans la liste locale
        }
      });
      debugPrint('Congrégation mise à jour avec succès.');
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour : $e');
    }

     */
  }

  // Fonction pour obtenir le nom du jour localisé
  String _getLocalizedWeekday(int weekday) {
    // Utilisation de la date actuelle et ajustement du jour
    final now = DateTime.now();
    final date = now.add(Duration(days: (weekday - now.weekday)));
    // Formatage avec intl pour obtenir le jour localisé
    return DateFormat.EEEE(JwLifeApp.settings.locale.languageCode).format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if ((_showSearchBar || _congregations.isEmpty) && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchField<dynamic>(
                autofocus: true,
                offset: Offset(0, 58),
                itemHeight: 55,
                textInputAction: TextInputAction.search,
                searchInputDecoration: SearchInputDecoration(
                  searchStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                  filled: true,
                  hintText: localization(context).search_hint,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSearchTextChanged: (text) {
                  setState(() {
                    _fetchCongregationSuggestions(text);
                  });
                  return null;
                },
                onSuggestionTap: (suggestion) {
                  _saveCongregationToFirestore(suggestion.item);
                },
                suggestionsDecoration: SuggestionDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                suggestions: _suggestions
                    .map((item) => SearchFieldListItem<dynamic>(item['name'],
                  item: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor), maxLines: 1),
                        Text(item['address'], style: TextStyle(fontSize: 10), maxLines: 1),
                      ],
                    ),
                  ),
                ),
                ).toList(),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final congregation in _congregations)
                    GestureDetector(
                      onTap: () async {
                        _showEditDialog(congregation);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              congregation['name'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              congregation['address'],
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Horaires des réunions :",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${_getLocalizedWeekday(congregation['schedule']['midweek']['weekday'])}: ${congregation['schedule']['midweek']['time']}",
                                  style: const TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  "${_getLocalizedWeekday(congregation['schedule']['weekend']['weekday'])}: ${congregation['schedule']['weekend']['time']}",
                                  style: const TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.location_on, color: Colors.blue),
                                  onPressed: () {
                                    String url =
                                        'https://www.google.com/maps/dir/?api=1&destination=${congregation['location']['latitude']},${congregation['location']['longitude']}&travelmode=driving';
                                    launchUrl(Uri.parse(url));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(JwIcons.arrows_circular, color: Colors.deepPurple),
                                  onPressed: () => _updateCongregation(congregation),
                                ),
                                IconButton(
                                  icon: const Icon(JwIcons.trash, color: Colors.red),
                                  onPressed: () async {
                                    /*
                                    try {
                                      CollectionReference congregationCollection = await getCongregationCollection();
                                      congregationCollection
                                          .doc(congregation['id'])
                                          .delete();
                                      setState(() {
                                        _congregations.remove(congregation);
                                      });
                                    } catch (e) {
                                      debugPrint('Erreur lors de la suppression : $e');
                                    }

                                     */
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showSearchBar = !_showSearchBar;
          });
        },
        child: const Icon(JwIcons.plus),
      ),
    );
  }
}

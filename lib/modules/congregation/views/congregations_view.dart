import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/i18n/localization.dart';
import 'dart:convert';
import 'package:searchfield/searchfield.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api.dart';
import '../../../data/userdata/Congregation.dart';

class CongregationsView extends StatefulWidget {
  const CongregationsView({super.key});

  @override
  _CongregationsViewState createState() => _CongregationsViewState();
}

class _CongregationsViewState extends State<CongregationsView> {
  List<Congregation> _suggestions = [];
  List<Congregation> _congregations = [];
  final SearchController _searchController = SearchController();
  bool _isLoading = true;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _fetchCongregationsFromDatabase();
  }

  Future<void> _fetchCongregationsFromDatabase() async {
    setState(() => _isLoading = true);

    try {
      // Récupérer les données depuis la base SQLite
      final fetchedCongregations = await JwLifeApp.userdata.getCongregations();

      // Tri par nom (champ 'Name' dans ta table)
      fetchedCongregations.sort((a, b) {
        final nameA = (a.name ?? '').toString().toLowerCase();
        final nameB = (b.name ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() {
        _congregations = fetchedCongregations;
      });
    } catch (e, stackTrace) {
      debugPrint('Erreur lors du chargement des congrégations : $e');
      debugPrintStack(stackTrace: stackTrace);
    }
    finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Congregation>> _fetchCongregations(String query) async {
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

    final response = await Api.httpGetWithHeadersUri(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if(data['geoLocationList'] is List) {
        List<Congregation> congregations = data['geoLocationList']
            .map((item) => _convertSuggestionToCongregation(item))
            .toList()
            .cast<Congregation>();
        return congregations;
      }
    }
    return [];
  }

  Future<void> _fetchCongregationSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = []; // Clear suggestions if the query is empty
      });
      return;
    }

    List<Congregation> congregations = await _fetchCongregations(query);

    for(var cong in congregations) {
      print('Congregation: ${cong}');
    }

    setState(() {
      _suggestions = congregations;
    });
  }

  Congregation _convertSuggestionToCongregation(dynamic suggestion) {
    final properties = suggestion['properties'];
    final location = suggestion['location'];

    return Congregation.fromMap({
      'Guid': properties['orgGuid'],
      'Name': properties['orgName'],
      'Address': properties['address'].replaceAll('\r\n', ' '),
      'LanguageCode': properties['languageCode'],
      'Latitude': location['latitude'],
      'Longitude': location['longitude'],
      'WeekendWeekday': properties['schedule']['current']['weekend']['weekday'],
      'WeekendTime': properties['schedule']['current']['weekend']['time'],
      'MidweekWeekday': properties['schedule']['current']['midweek']['weekday'],
      'MidweekTime': properties['schedule']['current']['midweek']['time'],
      //'phone': properties['phones'][0]['phone'],
    });
  }

  Future<void> _saveCongregationToDatabase(Congregation data) async {
    try {
      await JwLifeApp.userdata.insertCongregation(data);

      setState(() {
        _congregations.add(data);
        _showSearchBar = false;
      });

      debugPrint('Congrégation enregistrée avec succès.');
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement : $e');
    }
  }

  void _showEditDialog(Congregation congregation) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController =
        TextEditingController(text: congregation.name);
        final TextEditingController addressController =
        TextEditingController(text: congregation.address);

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
                try {
                  congregation.name = nameController.text;
                  congregation.address = addressController.text;

                  // Mise à jour en base SQLite
                  await JwLifeApp.userdata.updateCongregation(congregation.guid, congregation);

                  // Mettre à jour la liste locale et l'UI
                  setState(() {
                    int index = _congregations.indexWhere((item) => item.guid == congregation.guid);
                    if (index != -1) {
                      _congregations[index] = congregation;
                    }
                  });

                  Navigator.pop(context);
                } catch (e) {
                  debugPrint('Erreur lors de la mise à jour : $e');
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateCongregation(Congregation congregation) async {
    try {
      await JwLifeApp.userdata.updateCongregation(congregation.guid, congregation);

      // Mettre à jour la liste locale pour refléter la modification
      setState(() {
        int index = _congregations.indexWhere((item) => item.guid == congregation.guid);
        if (index != -1) {
          _congregations[index] = congregation;
        }
      });

      debugPrint('Congrégation mise à jour avec succès.');
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour : $e');
    }
  }

  // Fonction pour obtenir le nom du jour localisé
  String _getLocalizedWeekday(int weekday) {
    // Utilisation de la date actuelle et ajustement du jour
    final now = DateTime.now();
    final date = now.add(Duration(days: (weekday - now.weekday)));
    // Formatage avec intl pour obtenir le jour localisé
    return DateFormat.EEEE(JwLifeApp.settings.locale.languageCode).format(date);
  }

  /// Méthode réutilisable pour construire chaque élément de suggestion
  SearchFieldListItem<Congregation> _buildCongregationItem(Congregation item) {
    return SearchFieldListItem<Congregation>(
      item.name,
      item: item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
              overflow: TextOverflow.ellipsis,
            ),
            if (item.address!.isNotEmpty ?? false)
              Text(
                item.address!,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          if ((_showSearchBar || _congregations.isEmpty) && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchField<Congregation>(
                controller: _searchController,
                animationDuration: Duration(milliseconds: 300),
                autofocus: false,
                offset: Offset(-8, 58),
                itemHeight: 55,
                maxSuggestionsInViewPort: 7,
                maxSuggestionBoxHeight: 200,
                suggestionState: Suggestion.expand,
                searchInputDecoration: SearchInputDecoration(
                    hintText: localization(context).search_hint,
                    searchStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1f1f1f)
                        : const Color(0xFFf1f1f1),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: GestureDetector(
                      child: Container(
                          color: Color(0xFF345996),
                          margin: const EdgeInsets.only(left: 2),
                          child: Icon(JwIcons.magnifying_glass, color: Colors.white)
                      ),
                      onTap: () {
                        //showPage(context, SearchView(query: _searchController.text));
                      },
                    )
                ),
                suggestionsDecoration: SuggestionDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1f1f1f)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  width: MediaQuery.of(context).size.width-15,
                ),
                suggestions: _suggestions.map(_buildCongregationItem).toList(),
                onSearchTextChanged: (text) async {
                  _fetchCongregationSuggestions(text);
                  return [];
                },
                onSuggestionTap: (item) async {
                  final selected = item.item!;
                  _saveCongregationToDatabase(selected);
                  setState(() {
                    _showSearchBar = false;
                  });
                },
                onTapOutside: (event) {
                  setState(() {
                    _showSearchBar = false;
                  });
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _congregations.length,
              itemBuilder: (context, index) {
                final congregation = _congregations[index];
                return GestureDetector(
                  onTap: () async {
                    _showEditDialog(congregation);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1f1f1f) : Colors.white,
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
                          congregation.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          congregation.address!,
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
                              "${_getLocalizedWeekday(congregation.weekendWeekday!)}: ${congregation.weekendTime}",
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              "${_getLocalizedWeekday(congregation.midweekWeekday!)}: ${congregation.midweekTime}",
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
                                String url = 'https://www.google.com/maps/dir/?api=1&destination=${congregation.latitude},${congregation.longitude}&travelmode=driving';
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
                                try {
                                  final guid = congregation.guid;
                                  await JwLifeApp.userdata.deleteCongregation(guid);
                                  setState(() {
                                    _congregations.removeWhere((item) => item.guid == guid);
                                  });
                                } catch (e) {
                                  debugPrint('Erreur lors de la suppression : $e');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
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

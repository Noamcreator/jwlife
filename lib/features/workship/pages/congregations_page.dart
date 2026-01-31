import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_page.dart';
import '../../../app/jwlife_app_bar.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/api/api.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/userdata/congregation.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/decoration.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/input_decoration.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/searchfield.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/searchfield_list_item.dart';

class CongregationsPage extends StatefulWidget {
  const CongregationsPage({super.key});

  @override
  _CongregationsPageState createState() => _CongregationsPageState();
}

class _CongregationsPageState extends State<CongregationsPage> {
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
        final nameA = (a.name).toString().toLowerCase();
        final nameB = (b.name).toString().toLowerCase();
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
      'searchLanguageCode': JwLifeSettings.instance.workshipLanguage.value.symbol
    };

    final url = Uri.https(
        'apps.jw.org',
        '/api/public/meeting-search/weekly-meetings',
        queryParams
    );

    print('URL de recherche : $url');

    final response = await Api.httpGetWithHeadersUri(url);
    if (response.statusCode == 200) {
      if(response.data['geoLocationList'] is List) {
        List<Congregation> congregations = response.data['geoLocationList']
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
      printTime('Congregation: $cong');
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

      GlobalKeyService.workShipKey.currentState!.fetchFirstCongregation();

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
      List<Congregation> congregations = await _fetchCongregations(congregation.name);

      if (congregations.isNotEmpty) {
          // Si la congrégation existe déjà, on la supprime
         Congregation? newCongregation = congregations.firstWhereOrNull((c) => c.guid == congregation.guid);

        if(newCongregation != null) {
          // 1. Mise à jour dans la base de données/API via le provider
          await JwLifeApp.userdata.updateCongregation(congregation.guid, newCongregation);

          // 2. Mettre à jour la liste locale pour refléter la modification dans l'UI
          setState(() {
            int index = _congregations.indexWhere((item) => item.guid == newCongregation.guid);
            if (index != -1) {
              _congregations[index] = newCongregation;
            }
          });

          debugPrint('Congrégation ${congregation.guid} mise à jour avec succès.');
        }
      }
    } 
    catch (e) {
      debugPrint('Erreur lors de la mise à jour : $e');
      // Optionnel : ajouter un feedback utilisateur ici (SnackBar, etc.)
    }
  }

  // Fonction pour obtenir le nom du jour localisé
  String _getLocalizedWeekday(int weekday) {
    final now = DateTime.now();
    final date = now.add(Duration(days: (weekday - now.weekday)));
    final locale = getSafeLocale();
    return DateFormat.EEEE(locale).format(date);
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
            if (item.address!.isNotEmpty)
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

  Future<void> _allUpdateCongregations() async {
    try {
      for(Congregation congregation in _congregations) {
        await _updateCongregation(congregation);
      }

      showBottomMessage('Toutes les assemblées locales ont été mises à jour avec succès.');
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour : $e');
      // Optionnel : ajouter un feedback utilisateur ici (SnackBar, etc.)
    }
  }


  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().action_congregations,
        subTitle: _congregations.isNotEmpty ? _congregations[0].name : null,
        actions: [
          IconTextButton(text: '', icon: Icon(JwIcons.cloud_arrow_down), onPressed: (anchorContext) => _allUpdateCongregations()),
        ]
      ),
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
                    hintText: i18n().search_hint,
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
                        //showPage(SearchView(query: _searchController.text));
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
                final isDark = Theme.of(context).brightness == Brightness.dark;

                final locale = getSafeLocale();
                final midweekTime = DateFormat("HH:mm").parse(congregation.midweekTime!);
                final hourMidweekStr = DateFormat("HH", locale).format(midweekTime);
                final minuteMidweekStr = DateFormat("mm", locale).format(midweekTime);

                final weekendTime = DateFormat("HH:mm").parse(congregation.weekendTime!);
                final hourWeekendStr = DateFormat("HH", locale).format(weekendTime);
                final minuteWeekendStr = DateFormat("mm", locale).format(weekendTime);

                return GestureDetector(
                  onTap: () => _showEditDialog(congregation),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF000000) : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // L'icône demandée
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            JwIcons.kingdom_hall,
                            size: 35,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                congregation.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                i18n().label_date_next_meeting(_getLocalizedWeekday(congregation.midweekWeekday!), hourMidweekStr, minuteMidweekStr),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                i18n().label_date_next_meeting(_getLocalizedWeekday(congregation.weekendWeekday!), hourWeekendStr, minuteWeekendStr),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                congregation.address ?? "",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Le bouton Menu Popup
                        PopupMenuButton<String>(
                          useRootNavigator: true,
                          icon: Icon(Icons.more_horiz, color: isDark ? Colors.white54 : Colors.black54),
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          onSelected: (value) async {
                            switch (value) {
                              case 'go':
                                String url = 'https://www.google.com/maps/search/?api=1&query=${congregation.latitude},${congregation.longitude}';
                                launchUrl(Uri.parse(url));
                                break;
                              case 'update':
                                _updateCongregation(congregation);
                                break;
                              case 'delete':
                                try {
                                  final guid = congregation.guid;
                                  await JwLifeApp.userdata.deleteCongregation(guid);
                                  setState(() {
                                    _congregations.removeWhere((item) => item.guid == guid);
                                  });
                                } catch (e) {
                                  debugPrint('Erreur : $e');
                                }
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem(
                              value: 'go',
                              child: ListTile(
                                leading: Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                                title: const Text('Y aller'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'update',
                              child: ListTile(
                                leading: Icon(JwIcons.arrows_circular, color: Theme.of(context).primaryColor),
                                title: const Text('Actualiser'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(JwIcons.trash, color: Theme.of(context).primaryColor),
                                title: const Text('Supprimer'),
                                contentPadding: EdgeInsets.zero,
                              ),
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

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

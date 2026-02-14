import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_page.dart';
import '../../../app/jwlife_app_bar.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/icons.dart';
import '../../../core/utils/common_ui.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/decoration.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/input_decoration.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/searchfield.dart';
import '../../../widgets/searchfield/searchfield_with_suggestions/searchfield_list_item.dart';

/// Modèle pour les données du tableau des pays avec support du genre
class ForebearsCountry {
  final String name;
  final String code;
  final String incidence;
  final String frequency;
  final String rank;
  final String? malePct;
  final String? femalePct;

  ForebearsCountry({
    required this.name,
    required this.code,
    required this.incidence,
    required this.frequency,
    required this.rank,
    this.malePct,
    this.femalePct,
  });
}

class ForebearsPage extends StatefulWidget {
  const ForebearsPage({super.key});

  @override
  State<ForebearsPage> createState() => _ForebearsPageState();
}

class _ForebearsPageState extends State<ForebearsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _suggestions = [];
  List<ForebearsCountry> _countries = [];
  Map<String, String>? _selectedDetails;
  bool _isLoadingDetails = false;
  bool _isMapBeingTouched = false;

  Future<List<dynamic>> _fetchForebearsSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse('https://forebears.io/data/cache/ps/${query.trim().toLowerCase()}.json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Erreur suggestions: $e');
    }
    return [];
  }

  Future<String> _getFullUrl(String path) async {
    final lang = JwLifeSettings.instance.libraryLanguage.value.primaryIetfCode;
    String fullLang = 'x/$lang/';
    if (lang == 'en') fullLang = '';
    return 'https://forebears.io/$fullLang$path';
  }

  Future<void> _fetchDetails(String path) async {
    setState(() {
      _isLoadingDetails = true;
      _selectedDetails = null;
      _countries = [];
    });

    try {
      final fullUrl = await _getFullUrl(path);
      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var contentBox = document.querySelector('.content-box-content.medium-text.tablet-slim');

        if (contentBox != null) {
          String count = contentBox.querySelector('.accent b')?.text ?? "Inconnu";
          var stats = contentBox.querySelectorAll('.statistic-single');

          String prevalent = "N/A", prevalentCode = "";
          String density = "N/A", densityCode = "";

          if (stats.isNotEmpty) {
            var detail = stats[0].querySelector('.detail');
            prevalent = detail?.text.trim() ?? "N/A";
            prevalentCode = detail?.querySelector('use')?.attributes['href']?.split('#').last ?? "";
          }
          if (stats.length > 1) {
            var detail = stats[1].querySelector('.detail');
            density = detail?.text.trim() ?? "N/A";
            densityCode = detail?.querySelector('use')?.attributes['href']?.split('#').last ?? "";
          }

          List<ForebearsCountry> tempCountries = [];
          var rows = document.querySelectorAll('.nation-table tbody tr');

          for (var row in rows) {
            var cols = row.querySelectorAll('td');
            if (cols.length >= 4) {
              bool hasGender = cols.length == 5;
              
              // Extraction des genres (mâle / femelle)
              String? male, female;
              var genderCell = hasGender ? cols[1] : null;
              if (genderCell != null) {
                male = genderCell.querySelector('.m')?.text.trim();
                female = genderCell.querySelector('.f')?.text.trim();
              }

              tempCountries.add(ForebearsCountry(
                name: cols[0].text.trim(),
                code: cols[0].querySelector('use')?.attributes['href']?.split('#').last ?? "",
                incidence: hasGender ? cols[2].text.trim() : cols[1].text.trim(),
                frequency: hasGender ? cols[3].text.trim() : cols[2].text.trim(),
                rank: hasGender ? cols[4].text.trim() : cols[3].text.trim(),
                malePct: male,
                femalePct: female,
              ));
            }
          }

          setState(() {
            _countries = tempCountries;
            _selectedDetails = {
              'count': count,
              'prevalent': prevalent,
              'prevalentCode': prevalentCode,
              'density': density,
              'densityCode': densityCode,
              'name': capitalize(fullUrl.split('/').last),
              'url': fullUrl
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Scraping error: $e');
      showBottomMessage("Erreur de connexion");
    } finally {
      setState(() => _isLoadingDetails = false);
    }
  }

  /// Formate "1:33,211" en "1 sur 33 211" et gère les virgules
  String _formatFrequency(String raw) => raw.replaceAll(':', ' sur ').replaceAll(',', ' ');
  String _formatNumber(String raw) => raw.replaceAll(',', ' ');

  Map<String, Color> _generateMapColors() {
    Map<String, Color> mapColors = {};
    if (_countries.isEmpty) return mapColors;

    final List<Color> paliersCouleurs = [
      const Color(0xFFF8D587),
      const Color(0xFFF2B05E),
      const Color(0xFFE88B3A),
      const Color(0xFFD85D2A),
      const Color(0xFFB41D21),
    ];

    List<double> ranks = _countries
        .map((c) => double.tryParse(c.rank.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0)
        .where((r) => r > 0).toList();

    if (ranks.isEmpty) return mapColors;
    ranks.sort();
    double minRank = ranks.first;
    double maxRank = ranks.last;

    for (var country in _countries) {
      if (country.code.isNotEmpty) {
        double currentRank = double.tryParse(country.rank.replaceAll(RegExp(r'[^0-9]'), '')) ?? maxRank;
        double ratio = 1.0;
        if (maxRank != minRank) ratio = 1.0 - ((currentRank - minRank) / (maxRank - minRank));
        int indexPalier = (ratio * (paliersCouleurs.length - 1)).round().clamp(0, paliersCouleurs.length - 1);
        mapColors[country.code.toLowerCase()] = paliersCouleurs[indexPalier];
      }
    }
    return mapColors;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppPage(
      appBar: JwLifeAppBar(
        title: "Forebears",
        subTitle: i18n().forebears_subtitle,
        titleWidget: SearchField<dynamic>(
          controller: _searchController,
          suggestions: _suggestions.map(_buildForebearsItem).toList(),
          suggestionState: Suggestion.expand,
          itemHeight: 54,
          maxSuggestionsInViewPort: 6,
          offset: const Offset(0, 50),
          searchInputDecoration: SearchInputDecoration(
            hintText: i18n().forebears_search_hint,
            fillColor: isDark ? const Color(0xFF1f1f1f) : const Color(0xFFf1f1f1),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: InputBorder.none,
            suffixIcon: Container(color: const Color(0xFF345996), child: const Icon(JwIcons.magnifying_glass, color: Colors.white)),
          ),
          suggestionsDecoration: SuggestionDecoration(color: isDark ? const Color(0xFF2A2A2A) : Colors.white),
          onSearchTextChanged: (query) async {
            final results = await _fetchForebearsSuggestions(query);
            setState(() => _suggestions = results);
            return [];
          },
          onSuggestionTap: (item) {
            FocusScope.of(context).unfocus();
            _fetchDetails(item.item!['url']);
          },
          onSubmit: (query) {
            FocusScope.of(context).unfocus();
            _fetchDetails('surnames/${query.trim().toLowerCase()}');
          },
          autofocus: true,
        ),
      ),
      body: Column(
        children: [
          if (_isLoadingDetails) LinearProgressIndicator(minHeight: 3, color: Theme.of(context).primaryColor),
          Expanded(child: _selectedDetails == null ? _buildEmptyState(isDark) : _buildDetailsCard(isDark)),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(bool isDark) {
    final Color titleColor = isDark ? const Color(0xFFa0b9e2) : const Color(0xFF4a6da7);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: _isMapBeingTouched ? const NeverScrollableScrollPhysics() : const ScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_selectedDetails!['name']!, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 10),
          Text(i18n().forebears_count_description(_selectedDetails!['count']!), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF292929))),
          const Divider(height: 30),
          Row(children: [
            Expanded(child: _buildStatRow(i18n().forebears_prevalent_label, _selectedDetails!['prevalent']!, _selectedDetails!['prevalentCode'])),
            Expanded(child: _buildStatRow(i18n().forebears_density_label, _selectedDetails!['density']!, _selectedDetails!['densityCode'])),
          ]),
          const SizedBox(height: 30),
          Text(i18n().forebears_map_title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 12),
          Listener(
            onPointerDown: (_) => setState(() => _isMapBeingTouched = true),
            onPointerUp: (_) => setState(() => _isMapBeingTouched = false),
            onPointerCancel: (_) => setState(() => _isMapBeingTouched = false),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141414) : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  maxScale: 75.0,
                  child: SimpleMap(
                    instructions: SMapWorld.instructions,
                    colors: _generateMapColors(),
                    countryBorder: CountryBorder(color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFBCBCBA), width: 0.3),
                    defaultColor: isDark ? const Color(0xFF292929) : const Color(0xFFCCCCCC),
                    callback: (id, name, _) => _showCountryDialog(id, name),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(i18n().forebears_table_title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 12),
          if (_countries.isNotEmpty) _buildCountryTable(isDark),
          const SizedBox(height: 25),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(_selectedDetails!['url']!)),
            style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: titleColor, minimumSize: const Size(double.infinity, 45), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
            child: Text(i18n().forebears_external_link, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCountryDialog(String id, String name) {
    ForebearsCountry? country = _countries.firstWhereOrNull((c) => c.code == id);
    if (country == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showJwDialog(
      context: context,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drapeau et libellé alignés proprement
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.network(
                    'https://flagcdn.com/w40/${country.code.toLowerCase()}.png',
                    width: 30, // Un peu plus grand pour la lisibilité
                    errorBuilder: (_, __, ___) => const Icon(Icons.flag, size: 30),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  country.name,
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            _buildRichInfo(i18n().forebears_incidence_label, _formatNumber(country.incidence)),
            const SizedBox(height: 10),
            _buildRichInfo(i18n().forebears_frequency_label, _formatFrequency(country.frequency)),
            const SizedBox(height: 10),
            _buildRichInfo(i18n().forebears_rank_label, _formatNumber(country.rank)),
            
            if (country.malePct != null || country.femalePct != null) ...[
              const SizedBox(height: 20),
              Text(i18n().forebears_gender_stats_title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(children: [
                  if (country.malePct != null) 
                    Expanded(
                      flex: int.tryParse(country.malePct!.replaceAll('%', '')) ?? 0, 
                      child: Container(height: 24, color: Colors.blue[400], child: Center(child: Text("♂ ${country.malePct}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                    ),
                  if (country.femalePct != null) 
                    Expanded(
                      flex: int.tryParse(country.femalePct!.replaceAll('%', '')) ?? 0, 
                      child: Container(height: 24, color: Colors.pink[300], child: Center(child: Text("♀ ${country.femalePct}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                    ),
                ]),
              ),
            ]
          ],
        ),
      ),
      buttons: [JwDialogButton(label: i18n().action_ok, closeDialog: true)],
      buttonAxisAlignment: MainAxisAlignment.end
    );
  }

  Widget _buildRichInfo(String label, String value) {
    return Text.rich(TextSpan(children: [
      TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      TextSpan(text: ' '),
      TextSpan(text: value, style: const TextStyle(fontSize: 16)),
    ]));
  }

  Widget _buildCountryTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : Colors.black12), borderRadius: BorderRadius.circular(4)),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5)},
        children: [
          TableRow(decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12), children: [
            Padding(padding: EdgeInsets.all(10), child: Text(i18n().forebears_table_header_place, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Padding(padding: EdgeInsets.all(10), child: Text(i18n().forebears_table_header_incidence, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Padding(padding: EdgeInsets.all(10), child: Text(i18n().forebears_table_header_rank, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ]),
          ..._countries.map((c) => TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12))),
            children: [
              Padding(padding: const EdgeInsets.all(10), child: Row(children: [
                if (c.code.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8), child: Image.network('https://flagcdn.com/w20/${c.code.toLowerCase()}.png', width: 20)),
                Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              ])),
              Padding(padding: const EdgeInsets.all(10), child: Text(_formatNumber(c.incidence), style: const TextStyle(fontSize: 13))),
              Padding(padding: const EdgeInsets.all(10), child: Text(_formatNumber(c.rank), style: const TextStyle(fontSize: 13))),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(JwIcons.globe_lands, size: 80, color: isDark ? Colors.white30 : Colors.black12),
      const SizedBox(height: 16),
      Text(i18n().forebears_empty_state_text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white30 : Colors.black12), textAlign: TextAlign.center),
    ])));
  }

  Widget _buildStatRow(String label, String value, String? code) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      const SizedBox(height: 4),
      Row(children: [
        if (code != null && code.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6), child: Image.network('https://flagcdn.com/w40/${code.toLowerCase()}.png', width: 20, errorBuilder: (_, __, ___) => const SizedBox())),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ]),
    ]);
  }

  SearchFieldListItem<dynamic> _buildForebearsItem(dynamic item) {
    final isSurname = item['type'] == 's';
    return SearchFieldListItem<dynamic>(item['name'], item: item, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
      Icon(isSurname ? JwIcons.family : JwIcons.brother, size: 18, color: Colors.grey),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(isSurname ? i18n().forebears_type_surname : i18n().forebears_type_firstname, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ])),
    ])));
  }
}
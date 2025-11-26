import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/app_page.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';

import '../app/startup/auto_update.dart';
import '../i18n/i18n.dart';

class ReleasesPage extends StatefulWidget {
  const ReleasesPage({super.key});

  @override
  _ReleasesPageState createState() {
    return _ReleasesPageState();
  }
}

class _ReleasesPageState extends State<ReleasesPage> {
  final releases = ValueNotifier<List<dynamic>>([]);
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredReleases = [];
  List<String> _uniqueVersions = ['Toutes les versions'];
  String _selectedVersion = 'Toutes les versions';

  @override
  void initState() {
    super.initState();
    fetchReleases();
    _searchController.addListener(_filterReleases);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterReleases);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchReleases() async {
    List<dynamic> releasesList = await JwLifeAutoUpdater.getAllReleases();

    releases.value = releasesList.reversed.toList();
    _filteredReleases = releases.value;
    _updateUniqueVersions();
  }

  void _updateUniqueVersions() {
    final versions = releases.value.map<String>((r) => r['version'].toString()).toSet().toList();
    versions.sort((a, b) => b.compareTo(a));
    setState(() {
      _uniqueVersions = ['Toutes les versions', ...versions];
    });
  }

  void _filterReleases() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      List<dynamic> baseList = releases.value;

      if (_selectedVersion != 'Toutes les versions') {
        baseList = baseList.where((release) => release['version'] == _selectedVersion).toList();
      }

      if (query.isEmpty) {
        _filteredReleases = baseList;
      } else {
        _filteredReleases = baseList.where((release) {
          final version = release['version'].toString().toLowerCase();
          final changelog = release['changelog'].toString().toLowerCase();
          final timestamp = release['timestamp'].toString().toLowerCase();

          return version.contains(query) || changelog.contains(query) || timestamp.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: JwLifeAppBar(
        title: "Les mise à jour de l'application",
      ),
      body: ValueListenableBuilder(
        valueListenable: releases,
        builder: (context, value, child) {
          if (value.isEmpty && _searchController.text.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final displayList = _filteredReleases;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: i18n().search_bar_search,
                          hintStyle: TextStyle(color: Colors.grey),
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          contentPadding: EdgeInsets.all(10),
                          visualDensity: VisualDensity.compact,
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        cursorColor: Colors.grey,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("Filtrer par version:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8.0),
                    DropdownButton<String>(
                      value: _selectedVersion,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedVersion = newValue;
                            _searchController.clear();
                            _filterReleases();
                          });
                        }
                      },
                      items: _uniqueVersions.map<DropdownMenuItem<String>>((String version) {
                        return DropdownMenuItem<String>(
                          value: version,
                          child: Text(version),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              if (displayList.isEmpty)
                Expanded(
                    child: Center(child: Text(i18n().search_results_none))
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemBuilder: (context, index) {
                      final release = displayList[index];

                      String formatDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(release['timestamp']));

                      return ListTile(
                        title: Text(
                          '${i18n().settings_application_version} : ${release['version']} - ($formatDate)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                        ),
                        subtitle: GptMarkdown(
                          release['changelog'],
                          textScaler: TextScaler.linear(1.1),
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                        )
                      );
                    },
                    separatorBuilder: (context, index) {
                      return const Divider(color: Colors.grey);
                    },
                    itemCount: displayList.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
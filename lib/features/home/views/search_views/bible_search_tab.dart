import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/features/home/views/search_views/search_view.dart';

import 'search_model.dart';

class BibleSearchTab extends StatefulWidget {
  final SearchModel model;

  const BibleSearchTab({super.key, required this.model});

  @override
  _BibleSearchTabState createState() => _BibleSearchTabState();
}

class _BibleSearchTabState extends State<BibleSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.model.fetchBible(), // appel async
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun résultat trouvé.'));
          }

          final results = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];

              return GestureDetector(
                onTap: () async {
                  String itemString = item['lank']; // "bv-62004016_nwtsty"
                  String itemString2 = itemString.split("-")[1].split("_")[0]; // "62004016"

                  int bookNumber = int.parse(itemString2.substring(0, 2));  // 62
                  int chapterNumber = int.parse(itemString2.substring(2, 5));  // 4
                  int verseNumber = int.parse(itemString2.substring(5, 8));  // 16

                  String query = JwLifeApp.bibleCluesInfo.getVerses(
                    bookNumber,
                    chapterNumber,
                    verseNumber,
                    bookNumber,
                    chapterNumber,
                    verseNumber,
                  );

                  showPage(context, SearchView(query: query));
                },
                child: Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF292929)
                      : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFa0b9e2)
                                : const Color(0xFF4a6da7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                            item['snippet'],
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                        ),
                      ],
                    ),
                  )
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import '../../../../core/api/wikipedia_api.dart';

class WikipediaSearchTab extends StatefulWidget {
  final SearchModel model;

  const WikipediaSearchTab({super.key, required this.model});

  @override
  _WikipediaSearchTabState createState() => _WikipediaSearchTabState();
}

class _WikipediaSearchTabState extends State<WikipediaSearchTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WikipediaArticle>>(
      future: widget.model.fetchWikipedia(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucun article Wikipédia trouvé.'));
        }

        final articles = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: articles.map((article) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article.extract,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import '../../../../core/api/wikipedia_api.dart';
// Import pour lancer l'URL
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/widgets_utils.dart';

class WikipediaSearchTab extends StatefulWidget {
  final SearchModel model;

  const WikipediaSearchTab({super.key, required this.model});

  @override
  _WikipediaSearchTabState createState() => _WikipediaSearchTabState();
}

class _WikipediaSearchTabState extends State<WikipediaSearchTab> {
  // Fonction pour lancer l'URL de l'article
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Gérer l'erreur si l'URL ne peut pas être lancée (optionnel)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le lien : $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Définition des couleurs pour le thème (pour un contraste lisible)
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final shadowColor = isDarkMode ? Colors.black : Colors.grey.withOpacity(0.3);

    return FutureBuilder<List<WikipediaArticle>>(
      future: widget.model.fetchWikipedia(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return getLoadingWidget(Theme.of(context).primaryColor);
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Afficher la requête de recherche si aucun résultat n'est trouvé
          final query = widget.model.query;
          return Center(child: Text('Aucun article Wikipédia trouvé pour "$query".'));
        }

        final articles = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final article = articles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              // Utilisez un InkWell pour rendre le conteneur cliquable et ajouter un effet visuel
              child: InkWell(
                onTap: () {
                  if (article.url != null) {
                    _launchUrl(article.url!);
                  } else {
                    // 1. Ajoutez le message d'erreur entre guillemets.
                    // 2. Fermez l'appel de fonction avec un point-virgule.
                    showBottomMessage('Désolé, l\'URL de l\'article est manquante.');
                  }
                },
                borderRadius: BorderRadius.circular(10), // Assure que le splash effect respecte le border radius
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor, // Couleur de fond du conteneur
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200, // Bordure subtile
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre
                      Text(
                        article.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).primaryColor
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Description (Source/Catégorie)
                      Text(
                        article.description,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Extrait
                      Text(
                        article.extract,
                        style: const TextStyle(fontSize: 15),
                        maxLines: 8, // Limiter l'extrait à quelques lignes
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
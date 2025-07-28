import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/utils/utils.dart';
import '../../../../core/utils/utils_jwpub.dart';
import 'search_model.dart';

class VersesSearchTab extends StatefulWidget {
  final SearchModel model;

  const VersesSearchTab({super.key, required this.model});

  @override
  _VersesSearchTabState createState() => _VersesSearchTabState();
}

class _VersesSearchTabState extends State<VersesSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>?>(
        future: widget.model.fetchVerses(), // appel async
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun résultat trouvé.'));
          }

          final results = snapshot.data;

          if (results == null) {
            return Center(
              child: Text("La recherche « ${widget.model.query} » n'est pas un verset valide"),
            );
          }

          if (results.isEmpty) {
            return const Center(
              child: Text('Aucun verset trouvé'),
            );
          }

          /*
          results.sort((a, b) {
            final yearA = a['Year'] ?? 0;
            final yearB = b['Year'] ?? 0;
            return yearB.compareTo(yearA);
          });

           */

          // Affichage de la liste
          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];

              String paragraphText = '';
              final beginPosition = item['BeginPosition'];
              final endPosition = item['EndPosition'];

              printTime('KeySymbol: ${item['Symbol']}, Year: ${item['Year']}, MepsLanguageIndex: ${item['MepsLanguageIndex']}, IssueTagNumber: ${item['IssueTagNumber']}');

              if (beginPosition != null && endPosition != null) {
                // Décoder le contenu HTML
                final documentBlob = decodeBlobParagraph(item['Content'], getPublicationHash(item['MepsLanguageIndex'], item['Symbol'], item['Year'], int.parse(item['IssueTagNumber'])));
                final paragraphBlob = documentBlob.sublist(beginPosition, endPosition);

                // Extraire le fragment du HTML normalisé
                final paragraphHtml = utf8.decode(paragraphBlob);

                // Si vous avez besoin d'un texte brut après, utilisez parse
                paragraphText = parse(paragraphHtml).body?.text ?? '';
              }

              Publication? downloadPub = PublicationRepository().getByCompositeKey(item['Symbol'], item['IssueTagNumber'], item['MepsLanguageIndex']);

              return item['Content'] == null || downloadPub == null ? null : GestureDetector(
                onTap: () async {
                  showDocumentView(context, item['MepsDocumentId'], item['MepsLanguageIndex'], startParagraphId: item['ParagraphOrdinal'], endParagraphId: item['ParagraphOrdinal']);
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
                        item['FilePath'] != null
                            ? Row(
                          children: [
                            Image.file(File('${downloadPub.path}/${item['FilePath']}'), height: 60, width: 60),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item['DocumentTitle'],
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFa0b9e2)
                                      : const Color(0xFF4a6da7),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ) : Text(
                          item['DocumentTitle'],
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFa0b9e2)
                                : const Color(0xFF4a6da7),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          paragraphText,
                          style: const TextStyle(fontSize: 17),
                        ),
                        // ajoute une ligne entre les deux pour separer
                        Divider(
                          height: 20,
                          thickness: 1,
                          color: Colors.grey[800],
                        ),
                        Row(
                          children: [
                            ImageCachedWidget(
                              imageUrl: downloadPub.imageSqr,
                              pathNoImage: downloadPub.category.image,
                              height: 45,
                              width: 45,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    downloadPub.category.getName(context),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    downloadPub.getTitle(),
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${downloadPub.symbol} - ${downloadPub.year}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              )
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
        },
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/databases/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/utils/utils_jwpub.dart';
import 'search_model.dart';

class ImagesSearchTab extends StatefulWidget {
  final SearchModel model;

  const ImagesSearchTab({super.key, required this.model});

  @override
  _ImagesSearchTabState createState() => _ImagesSearchTabState();
}

class _ImagesSearchTabState extends State<ImagesSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.model.fetchImages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          final images = snapshot.data ?? [];

          if (images.isEmpty) {
            return const Center(child: Text('Aucune image trouvée.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: images.map((item) {
                Publication downloadPub = PublicationRepository()
                    .getAllDownloadedPublications()
                    .firstWhere((pub) =>
                pub.symbol == item['Symbol'] &&
                    pub.year == item['Year'] &&
                    pub.mepsLanguage.id == item['MepsLanguageIndex']);

                final filePath = item['FilePath'];
                final label = item['Label'] ?? 'Sans titre';
                final path = downloadPub.path;

                if (filePath == null || path == null) return const SizedBox();

                final imageFile = File('$path/$filePath');
                if (!imageFile.existsSync()) return const SizedBox();

                final double originalWidth = (item['Width'] ?? 200).toDouble();
                final double originalHeight = (item['Height'] ?? 200).toDouble();

                // Limite la largeur à la moitié de l'écran
                final double maxDisplayWidth =
                    MediaQuery.of(context).size.width / 2 - 20;
                final double aspectRatio = originalWidth / originalHeight;
                final double displayHeight = maxDisplayWidth / aspectRatio;

                return GestureDetector(
                  onTap: () {
                    showDocumentView(
                      context,
                      item['MepsDocumentId'],
                      item['MepsLanguageIndex'],
                      startParagraphId: item['BeginParagraphOrdinal'],
                      endParagraphId: item['EndParagraphOrdinal'],
                    );
                  },
                  child: SizedBox(
                    width: maxDisplayWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            imageFile,
                            width: maxDisplayWidth,
                            height: displayHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

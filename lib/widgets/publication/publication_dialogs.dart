import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// Fonction pour afficher le dialogue de téléchargement
Future<String?> showVideoDialog(BuildContext context, String lank, String wtlocale) async {
  final apiUrl = 'https://b.jw-cdn.org/apis/mediator/v1/media-items/$wtlocale/$lank';

  try {
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      return showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8, // Largeur personnalisée
              padding: EdgeInsets.all(20.0), // Ajouter un padding
              child: Column(
                mainAxisSize: MainAxisSize.min, // Pour ne pas remplir tout l'espace
                children: [
                  Text(
                    "VIDÉO: " + data['media'][0]['title'],
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      CachedNetworkImage(
                        imageUrl: data['media'][0]['images']['sqr']['md'],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Durée: " + data['media'][0]['durationFormattedMinSec']),
                          Text("Date: " + DateFormat('dd/MM/yyyy').format(DateTime.parse(data['media'][0]['firstPublished']))),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Fermer le dialogue sans valeur
                        },
                        child: Text('ANNULER'),
                      ),
                      TextButton(
                        onPressed: () {
                          showDownloadDialog(context, data['media'][0]['files']);
                        },
                        child: Text('TÉLÉCHARGER'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop('play'); // Retourner 'play'
                        },
                        child: Text('LIRE'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      print('Loading error: ${response.statusCode}');
    }
  } catch (e) {
    print('An exception occurred: $e');
  }

  return null; // Retourne null en cas d'échec
}
// Fonction pour afficher le dialogue de téléchargement
void showDownloadDialog(BuildContext context, List<dynamic> files) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8, // Largeur personnalisée
          padding: EdgeInsets.all(20.0), // Ajouter un padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Pour ne pas remplir tout l'espace
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Résolution",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: files.map<Widget>((file) {
                  return ListTile(
                    title: Text("Télécharger ${file['label']} (${(file['filesize'] / (1024 * 1024)).toStringAsFixed(2)} Mo)"),
                    onTap: () {
                      // Gérer le téléchargement ici
                      print("Télécharger: ${file['progressiveDownloadURL']}");
                      Navigator.of(context).pop(); // Fermer le dialogue de téléchargement
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Fermer le dialogue
                  },
                  child: Text('ANNULER'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
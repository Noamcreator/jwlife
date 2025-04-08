import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  _SpeechToTextScreenState createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  late SpeechToText _speech;
  bool _isListening = false;
  String _text = "Appuyez sur le bouton et commencez à parler.";
  final List<String> _bibleVerses = [];
  String _generalText = "";  // Texte général sans les versets détectés

  @override
  void initState() {
    super.initState();
    _speech = SpeechToText();
  }

  /// Vérifie si un texte contient un verset biblique
  List<String> _extractBibleVerses(String text) {
    final regex = RegExp(
        r'\b(?:[1-3]?\s?[A-Za-zéèêîôû\-]+)\s?\d+:\d+\b',  // Expression régulière améliorée
        caseSensitive: false);
    return regex.allMatches(text).map((match) => match.group(0)!).toList();
  }

  /// Sépare le texte général des versets détectés
  void _separateTextAndVerses(String text) {
    // Extraire les versets
    List<String> verses = _extractBibleVerses(text);

    // Retirer les versets du texte
    String filteredText = text;
    for (String verse in verses) {
      filteredText = filteredText.replaceAll(verse, '');
    }

    // Mettre à jour le texte et la liste des versets
    setState(() {
      _generalText = filteredText.trim(); // Texte sans versets
      _bibleVerses.addAll(verses); // Ajouter les versets à la liste
    });
  }

  /// Démarre ou arrête la reconnaissance vocale
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print("Statut: $status"),
        onError: (error) => print("Erreur: $error"),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _text = val.recognizedWords; // Texte complet
            _bibleVerses.clear(); // Effacer les versets précédents
            _separateTextAndVerses(_text); // Séparer texte et versets
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reconnaissance de versets bibliques"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Affichage du texte général sans les versets
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _generalText.isNotEmpty ? _generalText : _text,
                  style: TextStyle(fontSize: 18.0),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Affichage des versets détectés sous forme de boutons
            if (_bibleVerses.isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: _bibleVerses.map((verse) {
                  return ElevatedButton(
                    onPressed: () {
                      // Action lors d'un clic sur un verset
                      print("Verset sélectionné: $verse");
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Verset détecté"),
                          content: Text("Cliquez pour afficher $verse"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Fermer"),
                            )
                          ],
                        ),
                      );
                    },
                    child: Text(verse),
                  );
                }).toList(),
              ),
            SizedBox(height: 16),

            // Bouton pour démarrer/arrêter la reconnaissance vocale
            FloatingActionButton(
              onPressed: _listen,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none),
            ),
          ],
        ),
      ),
    );
  }
}

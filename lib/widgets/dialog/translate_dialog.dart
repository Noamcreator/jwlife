import 'package:flutter/material.dart';
import 'package:jwlife/core/api/translate_api.dart';

class TranslationContent extends StatefulWidget {
  final String text;
  final String? initialTargetLang;

  const TranslationContent({super.key, required this.text, this.initialTargetLang});

  @override
  State<TranslationContent> createState() => _TranslationContentState();
}

class _TranslationContentState extends State<TranslationContent> {
  late String _sourceLang;
  late String _targetLang;
  late Future<Map<String, dynamic>> _translationFuture;

  // Liste simplifiée pour l'exemple (à compléter selon tes besoins)
  final Map<String, String> _languages = {
    'auto': 'Détection automatique',
    'fr': 'Français',
    'en': 'Anglais',
    'es': 'Espagnol',
    'de': 'Allemand',
    'it': 'Italien',
    'pt': 'Portugais',
  };

  @override
  void initState() {
    super.initState();
    _sourceLang = 'auto';
    _targetLang = widget.initialTargetLang ?? 'fr';
    _runTranslation();
  }

  void _runTranslation() {
    setState(() {
      _translationFuture = fetchTranslation(widget.text, sourceLang: _sourceLang, targetLang: _targetLang);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Sélecteurs de Langues ---
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: _sourceLang,
                isExpanded: true,
                onChanged: (val) {
                  setState(() => _sourceLang = val!);
                  _runTranslation();
                },
                items: _languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 16)),
            Expanded(
              child: DropdownButton<String>(
                value: _targetLang,
                isExpanded: true,
                onChanged: (val) {
                  setState(() => _targetLang = val!);
                  _runTranslation();
                },
                // On retire 'auto' pour la langue de destination
                items: _languages.entries.where((e) => e.key != 'auto').map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // --- Résultat de la Traduction ---
        FutureBuilder<Map<String, dynamic>>(
          future: _translationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return const Text("Erreur de traduction");

            final data = snapshot.data!;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              //decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: SelectableText(data['destination-text'] ?? ''),
            );
          },
        ),
      ],
    );
  }
}
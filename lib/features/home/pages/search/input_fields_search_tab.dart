import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';

import '../../../../app/services/settings_service.dart';

class InputFieldsSearchTab extends StatefulWidget {
  final SearchModel model; // type générique, ton model avec fetchInputFields()

  const InputFieldsSearchTab({super.key, required this.model});

  @override
  _InputFieldsSearchTabState createState() => _InputFieldsSearchTabState();
}

class _InputFieldsSearchTabState extends State<InputFieldsSearchTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.model.fetchInputFields(), // Future<List<Map<String, dynamic>>>
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun champ trouvé.'));
          }

          final inputFields = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: inputFields.length,
            itemBuilder: (context, index) {
              final item = inputFields[index];
              final textTag = item['TextTag']?.toString() ?? '';
              final value = item['Value']?.toString() ?? '';
              final mepsDocumentId = item['DocumentId'] ?? 0;
              final mepsLanguageId = JwLifeSettings().currentLanguage.id;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  title: Text(value),
                  onTap: () {
                    showDocumentView(context, mepsDocumentId, mepsLanguageId, textTag: textTag);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

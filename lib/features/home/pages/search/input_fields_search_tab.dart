import 'package:flutter/material.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import 'package:jwlife/features/personal/widgets/input_field_item_widget.dart';

import '../../../../core/utils/widgets_utils.dart';
import '../../../../data/models/userdata/input_field.dart';

class InputFieldsSearchTab extends StatefulWidget {
  final SearchModel model; // type générique, ton model avec fetchInputFields()

  const InputFieldsSearchTab({super.key, required this.model});

  @override
  _InputFieldsSearchTabState createState() => _InputFieldsSearchTabState();
}

class _InputFieldsSearchTabState extends State<InputFieldsSearchTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InputField>>(
      future: widget.model.fetchInputFields(), // Future<List<Map<String, dynamic>>>
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return getLoadingWidget(Theme.of(context).primaryColor);
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucun champ trouvé.'));
        }

        final inputFields = snapshot.data!;

        return Scrollbar(
          interactive: true,
          child: CustomScrollView(
            physics: ClampingScrollPhysics(),
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final inputField = inputFields[index];

                    return _KeepAliveNoteItem(
                      key: ValueKey('field_${inputField.textTag}_${inputField.location.mepsDocumentId}'),
                      inputField: inputField,
                      onUpdated: () => setState(() {}),
                      searchQuery: widget.model.query,
                    );
                  },
                  childCount: inputFields.length,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KeepAliveNoteItem extends StatefulWidget {
  final InputField inputField;
  final VoidCallback onUpdated;
  final String searchQuery;

  const _KeepAliveNoteItem({
    super.key,
    required this.inputField,
    required this.onUpdated,
    this.searchQuery = '', // Initialisé à vide par défaut
  });

  @override
  State<_KeepAliveNoteItem> createState() => _KeepAliveNoteItemState();
}

class _KeepAliveNoteItemState extends State<_KeepAliveNoteItem>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return InputFieldItemWidget(
      inputField: widget.inputField,
      onUpdated: widget.onUpdated,
      fullField: false,
      highlightQuery: widget.searchQuery,
    );
  }
}


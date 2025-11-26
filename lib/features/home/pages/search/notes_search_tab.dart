import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/controller/notes_controller.dart';
import '../../../../data/models/userdata/note.dart';
import '../../../personal/widgets/note_item_widget.dart';
import 'search_model.dart';

class NotesSearchTab extends StatefulWidget {
  final SearchModel model;

  const NotesSearchTab({super.key, required this.model});

  @override
  _NotesSearchTabState createState() => _NotesSearchTabState();
}

class _NotesSearchTabState extends State<NotesSearchTab> {

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesController>().searchNotes(widget.model.query);

    return Scrollbar(
      interactive: true,
      child: CustomScrollView(
        physics: ClampingScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final note = notes[index];

                return _KeepAliveNoteItem(
                  key: ValueKey('note_${note.guid}'),
                  note: note,
                  onUpdated: () => setState(() {}),
                  // 🌟 TRANSMISSION du terme de recherche au widget enfant
                  searchQuery: widget.model.query,
                );
              },
              childCount: notes.length,
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
              addSemanticIndexes: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepAliveNoteItem extends StatefulWidget {
  final Note note;
  final VoidCallback onUpdated;
  final String searchQuery;

  const _KeepAliveNoteItem({
    super.key,
    required this.note,
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

    return NoteItemWidget(
      note: widget.note,
      tag: null,
      onUpdated: widget.onUpdated,
      fullNote: false,
      // 🌟 TRANSMISSION au NoteItemWidget (nommé ici highlightQuery pour clarifier son rôle)
      highlightQuery: widget.searchQuery,
    );
  }
}

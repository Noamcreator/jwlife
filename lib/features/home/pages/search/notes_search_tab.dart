import 'package:flutter/material.dart';
import '../../../../data/models/userdata/note.dart';
import '../../../personal/widgets/note_item_widget.dart';
import 'search_model.dart'; // ton modèle avec la méthode fetchNotes qui doit retourner List<Note>

class NotesSearchTab extends StatefulWidget {
  final SearchModel model;

  const NotesSearchTab({super.key, required this.model});

  @override
  _NotesSearchTabState createState() => _NotesSearchTabState();
}

class _NotesSearchTabState extends State<NotesSearchTab> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Note>>(
        future: widget.model.fetchNotes(), // méthode async qui renvoie List<Note>
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune note trouvée.'));
          }

          final notes = snapshot.data!;

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
                        key: ValueKey('note_${note.noteId}'),
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
        },
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

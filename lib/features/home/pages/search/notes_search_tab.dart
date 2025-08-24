import 'package:flutter/material.dart';
import '../../../../data/models/userdata/note.dart';
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

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];

              return GestureDetector(
                onTap: () {
                  // TODO : remplacer par ta navigation vers la page détail note
                  showNoteDetail(context, note);
                },
                child: Card(
                  color: note.getColor(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.title != null && note.title!.isNotEmpty)
                          Text(
                            note.title!,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (note.title != null && note.title!.isNotEmpty)
                          const SizedBox(height: 10),
                        if (note.content != null && note.content!.isNotEmpty)
                          Text(
                            note.content!,
                            style: const TextStyle(fontSize: 17),
                          ),
                        const SizedBox(height: 15),
                        Divider(
                          height: 20,
                          thickness: 1,
                          color: Colors.grey[800],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              note.getRelativeTime(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            if (note.location.title != null && note.location.title!.isNotEmpty)
                              Text(
                                note.location.title!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
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

  void showNoteDetail(BuildContext context, Note note) {
    // Placeholder : afficher un dialogue ou page détail note
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(note.title ?? 'Note'),
        content: SingleChildScrollView(child: Text(note.content ?? '')),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Fermer')),
        ],
      ),
    );
  }
}

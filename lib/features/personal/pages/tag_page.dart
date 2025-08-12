import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import '../widgets/note_item_widget.dart';
import 'note_page.dart';

class TagPage extends StatefulWidget {
  final Tag tag;

  const TagPage({super.key, required this.tag});

  @override
  _TagPageState createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  late Tag _tag;
  List<Note> _filteredNotes = [];

  @override
  void initState() {
    super.initState();
    _tag = widget.tag;
    notesByCategory();
  }

  Future<void> notesByCategory() async {
    // Fetch notes by category first
    List<Note> notes = await JwLifeApp.userdata.getNotesByTag(_tag.id);

    // Now update the state with the fetched notes
    setState(() {
      _filteredNotes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _tag);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tag.name),
            Text(
              '${_filteredNotes.length} notes',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(JwIcons.note_plus),
            onPressed: () async {
              Note? note = await JwLifeApp.userdata.addNote("", "", 0, [_tag.id], null, null, null, null, null, null);
              if (note != null) {
                await showPage(context, NotePage(note: note));
                setState(() {
                  _filteredNotes.add(note);
                });
              }
            },
          ),
          IconButton(
            icon: Icon(JwIcons.pencil),
            onPressed: () async {
              // Utiliser await à l'extérieur du setState
              Tag? updatedCategory = await showEditTagDialog(context, _tag);

              // Si la catégorie a été mise à jour, on applique le setState
              if (updatedCategory != null) {
                setState(() {
                  _tag = updatedCategory;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(JwIcons.tag_crossed),
            onPressed: () async {
               await showDeleteTagDialog(context, _tag).then((value) => setState(() {}));
               Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Scrollbar(
        interactive: true,
        child: ListView.builder(
          itemCount: _filteredNotes.length,
          itemBuilder: (context, index) {
            final note = _filteredNotes[index];

            if (note.noteId == -1) {
              return Container();
            }

            return NoteItemWidget(
              note: note,
              onUpdated: () => setState(() {}),
            );
          },
        ),
      ),
    );
  }
}

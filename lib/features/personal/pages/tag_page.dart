import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import '../../../app/services/global_key_service.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tag = widget.tag;
    notesByCategory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> notesByCategory() async {
    List<Note> notes = await JwLifeApp.userdata.getNotesByTag(_tag.id);
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
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context, result: _tag);
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
                await showPage(NotePage(note: note));
                setState(() {
                  _filteredNotes.add(note);
                });
              }
            },
          ),
          IconButton(
            icon: Icon(JwIcons.pencil),
            onPressed: () async {
              Tag? updatedCategory = await showEditTagDialog(context, _tag);
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
              bool? tagDeleted = await showDeleteTagDialog(context, _tag);
              setState(() {});
              if (tagDeleted == true) {
                GlobalKeyService.jwLifePageKey.currentState?.handleBack(context, result: _tag);
              }
            },
          ),
        ],
      ),
      body: Scrollbar(
        interactive: true,
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          // Physics qui empêche les sauts
          physics: ClampingScrollPhysics(),
          // Padding pour éviter les problèmes de bords
          padding: EdgeInsets.zero,
          itemCount: _filteredNotes.length,
          // Séparateur invisible pour stabiliser les hauteurs
          separatorBuilder: (context, index) => SizedBox(height: 0),
          itemBuilder: (context, index) {
            final note = _filteredNotes[index];

            if (note.noteId == -1) {
              return SizedBox.shrink();
            }

            // Wrapping dans AutomaticKeepAliveClientMixin via un widget custom
            return _KeepAliveNoteItem(
              key: ValueKey('note_${note.noteId}'),
              note: note,
              tag: _tag,
              onUpdated: () => setState(() {}),
            );
          },
        ),
      ),
    );
  }
}

// Widget custom qui maintient l'état vivant pour éviter les sauts
class _KeepAliveNoteItem extends StatefulWidget {
  final Note note;
  final Tag tag;
  final VoidCallback onUpdated;

  const _KeepAliveNoteItem({
    super.key,
    required this.note,
    required this.tag,
    required this.onUpdated,
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
    super.build(context); // Important pour AutomaticKeepAliveClientMixin

    return NoteItemWidget(
      note: widget.note,
      tag: widget.tag,
      onUpdated: widget.onUpdated,
      fullNote: true,
    );
  }
}
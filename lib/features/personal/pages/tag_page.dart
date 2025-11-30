import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import 'package:provider/provider.dart';
import '../../../app/app_page.dart';
import '../../../app/services/global_key_service.dart';
import '../../../data/controller/notes_controller.dart';
import '../../../i18n/i18n.dart';
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
  }

  // --- Fonctions de réordonnancement ---
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final Note note = _filteredNotes.removeAt(oldIndex);
      _filteredNotes.insert(newIndex, note);

      // Déclencher l'enregistrement du nouvel ordre
      _updateNoteOrderInDatabase();
    });
  }

  Future<void> _updateNoteOrderInDatabase() async {
    List<String> noteGuidInNewOrder = _filteredNotes.map((note) => note.guid).toList();
    await JwLifeApp.userdata.reorderNotesInTag(_tag.id, noteGuidInNewOrder);
  }

  @override
  Widget build(BuildContext context) {
    _filteredNotes = context.watch<NotesController>().getNotesFromTagId(_tag.id);

    return AppPage(
      appBar: JwLifeAppBar(
        title: _tag.name,
        subTitle: i18n().label_tag_notes(_filteredNotes.length),
        actions: [
          IconTextButton(
            icon: Icon(JwIcons.note_plus),
            onPressed: (BuildContext context) async {
              final notesController = context.watch<NotesController>();
              Note note = await notesController.addNote(tagsIds: [_tag.id]);
              await showPage(NotePage(note: note));
            },
          ),
          IconTextButton(
            icon: Icon(JwIcons.pencil),
            onPressed: (BuildContext context) async {
              Tag? updatedCategory = await showEditTagDialog(context, _tag);
              if (updatedCategory != null) {
                setState(() {
                  _tag = updatedCategory;
                });
              }
            },
          ),
          IconTextButton(
            icon: Icon(JwIcons.tag_crossed),
            onPressed: (BuildContext context) async {
              bool? tagDeleted = await showDeleteTagDialog(context, _tag);
              if (tagDeleted == true) {
                GlobalKeyService.jwLifePageKey.currentState?.handleBack(context);
              }
            },
          ),
        ],
      ),
      body: ReorderableListView.builder(
        onReorder: _onReorder,
        // Physics qui empêche les sauts
        physics: ClampingScrollPhysics(),
        // Padding pour éviter les problèmes de bords
        padding: EdgeInsets.zero,
        itemCount: _filteredNotes.length,
        itemBuilder: (context, index) {
          final note = _filteredNotes[index];

          if (note.guid == '') {
            return const SizedBox.shrink(key: ValueKey('note_hidden'));
          }

          // Wrapping dans AutomaticKeepAliveClientMixin via un widget custom
          return _KeepAliveNoteItem(
            key: ValueKey('note_${note.guid}'),
            note: note,
            tag: _tag,
            onUpdated: () => setState(() {}),
          );
        },
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

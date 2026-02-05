import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/controller/notes_controller.dart';
import 'package:jwlife/features/note/note_controller.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';
import 'package:provider/provider.dart';

class NoteWidget extends StatefulWidget {
  const NoteWidget({super.key});

  @override
  _NoteWidgetState createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  String? noteGuid;

  @override
  void initState() {
    super.initState();
    noteController.addListener(_onControllerChanged);
    noteGuid = noteController.currentNoteguid;
  }

  @override
  void dispose() {
    noteController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        noteGuid = noteController.currentNoteguid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesController = context.watch<NotesController>();
    final note = notesController.getNoteByGuid(noteController.currentNoteguid ?? '');

    if (note == null || !noteController.isVisible) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        showPage(NotePage(note: note!));
      },
      child: Container(
        width: double.infinity,
        height: kNoteHeight, // Utilisation de ta constante
        decoration: BoxDecoration(
          color: note!.getColor(context),
        ),
        child: Row(
          children: [
            // Icône de gauche : Chevron Up
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                JwIcons.chevron_up,
                color: isDark ? Colors.white : Color(0xFF626262),
                size: 23,
              ),
            ),
        
            // Centre : Titre et Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (note!.title != null && note!.title!.isNotEmpty)
                      Text(
                        note!.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          height: 1.2,
                          fontSize: 12.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    Text(
                      note!.content ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Color(0xFFC9C9C9) : Color(0xFF7D7D7D),
                        height: 1.2,
                        fontSize: 11.5,
                      ),
                      textAlign: TextAlign.center,                   
                    ),
                  ],
                ),
              ),
            ),
        
            // Icône de droite : Fermer (X)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  JwIcons.x,
                  color: isDark ? Colors.white : Color(0xFF626262),
                  size: 23,
                ),
                onPressed: () {
                  noteController.hide();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
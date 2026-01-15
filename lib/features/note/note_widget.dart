import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/ui/app_dimens.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/note/note_controller.dart';
import 'package:jwlife/features/personal/pages/note_page.dart';

class NoteWidget extends StatefulWidget {
  const NoteWidget({super.key});

  @override
  _NoteWidgetState createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  Note? note;

  @override
  void initState() {
    super.initState();
    noteController.addListener(_onControllerChanged);
    note = noteController.note;
  }

  @override
  void dispose() {
    noteController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        note = noteController.note;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (note == null || !noteController.isVisible) {
      return const SizedBox.shrink();
    }

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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                JwIcons.chevron_up,
                color: Colors.white,
                size: 23,
              ),
            ),
        
            // Centre : Titre et Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note!.title != null && note!.title!.isNotEmpty)
                      Text(
                        note!.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.2,
                          fontSize: 12.5,
                        ),
                      ),
                    Text(
                      note!.content ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC9C9C9),
                        height: 1.2,
                        fontSize: 11.5,
                      ),
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
                icon: const Icon(
                  JwIcons.x,
                  color: Colors.white,
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
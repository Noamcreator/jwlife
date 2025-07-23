import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/userdata/note.dart';

import '../../../core/utils/utils_note_tag.dart';
import 'note_page.dart';
import 'notes_categories_page.dart';
import 'tag_page.dart';

class StudyTabView extends StatefulWidget {
  const StudyTabView({super.key,});

  @override
  _StudyTabViewState createState() => _StudyTabViewState();
}

class _StudyTabViewState extends State<StudyTabView> {
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    notes = await JwLifeApp.userdata.getNotes(limit: 4);
    setState(() {});
  }

  Widget buildEmptyMessage(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 55,
            color: Color(0xFF8e8e8e),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF8e8e8e),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionHeaderNotesTags() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              await showPage(context, NotesTagsPage());
              init();
            },
            child: Row(
              children: [
                Text(
                  'Notes et Catégories',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  JwIcons.chevron_right,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  JwIcons.tag_plus,
                  color: Theme.of(context).primaryColor,
                  size: 25,
                ),
                onPressed: () async {
                  await showAddTagDialog(context);
                  setState(() {});
                },
              ),
              IconButton(
                icon: Icon(
                  JwIcons.note_plus,
                  color: Theme.of(context).primaryColor,
                  size: 25,
                ),
                onPressed: () async {
                  Note? note = await JwLifeApp.userdata.addNote(
                    "", "", 0, [], null, null, null, null, null, null,
                  );
                  if (note != null) {
                    await showPage(context, NotePage(note: note));
                    setState(() {
                      init();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSectionHeaderPlaylist() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => showPage(context, NotesTagsPage()),
            child: Row(
              children: [
                Text(
                  'Listes de lecture',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  JwIcons.chevron_right,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),
          Icon(
            JwIcons.plus,
            color: Theme.of(context).primaryColor,
            size: 25,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Notes et Catégories
          buildSectionHeaderNotesTags(),

          // Section Tags
          JwLifeApp.userdata.tags.isEmpty
              ? buildEmptyMessage(
            JwIcons.tag,
            'Créez des catégories pour classer vos publications et vos notes.',
          )
              : // Section Tags
          JwLifeApp.userdata.tags.isEmpty
              ? buildEmptyMessage(
            JwIcons.tag,
            'Créez des catégories pour classer vos publications et vos notes.',
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                List<Widget> tagWidgets = [];
                double currentLineWidth = 0;
                int currentLine = 0;
                const double spacing = 8;
                const double maxLines = 5;

                for (var tag in JwLifeApp.userdata.tags) {
                  // Calcul approximatif de la largeur du bouton
                  final textPainter = TextPainter(
                    text: TextSpan(
                      text: tag.name,
                      style: TextStyle(fontSize: 13),
                    ),
                    textDirection: TextDirection.ltr,
                  );
                  textPainter.layout();
                  double buttonWidth = textPainter.width + 18 + 16; // padding horizontal + marge

                  // Vérifier si le bouton rentre sur la ligne actuelle
                  if (currentLineWidth + buttonWidth > constraints.maxWidth) {
                    currentLine++;
                    currentLineWidth = 0;

                    // Arrêter si on dépasse 5 lignes
                    if (currentLine >= maxLines) {
                      break;
                    }
                  }

                  currentLineWidth += buttonWidth + spacing;

                  tagWidgets.add(
                    ElevatedButton(
                      onPressed: () async {
                        await showPage(context, TagPage(tag: tag));
                        init();
                      },
                      style: ButtonStyle(
                        minimumSize: MaterialStateProperty.all<Size>(Size(0, 16)),
                        padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                          EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        ),
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF292929)
                              : Color(0xFFd8d8d8),
                        ),
                        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      child: Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF8b9fc1)
                              : Color(0xFF4a6da7),
                        ),
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: -7,
                  children: tagWidgets,
                );
              },
            ),
          ),

          SizedBox(height: 10),

          // Section Notes
          notes.isEmpty
              ? buildEmptyMessage(
            JwIcons.note_plus,
            'Vos notes apparaîtront ici.',
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: notes.length,
              itemBuilder: (BuildContext context, int index) {
                Note note = notes[index];
                return Container(
                  width: double.infinity,
                  height: 45,
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: note.getColor(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[850]!
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: TextButton(
                    onPressed: () async {
                      await showPage(context, NotePage(note: note));
                      init();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.transparent,
                      overlayColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        note.title != null ? note.title!.trim().isNotEmpty ? note.title! : note.content ?? '' : '',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: note.title != null ? note.title!.trim().isNotEmpty ? FontWeight.w600 : FontWeight.normal : FontWeight.normal,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            )
          ),

          SizedBox(height: 32),

          // Header Listes de lectures
          buildSectionHeaderPlaylist(),

          // Section Listes de lectures vide
          buildEmptyMessage(
            JwIcons.plus,
            'Aucune liste de lecture.',
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }
}

Color darken(Color color, [double amount = .1]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

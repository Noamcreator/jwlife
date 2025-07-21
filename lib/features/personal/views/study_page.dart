import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/views/note_page.dart';
import 'package:jwlife/features/personal/views/notes_categories_page.dart';

import 'tag_page.dart';

class StudyTabView extends StatefulWidget {
  const StudyTabView({super.key,});

  @override
  _StudyTabViewState createState() => _StudyTabViewState();
}

class _StudyTabViewState extends State<StudyTabView> {
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
      padding: const EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => showPage(context, NotesTagsView()),
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
              Icon(
                JwIcons.tag_plus,
                color: Theme.of(context).primaryColor,
                size: 25,
              ),
              SizedBox(width: 15),
              Icon(
                JwIcons.note_plus,
                color: Theme.of(context).primaryColor,
                size: 25,
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
            onTap: () => showPage(context, NotesTagsView()),
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
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: JwLifeApp.userdata.tags.map((tag) {
                return ElevatedButton(
                  onPressed: () {
                    showPage(context, TagView(tag: tag));
                  },
                  style: ButtonStyle(
                    minimumSize: MaterialStateProperty.all<Size>(Size(0, 36)),
                    padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    backgroundColor: MaterialStateProperty.all<Color>(
                      Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF292929)
                          : Color(0xFFd8d8d8),
                    ),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF8b9fc1)
                          : Color(0xFF4a6da7),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: 16),

          // Section Notes
          JwLifeApp.userdata.notes.isEmpty
              ? buildEmptyMessage(
            JwIcons.note_plus,
            'Vos notes apparaîtront ici.',
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: JwLifeApp.userdata.notes.length,
              itemBuilder: (BuildContext context, int index) {
                final note = JwLifeApp.userdata.notes[index];
                return Container(
                  width: double.infinity,
                  height: 50,
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Note.getColor(context, note['ColorIndex'] ?? 0),
                  ),
                  child: TextButton(
                    onPressed: () {
                      showPage(context, NoteView(note: note));
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        note['Title'],
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 32),

          // Header Listes de lectures
          buildSectionHeaderPlaylist(),

          // Section Listes de lectures vide
          buildEmptyMessage(
            Icons.add,
            'Aucune liste de lecture.',
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }
}
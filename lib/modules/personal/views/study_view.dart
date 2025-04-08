import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/userdata/Note.dart';
import 'package:jwlife/modules/personal/views/note_view.dart';
import 'package:jwlife/modules/personal/views/notes_categories_view.dart';

import 'category_view.dart';

class StudyTabView extends StatefulWidget {

  const StudyTabView({Key? key,}) : super(key: key);

  @override
  _StudyTabViewState createState() => _StudyTabViewState();
}

class _StudyTabViewState extends State<StudyTabView> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              showPage(context, NotesCategoryView());
            },
            child: Row(
              children: [
                Text(
                  'Notes et Catégories',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(JwIcons.chevron_right),
              ],
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 215,
            child: ListView(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: -5,
                  children: JwLifeApp.userdata.categories.map((category) {
                    return ElevatedButton(
                      onPressed: () {
                        showPage(context, CategoryView(category: category));
                      },
                      style: ButtonStyle(
                        minimumSize: MaterialStateProperty.all<Size>(
                          Size(0, 30),
                        ),
                        padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                          EdgeInsets.symmetric(horizontal: 20),
                        ),
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF292929)
                              : Color(0xFFd8d8d8),
                        ),
                      ),
                      child: Text(
                        category['Name'],
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
              ],
            ),
          ),
          SizedBox(height: 20),
          Container(
            height: 215,
            child: JwLifeApp.userdata.notes.isEmpty
                ? Center(child: Text('No notes available'))
                : ListView.builder(
              itemCount: 4,
              itemBuilder: (BuildContext context, int index) {
                Map<String, dynamic> note = JwLifeApp.userdata.notes[index];
                return Container(
                  width: double.infinity,
                  height: 43,
                  margin: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Note.getColor(
                      context,
                      note['ColorIndex'] ?? 0,
                    ),
                  ),
                  child: TextButton(
                    onPressed: () {
                      showPage(context, NoteView(note: note));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          note['Title'],
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 5),
          InkWell(
            onTap: () {
              // Logique pour accéder aux listes de lectures
            },
            child: Row(
              children: [
                Text(
                  'Listes de lectures',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(JwIcons.chevron_right),
              ],
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}

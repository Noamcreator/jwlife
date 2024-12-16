import 'package:flutter/material.dart';

import '../../../jwlife.dart';
import '../../../userdata/Note.dart';
import '../../personal_page/category_page.dart';
import '../../personal_page/note_page.dart';

class PublicationNotesView extends StatefulWidget {
  final int docId;

  PublicationNotesView({Key? key, required this.docId}) : super(key: key);

  @override
  _PublicationNotesViewState createState() => _PublicationNotesViewState();
}

class _PublicationNotesViewState extends State<PublicationNotesView> {
  late List<Map<String, dynamic>> _notes = [];
  late int lang;

  @override
  void initState() {
    super.initState();
    update();
  }

  Future<void> update() async {
    List<Map<String, dynamic>> notes = await _loadLanguageAndFetchNotes();
    setState(() {
      _notes = notes;
    });
  }

  Future<List<Map<String, dynamic>>> _loadLanguageAndFetchNotes() async {
    lang = JwLifeApp.currentLanguage.id;
    return JwLifeApp.userdata.getNotesFromDocId(widget.docId, lang);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _notes.isEmpty ? Column(
        mainAxisAlignment: MainAxisAlignment.start, // Aligner en haut
        crossAxisAlignment: CrossAxisAlignment.center, // Centrer horizontalement
        children: [
          SizedBox(height: 25), // Espace en haut
          Center(child: Text(
            "Aucun contenu d'étude",
            style: TextStyle(fontSize: 25),
          ),
          ),
        ],
      ) :
      Scrollbar(
        interactive: true,
        child: ListView.builder(
          itemCount: _notes.length,
          itemBuilder: (context, index) {
            final note = _notes[index];
            List<String> categoriesId = note['CategoriesId'] == null ? [] : note['CategoriesId'].split(',');
            List<String> categoriesName = note['CategoriesName'] == null ? [] : note['CategoriesName'].split(',');
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                      return NotePage(
                        note: note,
                      );
                    },
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                ).then(
                        (value) => setState(() {
                      update();
                    }));
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]!
                      : Colors.grey[300]!,
                      width: 1),
                  color: Note.getColor(context, note['NoteColorIndex'] == null ? 0 : note['NoteColorIndex']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Note.dateTodayToCreated(note['NoteLastModified']),
                      style: TextStyle(fontSize: 10),
                    ),
                    Text(
                      note['NoteTitle'] ?? '',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      note['NoteContent'] ?? '',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 0,
                        alignment: WrapAlignment.end,
                        children: categoriesName.map((categoryName) {
                          int index = categoriesName.indexOf(categoryName);
                          Map<String, dynamic> category = {
                            "TagId": int.parse(categoriesId[index]),
                            "TagName": categoryName,
                          };
                          return ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                                    return CategoryPage(
                                      category: category,
                                    );
                                  },
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                            style: ButtonStyle(
                              minimumSize: MaterialStateProperty.all<Size>(
                                Size(0, 38),
                              ),
                              backgroundColor: MaterialStateProperty.all<Color>(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xEE1e1e1e)
                                    : Color(0xFFe8e8e8),
                              ),
                              overlayColor: MaterialStateProperty.all<Color>(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xEE404040)
                                    : Color(0xFFf8f8f8),
                              ),
                              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                                EdgeInsets.symmetric(horizontal: 20),
                              ),
                            ),
                            child: Text(categoryName,
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

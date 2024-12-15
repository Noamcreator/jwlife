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
  late Future<List<Map<String, dynamic>>> _notesFuture;
  late int lang;
  final ScrollController _scrollController = ScrollController(); // Controller pour le Slider

  @override
  void initState() {
    super.initState();
    update();
  }

  Future<void> update() async {
    setState(() {
      _notesFuture = _loadLanguageAndFetchNotes();
    });
  }

  Future<List<Map<String, dynamic>>> _loadLanguageAndFetchNotes() async {
    lang = JwLifeApp.currentLanguage.id;
    return JwLifeApp.userdata.getNotesFromDocId(widget.docId, lang);
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Assure de libérer le controller à la destruction du widget
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Column(
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
            );
          } else {
            final notes = snapshot.data!;
            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 6.0,
              radius: const Radius.circular(8),
              interactive: true,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  print('note: $note');
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
            );
          }
        },
      ),
    );
  }
}

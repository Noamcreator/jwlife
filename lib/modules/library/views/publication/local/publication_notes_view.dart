import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/userdata/Note.dart';
import 'package:jwlife/modules/library/views/publication/local/document/document.dart';
import 'package:jwlife/modules/personal/views/category_view.dart';
import 'package:jwlife/modules/personal/views/note_view.dart';

class PublicationNotesView extends StatefulWidget {
  final Document document;

  PublicationNotesView({Key? key, required this.document}) : super(key: key);

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
    lang = JwLifeApp.settings.currentLanguage.id;
    return widget.document.notes;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 70),
          _notes.isEmpty
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 50),
              Center(
                child: Text(
                  "Aucun contenu d'étude",
                  style: TextStyle(fontSize: 25),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          )
              : Expanded(
            child: Scrollbar(
              interactive: true,
              child: ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = Map<String, dynamic>.from(_notes[index]);
                  List<String> categoriesId = note['CategoriesId'] == null ? [] : note['CategoriesId'].split(',');
                  List<String> categoriesName = note['CategoriesName'] == null ? [] : note['CategoriesName'].split(',');
                  return GestureDetector(
                    onTap: () {
                      showPage(context, NoteView(note: note)).then(
                            (value) => setState(() {
                          update();
                        }),
                      );
                    },
                    onLongPress: () {
                      // Afficher le menu lors d'un appui long
                      _showPopupMenu(context, note);
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]!
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        color: Note.getColor(context, note['ColorIndex'] ?? 0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Utilisation de Flexible pour permettre au titre de s'étendre sur plusieurs lignes
                              Flexible(
                                child: Text(
                                  note['Title'] ?? '',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  maxLines: 2, // Limiter le nombre de lignes si nécessaire
                                  overflow: TextOverflow.ellipsis, // Utiliser "..." si le titre dépasse
                                ),
                              ),
                              PopupMenuButton<int>(
                                icon: Icon(Icons.more_vert, color: Color(0xFFd8d8d8)),
                                itemBuilder: (context) => [
                                  PopupMenuItem<int>(
                                    value: 0,
                                    child: ListTile(
                                      title: Text('Supprimer'),
                                      onTap: () {
                                        JwLifeApp.userdata.deleteNote(note);
                                      },
                                    ),
                                  ),
                                  PopupMenuItem<int>(
                                    value: 1,
                                    child: ListTile(
                                      title: Text('Changer la couleur'),
                                      onTap: () {},
                                      trailing: DropdownButton<int>(
                                        value: note['ColorIndex'] ?? 0,
                                        onChanged: (int? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              note['ColorIndex'] = newValue;
                                            });
                                            JwLifeApp.userdata.updateNote(note, note['Title'], note['Content'], colorIndex: newValue);
                                          }
                                        },
                                        items: List.generate(7, (index) {
                                          return DropdownMenuItem<int>(
                                            value: index,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              color: Note.getColor(context, index),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            note['Content'] ?? '',
                            style: TextStyle(fontSize: 19),
                          ),
                          if (categoriesId.isNotEmpty)
                            SizedBox(height: 8),
                          if (categoriesId.isNotEmpty)
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
                                    "Name": categoryName,
                                  };
                                  return ElevatedButton(
                                    onPressed: () async {
                                      await showPage(context, CategoryView(category: category)).then((value) => setState(() {
                                        update();
                                      }));
                                    },
                                    style: ButtonStyle(
                                      minimumSize: MaterialStateProperty.all<Size>(Size(0, 38)),
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
                                    child: Text(
                                      categoryName,
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
          ),
        ],
      ),
    );
  }

  void _showPopupMenu(BuildContext context, Map<String, dynamic> note) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(300, 130, 0, 0), // Position du menu
      items: [
        PopupMenuItem<int>(
          value: 0,
          child: Text('Supprimer'),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: Text('Changer la couleur'),
        ),
      ],
    ).then((value) {
      if (value != null) {
        if (value == 0) {
          _deleteNote(note);
        } else if (value == 1) {
          _changeNoteColor(note);
        }
      }
    });
  }

  void _deleteNote(Map<String, dynamic> note) {
    // Implémenter la logique de suppression de la note ici
    print("Note supprimée : ${note['Title']}");
  }

  void _changeNoteColor(Map<String, dynamic> note) {
    // Implémenter la logique de changement de couleur de la note ici
    print("Changer la couleur de la note : ${note['Title']}");
  }
}

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_note_tag.dart';
import 'package:jwlife/data/userdata/Note.dart';
import 'note_view.dart';

class CategoryView extends StatefulWidget {
  final Map<String, dynamic> category;

  CategoryView({super.key, required this.category});

  @override
  _CategoryViewState createState() => _CategoryViewState();
}

class _CategoryViewState extends State<CategoryView> {
  late Map<String, dynamic> _category;
  List<Map<String, dynamic>> _filteredNotes = [];

  @override
  void initState() {
    super.initState();
    _category = Map<String, dynamic>.from(widget.category);
    notesByCategory();
  }

  Future<void> notesByCategory() async {
    // Fetch notes by category first
    List<Map<String, dynamic>> notes = await JwLifeApp.userdata.getNotesByCategory(_category['TagId']);

    // Now update the state with the fetched notes
    setState(() {
      _filteredNotes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _category);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_category['Name']),
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
              var note = await JwLifeApp.userdata.addNote("", "", null, [_category['TagId']], null, null, null, null);
              showPage(context, NoteView(note: note));
            },
          ),
          IconButton(
            icon: Icon(JwIcons.pencil),
            onPressed: () async {
              // Utiliser await à l'extérieur du setState
              var updatedCategory = await showEditTagDialog(context, _category);

              // Si la catégorie a été mise à jour, on applique le setState
              if (updatedCategory != null) {
                setState(() {
                  _category = updatedCategory;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(JwIcons.tag_crossed),
            onPressed: () async {
               await showDeleteTagDialog(context, _category).then((value) => setState(() {}));
            },
          ),
        ],
      ),
      body: Scrollbar(
        interactive: true,
        child: ListView.builder(
          itemCount: _filteredNotes.length,
          itemBuilder: (context, index) {
            final note = _filteredNotes[index];

            List<String> categoriesId = note['CategoriesId'] == null ? [] : note['CategoriesId'].split(',');
            List<String> categoriesName = note['CategoriesName'] == null ? [] : note['CategoriesName'].split(',');
            return GestureDetector(
              onTap: () {
                showPage(context, NoteView(
                  note: note,
                ));
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]!
                      : Colors.grey[300]!,
                      width: 1),
                  color: Note.getColor(context, note['ColorIndex'] ?? 0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Note.dateTodayToCreated(note['LastModified']),
                      style: TextStyle(fontSize: 10),
                    ),
                    Text(
                      note['Title'] ?? '',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      note['Content'] ?? '',
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
                          // Trouver l'index de categoryName
                          int index = categoriesName.indexOf(categoryName);
                          // Créer la Map avec la conversion en int
                          Map<String, dynamic> category = {
                            "TagId": int.parse(categoriesId[index]), // Conversion en int
                            "Name": categoryName,
                          };
                          return ElevatedButton(
                            onPressed: () {
                              if (category['TagId'] != _category['TagId']) {
                                showPage(context, CategoryView(category: category));
                              }
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

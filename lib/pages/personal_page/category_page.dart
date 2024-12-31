import 'package:flutter/material.dart';
import '../../jwlife.dart';
import '../../userdata/Note.dart';
import '../../utils/icons.dart';
import 'note_page.dart';

class CategoryPage extends StatefulWidget {
  final Map<String, dynamic> category;

  CategoryPage({super.key, required this.category});

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Map<String, dynamic>> _filteredNotes = [];

  @override
  void initState() {
    super.initState();
    notesByCategory();
  }

  Future<void> notesByCategory() async {
    // Fetch notes by category first
    List<Map<String, dynamic>> notes = await JwLifeApp.userdata.getNotesByCategory(widget.category['TagId']);

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
            Navigator.pop(context, widget.category);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.category['TagName']),
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
            onPressed: () {
              // Action to perform when the add note button is pressed
            },
          ),
          IconButton(
            icon: Icon(JwIcons.tag_crossed),
            onPressed: () {
              // Action to perform when the delete category button is pressed
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
                );
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
                          // Trouver l'index de categoryName
                          int index = categoriesName.indexOf(categoryName);
                          // Créer la Map avec la conversion en int
                          Map<String, dynamic> category = {
                            "TagId": int.parse(categoriesId[index]), // Conversion en int
                            "TagName": categoryName,
                          };
                          return ElevatedButton(
                            onPressed: () {
                              if (category['TagId'] != widget.category['TagId']) {
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

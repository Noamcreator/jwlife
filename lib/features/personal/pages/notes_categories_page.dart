import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/pages/tag_page.dart';
import '../widgets/note_item_widget.dart';
import 'note_page.dart';

class NotesTagsPage extends StatefulWidget {

  const NotesTagsPage({super.key});

  @override
  _NotesTagsPageState createState() => _NotesTagsPageState();
}

class _NotesTagsPageState extends State<NotesTagsPage> {
  List<Tag> filteredTags = [];
  List<Note> allNotes = [];
  List<Note> filteredNotes = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    List<Note> notes = await JwLifeApp.userdata.getNotes();

    setState(() {
      filteredTags = JwLifeApp.userdata.tags;
      allNotes = notes;
      filteredNotes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Notes et Catégories"),
            Text(
              '${filteredNotes.length} notes et ${filteredTags.length} catégories',
              style: TextStyle(fontSize: 12),
              maxLines: 2,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(JwIcons.note_plus),
            onPressed: () async {
              Note? note = await JwLifeApp.userdata.addNote("", "", 0, [], null, null, null, null, null, null);
              if (note != null) {
                await showPage(NotePage(note: note));
                setState(() {
                  filteredNotes.insert(0, note);
                });
              }
            },
          ),
          IconButton(
            icon: Icon(JwIcons.tag_plus),
            onPressed: () async {
              await showAddTagDialog(context, false);
              setState(() {
                filteredTags = JwLifeApp.userdata.tags;
              });
            },
          ),
          IconButton(
            icon: Icon(JwIcons.arrow_circular_left_clock),
            onPressed: () {
              History.showHistoryDialog(context);
            },
          ),
    ],
      ),
      body: Scrollbar(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      filteredTags = JwLifeApp.userdata.tags.where((tag) => tag.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
                      filteredNotes = allNotes.where((note) =>
                      (note.title != null && note.title!.toLowerCase().contains(searchQuery.toLowerCase())) ||
                          (note.content != null && note.content!.toLowerCase().contains(searchQuery.toLowerCase()))
                      ).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int maxButtons = 8; // Nombre maximum de boutons affichables
                    List<Tag> visibleCategories = filteredTags.take(maxButtons).toList();

                    // Si le nombre de catégories filtrées dépasse le maximum, ajouter le bouton "Afficher plus"
                    if (filteredTags.length > maxButtons) {
                      //visibleCategories.add({'Name': 'Afficher plus'});
                    }

                    return Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: -5,
                          children: visibleCategories.map((category) {
                            if (category.name == 'Afficher plus') {
                              return GestureDetector(
                                onTap: () {
                                  // Afficher toutes les catégories
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Toutes les catégories'),
                                        content: SingleChildScrollView(
                                          child: ListBody(
                                            children: JwLifeApp.userdata.tags.map((tag) {
                                              return ListTile(
                                                title: Text(tag.name),
                                                onTap: () {
                                                  showPage(TagPage(tag: tag));
                                                },
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            child: Text('Fermer'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      'Afficher toutes les catégories (${JwLifeApp.userdata.tags.length})',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ElevatedButton(
                              onPressed: () async {
                                await showPage(TagPage(tag: category));
                                setState(() {
                                  filteredTags = JwLifeApp.userdata.tags;
                                });
                              },
                              style: ButtonStyle(
                                minimumSize: MaterialStateProperty.all<Size>(Size(0, 30)),
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
                                category.name,
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
                    );
                  },
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  return NoteItemWidget(
                    note: filteredNotes[index],
                    tag: null,
                    onUpdated: () => setState(() {}),
                  );
                },
                childCount: filteredNotes.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_note_tag.dart';
import 'package:jwlife/data/models/publication_category.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/data/models/userdata/tag.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/views/tag_page.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'note_page.dart';

class NotesTagsView extends StatefulWidget {

  const NotesTagsView({super.key});

  @override
  _NotesTagsViewState createState() => _NotesTagsViewState();
}

class _NotesTagsViewState extends State<NotesTagsView> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Filtrer les catégories et notes en fonction de la recherche
    List<Tag> filteredCategories = JwLifeApp.userdata.tags.where((category) {
      return category.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    List<Map<String, dynamic>> filteredNotes = JwLifeApp.userdata.notes.where((note) {
      return note['Title'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          note['Content'].toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
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
              '${filteredNotes.length} notes et ${filteredCategories.length} catégories',
              style: TextStyle(fontSize: 12),
              maxLines: 2,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(JwIcons.note_plus),
            onPressed: () async {
              var note = await JwLifeApp.userdata.addNote("", "", 0, [], null, null, null, null, null, null);
              showPage(context, NoteView(note: note));
            },
          ),
          IconButton(
            icon: Icon(JwIcons.tag_plus),
            onPressed: () async {
              showAddTagDialog(context);
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
                    List<Tag> visibleCategories = filteredCategories.take(maxButtons).toList();

                    // Si le nombre de catégories filtrées dépasse le maximum, ajouter le bouton "Afficher plus"
                    if (filteredCategories.length > maxButtons) {
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
                                                  showPage(context, TagPage(tag: tag));
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
                              onPressed: () {
                                showPage(context, TagPage(tag: category));
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
                  final note = filteredNotes[index];
                  List<String> categoriesId = note['TagsId']?.split(',') ?? [];
                  List<String> categoriesName = [];

                  return GestureDetector(
                    onTap: () {
                      showPage(context, NoteView(note: note));
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]!
                              : Colors.grey[300]!,
                          width: 1,
                        ),
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
                        SizedBox(
                          height: 100, // Limite de hauteur pour le contenu
                          child: Text(
                            note['Content'] ?? '',
                            style: TextStyle(fontSize: 16),
                            maxLines: 4, // Limite à 4 lignes
                            overflow: TextOverflow.ellipsis, // Affiche "..." si dépassement
                          ),
                        ),
                        SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            double availableWidth = constraints.maxWidth; // Largeur disponible
                            double buttonWidth = 100; // Largeur approximative d'un bouton (ajuste si nécessaire)
                            int maxCategories = (availableWidth / buttonWidth).floor(); // Nombre max de catégories affichables

                            List<String> visibleCategories = categoriesName.take(maxCategories).toList(); // On affiche seulement celles qui tiennent

                            return Wrap(
                              spacing: 8,
                              children: visibleCategories.map((categoryName) {
                                int index = categoriesName.indexOf(categoryName);
                                Tag tag = Tag.fromMap({
                                  "TagId": int.parse(categoriesId[index]),
                                  "Type": 1,
                                  "Name": categoryName,
                                });

                                return ElevatedButton(
                                  onPressed: () {
                                    showPage(context, TagPage(tag: tag));
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
                            );
                          },
                        ),
                        Divider(
                          thickness: 1,
                          color: Colors.grey,
                        ),
                        InkWell(
                          onTap: () {
                            showDocumentView(context, note['DocumentId'], note['MepsLanguage']);
                          },
                          child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: note['ShortTitle'] == null ? Container() : Row(
                                children: [
                                  ImageCachedWidget(
                                    imageUrl: 'https://app.jw-cdn.org/catalogs/publications/${note['ImageSqr']}',
                                    pathNoImage: PublicationCategory.all.firstWhere((category) => category.id == note['PublicationTypeId']).image,
                                    height: 40,
                                    width: 40,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded( // ✅ Ajout pour limiter la largeur du texte
                                    child: Text(
                                      note['ShortTitle'] ?? 'Publication',
                                      style: TextStyle(color: Colors.grey),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                          ),
                        ),
                      ],
                    ),
                  ),
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


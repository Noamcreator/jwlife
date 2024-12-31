import 'package:flutter/material.dart';
import '../../jwlife.dart';
import '../../userdata/Note.dart';
import '../../utils/icons.dart';
import 'category_page.dart';
import 'note_page.dart';

class NotesCategoryPage extends StatefulWidget {
  NotesCategoryPage({
    super.key,
  });

  @override
  _NotesCategoryPageState createState() => _NotesCategoryPageState();
}

class _NotesCategoryPageState extends State<NotesCategoryPage> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Filtrer les catégories et notes en fonction de la recherche
    List<Map<String, dynamic>> filteredCategories = JwLifeApp.userdata.categories.where((category) {
      return category['TagName'].toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    List<Map<String, dynamic>> filteredNotes = JwLifeApp.userdata.notes.where((note) {
      return note['NoteTitle'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          note['NoteContent'].toLowerCase().contains(searchQuery.toLowerCase());
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
              // Appeler la fonction addNote et attendre qu'elle se termine
              var note = await JwLifeApp.userdata.addNote("Note", "Ceci est une nouvelle note", 2, [28], null, null, null, null);

              // Naviguer vers la page de la note après l'ajout
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NotePage(
                          note: note, // Vous devrez ajuster cela selon la structure de votre page de note
                      )
                  )
              );
            },
          ),
          IconButton(
            icon: Icon(JwIcons.pencil),
            onPressed: () {
              // Logic for renaming the category can go here
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
              child: Container(
                height: 150,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int maxButtons = 8; // Nombre maximum de boutons affichables
                    List<Map<String, dynamic>> visibleCategories = filteredCategories.take(maxButtons).toList();

                    // Si le nombre de catégories filtrées dépasse le maximum, ajouter le bouton "Afficher plus"
                    if (filteredCategories.length > maxButtons) {
                      visibleCategories.add({'TagName': 'Afficher plus'});
                    }

                    return Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: -5,
                          children: visibleCategories.map((category) {
                            if (category['TagName'] == 'Afficher plus') {
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
                                            children: JwLifeApp.userdata.categories.map((cat) {
                                              return ListTile(
                                                title: Text(cat['TagName']),
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => CategoryPage(
                                                        category: cat,
                                                      ),
                                                    ),
                                                  );
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
                                      'Afficher toutes les catégories (${JwLifeApp.userdata.categories.length})',
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
                                category['TagName'],
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
                  List<String> categoriesId = note['CategoriesId']?.split(',') ?? [];
                  List<String> categoriesName = note['CategoriesName']?.split(',') ?? [];

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
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]!
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        color: Note.getColor(context, note['NoteColorIndex'] ?? 0),
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
                            child: Container(
                              constraints: BoxConstraints(
                                maxHeight: 50, // Limitez la hauteur du conteneur
                                maxWidth: MediaQuery.of(context).size.width * 0.8, // Limite la largeur à 80% de l'écran
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 0,
                                  alignment: WrapAlignment.end,
                                  children: categoriesName.map((categoryName) {
                                    int index = categoriesName.indexOf(categoryName);
                                    Map<String, dynamic> category = {
                                      "TagId": int.parse(categoriesId[index]), // Conversion en int
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


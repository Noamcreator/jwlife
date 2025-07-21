import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/databases/publication_category.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/utils/utils.dart';

class NoteView extends StatefulWidget {
  final Map<String, dynamic> note;

  const NoteView({super.key, required this.note});

  @override
  _NoteViewState createState() => _NoteViewState();
}

class _NoteViewState extends State<NoteView> {
  late Map<String, dynamic> _note;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _categoriesController;

  @override
  void initState() {
    super.initState();
    _note = Map<String, dynamic>.from(widget.note); // Copie mutable

    _titleController = TextEditingController(text: _note['Title']);
    _titleController.addListener(() {
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text);
    });

    _contentController = TextEditingController(text: _note['Content']);
    _contentController.addListener(() {
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text);
    });

    _categoriesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoriesController.dispose();
    super.dispose();
  }

  /*
  List<Map<String, dynamic>> _filteredCategories(String query) {
    return widget.userdata.getCategories().where((category) => category.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

   */

  void _addCategory(Map<String, dynamic> newCategory) {
    /*
    setState(() {
      if (newCategory['Name'].isNotEmpty) {
        widget.note.categories.add(newCategory);
      }
      _categoriesController.clear();
      _textFieldFocus.unfocus();

      FocusScope.of(context).unfocus();
    });

     */
  }

  /*
  Widget _buildCategoryDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_categoriesController.text.isNotEmpty)
          //List<Map<String, dynamic>> categories = await widget.userdata.getCategories();
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: JwLibraryApp.userdata.getCategories().map((category) {
                return ListTile(
                  title: Text(category),
                  onTap: () {
                    _addCategory(category);
                  },
                );
              }).toList(),
            ),
          ),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoriesController,
                decoration: InputDecoration(
                  labelText: 'Écrire une catégorie ou en choisir une',
                ),
                onChanged: (text) {
                  setState(() {}); // Actualiser l'affichage des suggestions lorsque le texte change
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                if(_categoriesController.text.isNotEmpty)
                {
                  //_addCategory(_categoriesController as Category);
                }
              },
            ),
          ],
        ),


      ],
    );
  }

   */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Note.getColor(context, _note['ColorIndex'] ?? 0),
      appBar: AppBar(
        backgroundColor: Note.getColor(context, _note['ColorIndex'] ?? 0),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  title: Text('Supprimer'),
                  onTap: () {
                    JwLifeApp.userdata.deleteNote(_note);
                    Navigator.pop(context); // Fermer le PopupMenuButton
                    Navigator.pop(context); // Fermer la vue de la note
                  },
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  title: Text('Changer la couleur'),
                  onTap: () {},
                  trailing: DropdownButton<int>(
                    value: _note['ColorIndex'] ?? 0,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        _note['ColorIndex'] = newValue;
                        JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text, colorIndex: newValue).then((updatedNote) {
                          setState(() {
                            _note = updatedNote;
                          });
                        }).catchError((error) {
                          printTime("Erreur lors de la mise à jour de la note : $error");
                        });
                      }
                    },
                    items: List.generate(7, (index) {
                      return DropdownMenuItem(
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
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                maxLines: null,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Titre',
                  hintStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF757575)),
                )
              ),
              SizedBox(height: 10),
              TextField(
                controller: _contentController,
                maxLines: null,
                style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Note',
                    hintStyle: TextStyle(fontSize: 22, color: Color(0xFF757575)),
                )
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: _note['CategoriesName'] == null ? [] : _note['CategoriesName'].split(',').map<Widget>((category) {
                  return Chip(
                    label: Text(category),
                    onDeleted: () {
                      setState(() {
                        // Supprimer la catégorie de la liste
                        _note['CategoriesName'] = _note['CategoriesName'] == null ? [] : _note['CategoriesName'].split(',').toList()..remove(category);
                      });
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 10),
              // Ajouter un séparateur en bas
              Divider(
                thickness: 1,
                color: Colors.grey,
              ),
              InkWell(
                onTap: () {
                  showDocumentView(context, widget.note['DocumentId'], widget.note['MepsLanguage']);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: widget.note['ShortTitle'] == null ? Container() : Row(
                    children: [
                      ImageCachedWidget(
                        imageUrl: 'https://app.jw-cdn.org/catalogs/publications/${widget.note['ImageSqr']}',
                        pathNoImage: PublicationCategory.all.firstWhere((category) => category.id == widget.note['PublicationTypeId']).image,
                        height: 40,
                        width: 40,
                      ),
                      SizedBox(width: 8),
                      Text(widget.note['ShortTitle'] ?? 'Publication', style: TextStyle(color: Colors.grey)),
                    ],
                  )
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../jwlife.dart';
import '../../userdata/Note.dart';


class NotePage extends StatefulWidget {
  final Map<String, dynamic> note;

  const NotePage({super.key, required this.note});

  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late Map<String, dynamic> _note;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _categoriesController;

  @override
  void initState() {
    super.initState();
    _note = Map<String, dynamic>.from(widget.note); // Copie mutable

    _titleController = TextEditingController(text: _note['NoteTitle']);
    _titleController.addListener(() {
      _note['NoteTitle'] = _titleController.text;
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text, _note['NoteColorIndex'], []);
    });

    _contentController = TextEditingController(text: _note['NoteContent']);
    _contentController.addListener(() {
      _note['NoteContent'] = _contentController.text;
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text, _note['NoteColorIndex'], []);
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
      backgroundColor: Note.getColor(context, _note['NoteColorIndex'] == null ? 0 : _note['NoteColorIndex']),
      appBar: AppBar(
        backgroundColor: Note.getColor(context, _note['NoteColorIndex'] == null ? 0 : _note['NoteColorIndex']),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  title: Text('Supprimer'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  title: Text('Changer la couleur'),
                  onTap: () {
                  },
                  trailing: DropdownButton<int>(
                    value: _note['NoteColorIndex'] == null ? 0 : _note['NoteColorIndex'], // Valeur sélectionnée par défaut
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        _note['NoteColorIndex'] = newValue;
                        JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text, newValue, []).then((updatedNote) {
                          setState(() {
                            _note = updatedNote;
                          });
                        }).catchError((error) {
                          print("Erreur lors de la mise à jour de la note : $error");
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
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                maxLines: null,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              TextField(
                controller: _contentController,
                maxLines: null,
                style: TextStyle(fontSize: 20),
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
              //_buildCategoryDropdown(context),
            ],
          ),
        ),
      ),
    );
  }
}

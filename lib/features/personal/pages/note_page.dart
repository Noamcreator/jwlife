import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/widgets/note_item_widget.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/icons.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/userdata/tag.dart';

class NotePage extends StatefulWidget {
  final Note note;

  const NotePage({super.key, required this.note});

  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late Note _note;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _categoriesController;
  late Future<Map<String, dynamic>> _dataFuture;

  final GlobalKey _inputKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  bool _showCategoryInput = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;

    _titleController = TextEditingController(text: _note.title);
    _titleController.addListener(() {
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text);
    });

    _contentController = TextEditingController(text: _note.content);
    _contentController.addListener(() {
      JwLifeApp.userdata.updateNote(_note, _titleController.text, _contentController.text);
    });

    _categoriesController = TextEditingController();
    _categoriesController.addListener(() {
      _removeOverlay();
      _showOverlay();
    });

    _dataFuture = NoteItemWidget.resolveNoteDependencies(widget.note);
  }

  @override
  void dispose() {
    _removeOverlay();
    _titleController.dispose();
    _contentController.dispose();
    _categoriesController.dispose();
    super.dispose();
  }

  List<Tag> _getFilteredTags(String query) {
    final tags = JwLifeApp.userdata.tags;
    return tags
        .where((tag) =>
    tag.name.toLowerCase().contains(query.toLowerCase()) &&
        !_note.tagsId.contains(tag.id))
        .toList();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    if (!_showCategoryInput || _categoriesController.text.trim().isEmpty) return;

    final renderBox = _inputKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final filteredTags = _getFilteredTags(_categoriesController.text).toList();
    final showAdd = _categoriesController.text.trim().isNotEmpty &&
        !filteredTags.any((tag) =>
        tag.name.toLowerCase() ==
            _categoriesController.text.trim().toLowerCase());

    // ⚠️ Supprime l’ancien overlay
    _removeOverlay();

    final totalItemCount = (showAdd ? 1 : 0) + filteredTags.length;
    final visibleCount = totalItemCount.clamp(0, 5);
    final itemHeight = 48.0;
    final spacing = 12.0;

    final totalHeight = visibleCount * itemHeight + spacing;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy - totalHeight, // 👈 décale VERS LE HAUT
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.grey[900],
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: itemHeight * 5),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: (showAdd ? 1 : 0) + filteredTags.length,
              itemBuilder: (context, index) {
                // Si showAdd est activé et que l'index est 0 → bouton "Ajouter"
                if (showAdd && index == 0) {
                  return ListTile(
                    dense: true,
                    leading: Icon(JwIcons.plus),
                    title: Text(
                      "Ajouter la catégorie '${_categoriesController.text.trim()}'",
                      style: TextStyle(fontSize: 15),
                    ),
                    onTap: () async {
                      Tag? tag = await JwLifeApp.userdata
                          .addTag(_categoriesController.text, 1);
                      if (tag != null) {
                        await JwLifeApp.userdata
                            .addTagToNoteWithGuid(_note.guid, tag.id);
                        setState(() {
                          _note.tagsId.add(tag.id);
                          _categoriesController.clear();
                          _showCategoryInput = false;
                        });
                        _removeOverlay();
                      }
                    },
                  );
                }

                // Sinon → élément de filteredTags
                final tag = filteredTags[showAdd ? index - 1 : index];
                return ListTile(
                  dense: true,
                  title: Text(tag.name, style: TextStyle(fontSize: 15)),
                  onTap: () async {
                    await JwLifeApp.userdata
                        .addTagToNoteWithGuid(_note.guid, tag.id);
                    setState(() {
                      _note.tagsId.add(tag.id);
                      _categoriesController.clear();
                      _showCategoryInput = false;
                    });
                    _removeOverlay();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context, debugRequiredFor: widget).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    Color color = Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF292929)
        : Color(0xFFe9e9e9);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _note.getColor(context),
      appBar: AppBar(
        backgroundColor: _note.getColor(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            GlobalKeyService.jwLifePageKey.currentState?.handleBack(context, result: _note);
          }
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  title: Text('Supprimer'),
                  onTap: () async {
                    await JwLifeApp.userdata.deleteNote(_note);
                    _note.noteId = -1;
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  title: Text('Changer la couleur'),
                  onTap: () {},
                  trailing: DropdownButton<int>(
                    dropdownColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF292929)
                        : Color(0xFFf1f1f1),
                    value: _note.colorIndex,
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        _note.colorIndex = newValue;
                        JwLifeApp.userdata.updateNote(_note, _titleController.text,
                            _contentController.text,
                            colorIndex: newValue)
                            .then((updatedNote) {
                          setState(() {
                            _note = updatedNote;
                          });
                        });
                      }
                    },
                    items: List.generate(7, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Container(
                          width: 20,
                          height: 20,
                          color: _note.getColor(context, colorId: index),
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    maxLines: null,
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Titre',
                      hintStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Color(0xFF757575)),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    style: TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Note',
                      hintStyle:
                      TextStyle(fontSize: 22, color: Color(0xFF757575)),
                    ),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: _note.tagsId.map<Widget>((tagId) {
                      Tag tag = JwLifeApp.userdata.tags
                          .firstWhere((tag) => tag.id == tagId);
                      return Chip(
                        shape: StadiumBorder(),
                        side: BorderSide(color: color, width: 1),
                        label: Text(tag.name, style: TextStyle(fontSize: 15)),
                        backgroundColor: color,
                        deleteIcon: Icon(JwIcons.x, size: 18),
                        onDeleted: () async {
                          await JwLifeApp.userdata
                              .removeTagFromNoteWithGuid(_note.guid, tag.id);
                          setState(() {
                            _note.tagsId.remove(tagId);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  if (_showCategoryInput)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: _inputKey,
                            controller: _categoriesController,
                            autofocus: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onSubmitted: (value) async {
                              if (value.trim().isNotEmpty) {
                                Tag? tag = await JwLifeApp.userdata
                                    .addTag(value, 1);
                                if (tag != null) {
                                  await JwLifeApp.userdata
                                      .addTagToNoteWithGuid(
                                      _note.guid, tag.id);
                                  setState(() {
                                    _note.tagsId.add(tag.id);
                                    _categoriesController.clear();
                                    _showCategoryInput = false;
                                  });
                                  _removeOverlay();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showCategoryInput = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showOverlay();
                        });
                      },
                      label: Icon(JwIcons.plus,
                          size: 22,
                          color: Theme.of(context).brightness ==
                              Brightness.light
                              ? Colors.black
                              : Colors.white),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Theme.of(context).brightness ==
                                Brightness.light
                                ? Colors.black
                                : Colors.white),
                        shape: CircleBorder(),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Divider(thickness: 1, color: Colors.grey),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _dataFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return SizedBox.shrink();

                      final pub = snapshot.data!['pub'] as Publication?;
                      final docTitle = snapshot.data!['docTitle'] as String;

                      if (pub == null) return SizedBox.shrink();

                      return InkWell(
                        onTap: () {
                          if (_note.location.mepsDocumentId != null) {
                            showDocumentView(
                              context,
                              _note.location.mepsDocumentId!,
                              _note.location.mepsLanguageId!,
                              startParagraphId: _note.blockIdentifier,
                              endParagraphId: _note.blockIdentifier,
                            );
                          } else if (_note.location.bookNumber != null &&
                              _note.location.chapterNumber != null) {
                            showChapterView(
                              context,
                              _note.location.keySymbol!,
                              _note.location.mepsLanguageId!,
                              _note.location.bookNumber!,
                              _note.location.chapterNumber!,
                              firstVerseNumber: _note.blockIdentifier,
                              lastVerseNumber: _note.blockIdentifier,
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              ImageCachedWidget(
                                imageUrl: pub.imageSqr,
                                icon: pub.category.icon,
                                height: 35,
                                width: 35,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      docTitle.isEmpty
                                          ? pub.getShortTitle()
                                          : docTitle,
                                      style: TextStyle(fontSize: 16, height: 1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      docTitle.isEmpty
                                          ? pub.getSymbolAndIssue()
                                          : pub.getShortTitle(),
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1,
                                          color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

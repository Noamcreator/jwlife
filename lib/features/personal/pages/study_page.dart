import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/pages/playlist_page.dart';
import 'package:jwlife/features/personal/pages/playlists_page.dart';

import '../../../core/utils/utils_tag_dialogs.dart';
import '../../../data/models/userdata/playlist.dart';
import '../widgets/empty_message.dart';
import 'note_page.dart';
import 'notes_categories_page.dart';
import 'tag_page.dart';

class StudyTabView extends StatefulWidget {
  const StudyTabView({super.key,});

  @override
  _StudyTabViewState createState() => _StudyTabViewState();
}

class _StudyTabViewState extends State<StudyTabView> {
  List<Note> notes = [];
  List<Playlist> playlists = [];

  @override
  void initState() {
    super.initState();
    initNotes();
    initPlaylist();
  }

  Future<void> initNotes() async {
    notes = await JwLifeApp.userdata.getNotes(limit: 4);
    setState(() {});
  }

  Future<void> initPlaylist() async {
    playlists = await JwLifeApp.userdata.getPlaylists(limit: 4);
    setState(() {});
  }

  Widget buildSectionHeaderBibleReading() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {

            },
            child: Row(
              children: [
                Text(
                  'Ma lecture de la Bible',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  JwIcons.chevron_right,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  JwIcons.bible,
                  color: Theme.of(context).primaryColor,
                  size: 25,
                ),
                onPressed: () async {

                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSectionHeaderNotesTags() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              await showPage(NotesTagsPage());
              initNotes();
            },
            child: Row(
              children: [
                Text(
                  'Notes et Catégories',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  JwIcons.chevron_right,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  JwIcons.tag_plus,
                  color: Theme.of(context).primaryColor,
                  size: 25,
                ),
                onPressed: () async {
                  await showAddTagDialog(context, false);
                  setState(() {});
                },
              ),
              IconButton(
                icon: Icon(
                  JwIcons.note_plus,
                  color: Theme.of(context).primaryColor,
                  size: 25,
                ),
                onPressed: () async {
                  Note? note = await JwLifeApp.userdata.addNote(
                    "", "", 0, [], null, null, null, null, null, null,
                  );
                  if (note != null) {
                    await showPage(NotePage(note: note));
                    setState(() {
                      initNotes();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  //allowedExtensions: ['png', 'jpg', 'jpeg', 'mp4', 'm4v', '3gp', 'mov', 'mp3', 'aac', 'heic', 'webp'], // adapte si besoin

  Widget buildSectionHeaderPlaylist() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => showPage(PlaylistsPage()),
            child: Row(
              children: [
                Text(
                  'Listes de lecture',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  JwIcons.chevron_right,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),
          PopupMenuButton<void>(
            icon: Icon(
              JwIcons.plus,
              color: Theme.of(context).primaryColor,
              size: 25,
            ),
            itemBuilder: (ctx) => [
              PopupMenuItem<void>(
                child: const Text('Créer une liste de lecture'),
                onTap: () async {
                  // S’exécute après la fermeture du menu
                  await Future.delayed(Duration.zero); // évite setState pendant la fermeture
                  await showAddTagDialog(context, true);
                  playlists = await JwLifeApp.userdata.getPlaylists(limit: 4);
                  if (context.mounted) setState(() {});
                },
              ),
              PopupMenuItem<void>(
                child: const Text('Importer une liste de lecture'),
                onTap: () async {
                  await Future.delayed(Duration.zero); // idem
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    final path = result.files.single.path;
                    if (path != null) {
                      try {
                        await JwLifeApp.userdata.importPlaylistFromFile(File(path));
                        await initPlaylist();
                        if (context.mounted) {
                          showBottomMessage('Import réussi.');
                        }
                      }
                      catch (e) {
                        if (context.mounted) {
                          showBottomMessage('Échec de l’import : $e');
                        }
                      }
                    }
                  }
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Lecture de la Bible
          buildSectionHeaderBibleReading(),

          // Lecture de la bible
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  showChapterView(context, 'nwtsty', 3, 43, 3, firstVerseNumber: 16, lastVerseNumber: 16);
                },
                child: Card(
                  color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Jean 3:16",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Car Dieu a tant aimé le monde qu’il a donné son Fils unique, "
                              "afin que tout homme qui exerce la foi en lui ne soit pas détruit, "
                              "mais ait la vie éternelle.",
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
          ),

          // Header Notes et Catégories
          buildSectionHeaderNotesTags(),

          // Section Tags
          JwLifeApp.userdata.tags.isEmpty
              ? buildEmptyMessage(
            JwIcons.tag,
            'Créez des catégories pour classer vos publications et vos notes.',
          )
              : // Section Tags
          JwLifeApp.userdata.tags.isEmpty
              ? buildEmptyMessage(
            JwIcons.tag,
            'Créez des catégories pour classer vos publications et vos notes.',
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                List<Widget> tagWidgets = [];
                double currentLineWidth = 0;
                int currentLine = 0;
                const double spacing = 8;
                const double maxLines = 4;

                for (var tag in JwLifeApp.userdata.tags) {
                  // Calcul approximatif de la largeur du bouton
                  final textPainter = TextPainter(
                    text: TextSpan(
                      text: tag.name,
                      style: TextStyle(fontSize: 13),
                    ),
                    textDirection: TextDirection.ltr,
                  );
                  textPainter.layout();
                  double buttonWidth = textPainter.width + 18 + 16; // padding horizontal + marge

                  // Vérifier si le bouton rentre sur la ligne actuelle
                  if (currentLineWidth + buttonWidth > constraints.maxWidth) {
                    currentLine++;
                    currentLineWidth = 0;

                    // Arrêter si on dépasse 5 lignes
                    if (currentLine >= maxLines) {
                      break;
                    }
                  }

                  currentLineWidth += buttonWidth + spacing;

                  tagWidgets.add(
                    ElevatedButton(
                      onPressed: () async {
                        await showPage(TagPage(tag: tag));
                        initNotes();
                      },
                      style: ButtonStyle(
                        minimumSize: MaterialStateProperty.all<Size>(Size(0, 16)),
                        padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                          EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        ),
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF292929)
                              : Color(0xFFd8d8d8),
                        ),
                        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      child: Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF8b9fc1)
                              : Color(0xFF4a6da7),
                        ),
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: -7,
                  children: tagWidgets,
                );
              },
            ),
          ),

          SizedBox(height: 10),

          // Section Notes
          notes.isEmpty
              ? buildEmptyMessage(
            JwIcons.note_plus,
            'Vos notes apparaîtront ici.',
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: notes.length,
              itemBuilder: (BuildContext context, int index) {
                Note note = notes[index];
                return Container(
                  width: double.infinity,
                  height: 45,
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: note.getColor(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[850]!
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: TextButton(
                    onPressed: () async {
                      await showPage(NotePage(note: note));
                      initNotes();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.transparent,
                      overlayColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        note.title != null ? note.title!.trim().isNotEmpty ? note.title! : note.content ?? '' : '',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: note.title != null ? note.title!.trim().isNotEmpty ? FontWeight.w600 : FontWeight.normal : FontWeight.normal,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            )
          ),

          SizedBox(height: 10),

          // Header Listes de lectures
          buildSectionHeaderPlaylist(),

          // Section Notes
          playlists.isEmpty
              ? buildEmptyMessage(
            JwIcons.plus,
            'Aucune liste de lecture disponible.',
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: playlists.length,
              itemBuilder: (BuildContext context, int index) {
                Playlist playlist = playlists[index];
                return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 3),
                    child: Material(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                      child: InkWell(
                        onTap: () async {
                          await showPage(PlaylistPage(playlist: playlist));
                          initPlaylist();
                        },
                        child: SizedBox(
                          height: 80,
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2.0),
                                    child: FutureBuilder<File?>(
                                      future: playlist.getThumbnailFile(),
                                      builder: (context, snapshot) {
                                        final placeholder = Container(
                                          height: 80,
                                          width: 80,
                                          color: Colors.grey.shade300,
                                        );

                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return placeholder;
                                        }

                                        if (snapshot.hasError || snapshot.data == null) {
                                          return Container(
                                            height: 80,
                                            width: 80,
                                            color: Colors.grey,
                                          );
                                        }

                                        return Image.file(
                                          snapshot.data!,
                                          height: 80,
                                          width: 80,
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: 6.0,
                                        right: 25.0,
                                        // publication.issueTitle remplacé par playlist.name.isNotEmpty pour éviter l'erreur
                                        top: 4.0,
                                        bottom: 2.0,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist.name,
                                            style: TextStyle(
                                              height: 1.2,
                                              fontSize: 14.5,
                                              color: Theme.of(context).secondaryHeaderColor,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Menu contextuel
                              Positioned(
                                top: -5,
                                right: -10,
                                child: PopupMenuButton(
                                  popUpAnimationStyle: AnimationStyle.lerp(
                                    const AnimationStyle(curve: Curves.ease),
                                    const AnimationStyle(curve: Curves.ease),
                                    0.5,
                                  ),
                                  icon: const Icon(Icons.more_vert, color: Color(0xFF9d9d9d)),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(JwIcons.pencil),
                                          SizedBox(width: 8),
                                          Text('Renommer'),
                                        ],
                                      ),
                                      onTap: () async {
                                        await showEditTagDialog(context, playlist);
                                        initPlaylist();
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(JwIcons.trash),
                                          SizedBox(width: 8),
                                          Text('Supprimer'),
                                        ],
                                      ),
                                      onTap: () async {
                                        await showDeleteTagDialog(context, playlist);
                                        initPlaylist();
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(JwIcons.share),
                                          SizedBox(width: 8),
                                          Text('Partager'),
                                        ],
                                      ),
                                      onTap: () {
                                        //sharePlaylist(context, playlist);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                  )
                );
              },
            ),
          ),

        SizedBox(height: 20),
        ],
      ),
    );
  }
}

Color darken(Color color, [double amount = .1]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

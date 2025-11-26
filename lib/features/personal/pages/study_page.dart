import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_playlist.dart';
import 'package:jwlife/data/models/userdata/note.dart';
import 'package:jwlife/features/personal/pages/playlist_page.dart';
import 'package:jwlife/features/personal/pages/playlists_page.dart';
import 'package:provider/provider.dart';


import '../../../core/utils/utils_tag_dialogs.dart';
import '../../../data/controller/notes_controller.dart';
import '../../../data/controller/tags_controller.dart';
import '../../../data/models/userdata/playlist.dart';
import '../../../i18n/i18n.dart';
import '../widgets/empty_message.dart';
import 'note_page.dart';
import 'notes_categories_page.dart';
import 'tag_page.dart';

class StudyTabView extends StatefulWidget {
  const StudyTabView({super.key,});

  @override
  StudyTabViewState createState() => StudyTabViewState();
}

class StudyTabViewState extends State<StudyTabView> {
  List<Playlist> playlists = [];

  @override
  void initState() {
    super.initState();
    initPlaylist();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> reloadData() async {
    initPlaylist();
  }

  Future<void> initPlaylist() async {
    playlists = await JwLifeApp.userdata.getPlaylists(limit: 4);
    setState(() {});
  }

  Future<void> refreshPlaylist() async {
    playlists = await JwLifeApp.userdata.getPlaylists(limit: 4);
    setState(() {});
  }

  Future<void> refreshTag() async {
    setState(() {});
  }

  Future<void> openPlaylist(Playlist playlist) async {
    await showPage(PlaylistPage(playlist: playlist));
    initPlaylist();
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
                  i18n().navigation_bible_reading,
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

  Widget buildSectionHeaderNotesTags(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              showPage(NotesTagsPage());
            },
            child: Row(
              children: [
                Text(
                  i18n().navigation_notes_and_tag,
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
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSectionHeaderPlaylist(BuildContext context) {
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
                  i18n().navigation_playlists,
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
                child: Text(i18n().action_create_a_playlist),
                onTap: () async {
                  await showAddTagDialog(context, true);
                  initPlaylist();
                },
              ),
              PopupMenuItem<void>(
                child: Text(i18n().action_import_playlist),
                onTap: () async {
                  await importPlaylist(context);
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
    final notes = context.watch<NotesController>().getNotes(limit: 4);
    final tags = context.watch<TagsController>().tags;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Lecture de la Bible
          //buildSectionHeaderBibleReading(),

          // Lecture de la bible
          /*
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

           */

          // Header Notes et Catégories
          buildSectionHeaderNotesTags(context),

          // Section Tags
          tags.isEmpty ? buildEmptyMessage(JwIcons.tag, i18n().message_whatsnew_create_tags)
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                List<Widget> tagWidgets = [];
                double currentLineWidth = 0;
                int currentLine = 0;
                const double spacing = 8;
                const double maxLines = 4;

                for (var tag in tags) {
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
                        showPage(TagPage(tag: tag));
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

          const SizedBox(height: 10),

          notes.isEmpty ? buildEmptyMessage(
            JwIcons.note_plus,
            i18n().message_no_notes,
          ) : Padding(
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
                      showPage(NotePage(note: note));
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
          buildSectionHeaderPlaylist(context),

          // Section Notes
          playlists.isEmpty ? buildEmptyMessage(
            JwIcons.plus,
            i18n().message_no_playlists,
          ) : Padding(
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
                                          Text(i18n().action_rename),
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
                                          Text(i18n().action_delete),
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
                                          Text(i18n().action_share),
                                        ],
                                      ),
                                      onTap: () {
                                        showSharePlaylist(context, playlist);
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

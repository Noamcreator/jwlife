import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/features/personal/pages/playlist_page.dart';
import '../../../data/models/userdata/playlist.dart';
import '../widgets/empty_message.dart';

class PlaylistsPage extends StatefulWidget {

  const PlaylistsPage({super.key});

  @override
  _PlaylistsPageState createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  List<Playlist> filteredPlaylists = [];
  List<Playlist> allPlaylists = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    List<Playlist> playlists = await JwLifeApp.userdata.getPlaylists();

    setState(() {
      allPlaylists = playlists;
      filteredPlaylists = playlists;
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
            Text("Listes de lectures"),
            Text(
              '${filteredPlaylists.length} listes de lectures',
              style: TextStyle(fontSize: 12),
              maxLines: 2,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(JwIcons.plus),
            onPressed: () async {
              /*
              Note? note = await JwLifeApp.userdata.addNote("", "", 0, [], null, null, null, null, null, null);
              if (note != null) {
                await showPage(NotePage(note: note));
                setState(() {
                  filteredNotes.insert(0, note);
                });
              }

               */
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
                      filteredPlaylists = allPlaylists.where((tag) => tag.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
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
              child: // Section Notes
              filteredPlaylists.isEmpty
                  ? buildEmptyMessage(
                JwIcons.plus,
                'Aucune liste de lecture disponible.',
              ) : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPlaylists.length,
                  itemBuilder: (BuildContext context, int index) {
                    Playlist playlist = filteredPlaylists[index];
                    return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 3),
                        child: Material(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
                            child: InkWell(
                              onTap: () async {
                                await showPage(PlaylistPage(playlist: playlist));
                                init();
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
            ),
          ],
        ),
      ),
    );
  }
}

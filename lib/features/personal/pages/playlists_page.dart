import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/features/personal/pages/playlist_page.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import '../../../app/app_page.dart';
import '../../../core/ui/app_dimens.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_playlist.dart';
import '../../../core/utils/utils_tag_dialogs.dart';
import '../../../data/models/userdata/playlist.dart';
import '../../../i18n/i18n.dart';
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
    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().navigation_playlists,
        subTitle: i18n().label_playlist_items(formatNumber(filteredPlaylists.length)),
        actions: [
          IconTextButton(
            icon: Icon(JwIcons.plus),
            text: i18n().action_create_a_playlist,
            onPressed: (BuildContext context) async {
              await showAddTagDialog(context, true);
              init();
            },
          ),
          IconTextButton(
            icon: Icon(JwIcons.document),
            text: i18n().action_import_playlist,
            onPressed: (BuildContext context) async {
              await importPlaylist(context);
            },
          )
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
                    hintText: i18n().search_bar_search,
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
                i18n().message_no_playlists,
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
                                                height: kItemHeight,
                                                width: kItemHeight,
                                                color: Colors.grey.shade300,
                                              );

                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return placeholder;
                                              }

                                              if (snapshot.hasError || snapshot.data == null) {
                                                return Container(
                                                  height: kItemHeight,
                                                  width: kItemHeight,
                                                  color: Colors.grey,
                                                );
                                              }

                                              return Image.file(
                                                snapshot.data!,
                                                height: kItemHeight,
                                                width: kItemHeight,
                                                fit: BoxFit.cover,
                                              );
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsetsDirectional.only(
                                              start: 6.0,
                                              end: 25.0,
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
                                    PositionedDirectional(
                                      top: -10,
                                      end: -5,
                                      child: PopupMenuButton(
                                        popUpAnimationStyle: AnimationStyle.lerp(
                                          const AnimationStyle(curve: Curves.ease),
                                          const AnimationStyle(curve: Curves.ease),
                                          0.5,
                                        ),
                                        icon: const Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
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
                                              init();
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
                                              init();
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
            ),
          ],
        ),
      ),
    );
  }
}

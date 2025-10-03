import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/userdata/playlist.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';

import '../../data/models/video.dart';
import '../../features/personal/pages/playlist_page.dart';

Future<void> showAddPlaylistDialog(BuildContext context, dynamic item) async {
  List<Playlist> playlists = await JwLifeApp.userdata.getPlaylists();
  TextEditingController textController = TextEditingController();

  await showJwDialog<void>(
    context: context,
    titleText: "Ajouter à la liste de lecture",
    content: SizedBox(
      width: double.maxFinite,
      height: 350,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: "Rechercher",
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                // Optionnel : ajouter logique recherche en live si besoin
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return SizedBox(
                  height: 80,
                  child: FutureBuilder<File?>(
                    future: playlist.getThumbnailFile(),
                    builder: (context, snapshot) {
                      Widget leading = ClipRRect(
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
                      );

                      return InkWell(
                        onTap: () async {
                          // Ajout de l'image dans la playlist
                          if(item is String) {
                            await JwLifeApp.userdata.insertImageInPlaylist(playlist, item);
                          }
                          else if (item is Audio) {
                            await JwLifeApp.userdata.insertMediaItemInPlaylist(playlist, item);
                          }
                          else if (item is Video) {
                            await JwLifeApp.userdata.insertMediaItemInPlaylist(playlist, item);
                          }
                          showBottomMessageWithAction("Ajouté à la liste de lecture  ${playlist.name}",
                              SnackBarAction(
                                label: 'Aller à la liste de lecture',
                                onPressed: () async {
                                  GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(6);
                                  await showPage(PlaylistPage(playlist: playlist));
                                },
                              )
                          );
                          Navigator.pop(context);
                        },
                        child: ListTile(
                          leading: leading,
                          title: Text(playlist.name),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      );
                    },
                  )
                );
              },
            ),
          ),
        ],
      ),
    ),
    buttons: [
      JwDialogButton(
        label: "ANNULER"
      ),
    ],
  );
}
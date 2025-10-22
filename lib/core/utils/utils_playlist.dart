import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/userdata/playlist.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:jwlife/data/models/userdata/playlistItem.dart';
import '../../data/models/userdata/tag.dart';
import '../../data/models/video.dart';

Future<void> showAddItemToPlaylistDialog(BuildContext context, dynamic item) async {
  // 🔧 On stocke la liste initiale dans un état réactif
  List<Playlist> playlists = await JwLifeApp.userdata.getPlaylists();
  final textController = TextEditingController();

  await showJwDialog<void>(
    context: context,
    titleText: "Ajouter à la liste de lecture",
    content: SizedBox(
      width: double.maxFinite,
      height: 430,
      child: StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setDialogState) {
          // Fonction d’ajout à la playlist
          Future<void> addToPlaylist(Playlist playlist) async {
            if (item is String) {
              await JwLifeApp.userdata.insertIndependentMediaInPlaylist(playlist, item);
            }
            else if (item is PlaylistItem) {
              await JwLifeApp.userdata.insertPlaylistItem(item, playlist: playlist);
            }
            else if (item is Audio || item is Video) {
              await JwLifeApp.userdata.insertMediaItemInPlaylist(playlist, item);
            }

            BuildContext ctx = GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().context;
            showBottomMessageWithAction(
              "Ajouté à la liste de lecture « ${playlist.name} »",
              SnackBarAction(
                label: 'Ouvrir',
                textColor: Theme.of(ctx).primaryColor,
                onPressed: () {
                  GlobalKeyService.personalKey.currentState!.openPlaylist(playlist);
                },
              ),
            );
          }

          // Création d’une nouvelle playlist
          Future<void> handleCreateNewPlaylist() async {
            // Ferme le dialogue actuel avant d’en ouvrir un autre
            Navigator.of(dialogContext).pop();

            final Tag? newTag = await showAddTagDialog(
              context,
              true,
              showTagPage: false,
            );

            // ⚠️ showAddTagDialog retourne un Tag, pas un Playlist.
            if (newTag is Playlist) {
              await addToPlaylist(newTag);
              GlobalKeyService.personalKey.currentState?.refreshPlaylist();
            }
          }

          // 🔍 Filtrage en direct selon la recherche
          final filteredPlaylists = playlists.where((p) {
            final query = textController.text.toLowerCase();
            return p.name.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: InkWell(
                  onTap: handleCreateNewPlaylist,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: Theme.of(context).primaryColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(JwIcons.plus,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          "CRÉER UNE PLAYLIST",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: "Rechercher",
                    prefixIcon: Icon(JwIcons.magnifying_glass),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = filteredPlaylists[index];
                    const double thumbnailSize = 64.0;

                    return InkWell(
                      onTap: () async {
                        await addToPlaylist(playlist);
                        Navigator.of(dialogContext).pop();
                      },
                      child: ListTile(
                        leading: FutureBuilder<File?>(
                          future: playlist.getThumbnailFile(),
                          builder: (context, snapshot) {
                            final placeholder = Container(
                              height: thumbnailSize,
                              width: thumbnailSize,
                              color: Colors.grey.shade300,
                            );

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return placeholder;
                            }
                            if (snapshot.hasError || snapshot.data == null) {
                              return Container(
                                height: thumbnailSize,
                                width: thumbnailSize,
                                color: Colors.grey,
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(2.0),
                              child: Image.file(
                                snapshot.data!,
                                height: thumbnailSize,
                                width: thumbnailSize,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                        title: Text(playlist.name),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(label: "ANNULER"),
    ],
  );
}

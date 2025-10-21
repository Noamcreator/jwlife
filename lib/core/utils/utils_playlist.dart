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

import '../../data/models/video.dart';
import '../../features/personal/pages/playlist_page.dart';

Future<void> showAddItemToPlaylistDialog(BuildContext context, dynamic item) async {
  List<Playlist> initialPlaylists = await JwLifeApp.userdata.getPlaylists();
  TextEditingController textController = TextEditingController();

  await showJwDialog<void>(
    context: context,
    titleText: "Ajouter à la liste de lecture",
    content: SizedBox(
      width: double.maxFinite,
      height: 430,
      // **1. Utilisation de StatefulBuilder pour gérer l'état interne du dialogue**
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          // Utiliser la liste de playlists actuelle (initialPlaylists agit comme l'état)
          List<Playlist> currentPlaylists = initialPlaylists;

          // Fonction pour recharger la liste des playlists
          Future<void> reloadPlaylists() async {
            List<Playlist> updatedPlaylists = await JwLifeApp.userdata.getPlaylists();
            setDialogState(() {
              initialPlaylists = updatedPlaylists; // Mettre à jour la variable de l'état
            });
          }

          // Fonction pour la création d'une nouvelle playlist
          Future<void> handleCreateNewPlaylist() async {
            // Afficher le dialogue de création
            await showAddTagDialog(context, true, showTagPage: false);

            GlobalKeyService.personalKey.currentState!.refreshPlaylist();

            // **2. Recharger la liste après la fermeture du dialogue de création**
            await reloadPlaylists();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: InkWell(
                  onTap: handleCreateNewPlaylist,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(0.0),
                      border: Border.all(color: Theme.of(context).primaryColor),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(JwIcons.plus, color: Theme.of(context).primaryColor),
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
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    hintText: "Rechercher",
                    prefixIcon: const Icon(JwIcons.magnifying_glass),
                  ),
                  onChanged: (value) {
                    // Optionnel : ajouter logique recherche en live si besoin
                  },
                ),
              ),
              const SizedBox(height: 10),
              // --- Section de la liste des playlists existantes ---
              Expanded(
                child: ListView.builder(
                  itemCount: currentPlaylists.length, // Utiliser la liste mise à jour
                  itemBuilder: (context, index) {
                    final playlist = currentPlaylists[index];
                    // **La hauteur du ListTile est fixée à 80, l'image doit être de 80x80 pour être carrée**
                    const double thumbnailSize = 64.0; // Diminuer légèrement pour laisser de la marge

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
                                    // **Image Carrée**
                                    height: thumbnailSize,
                                    width: thumbnailSize,
                                    color: Colors.grey.shade300,
                                  );

                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return placeholder;
                                  }

                                  if (snapshot.hasError || snapshot.data == null) {
                                    return Container(
                                      // **Image Carrée**
                                      height: thumbnailSize,
                                      width: thumbnailSize,
                                      color: Colors.grey,
                                    );
                                  }

                                  return Image.file(
                                    snapshot.data!,
                                    // **Image Carrée**
                                    height: thumbnailSize,
                                    width: thumbnailSize,
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
                                      textColor: Theme.of(context).primaryColor,
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
          );
        },
      ),
    ),
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
          label: "ANNULER"
      ),
    ],
  );
}
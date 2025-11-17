import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_pub.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/userdata/playlist.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import '../../data/models/userdata/playlist_item.dart';
import '../../data/models/userdata/tag.dart';
import '../../data/models/video.dart';
import '../../i18n/i18n.dart';
import 'package:path/path.dart' as path;

Future<void> showAddItemToPlaylistDialog(BuildContext context, dynamic item) async {
  // 🔧 On stocke la liste initiale dans un état réactif
  List<Playlist> playlists = await JwLifeApp.userdata.getPlaylists();
  final textController = TextEditingController();

  await showJwDialog<void>(
    context: context,
    titleText: i18n().action_add_to_playlist,
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
              i18n().message_added_to_playlist_name(playlist.name),
              SnackBarAction(
                label: i18n().action_open,
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
                          i18n().action_create_a_playlist_uppercase,
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
                  decoration: InputDecoration(
                    hintText: i18n().search_hint,
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
      JwDialogButton(label: i18n().action_cancel_uppercase),
    ],
  );
}

Future<void> importPlaylist(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  if (result != null && result.files.isNotEmpty) {
    final filePath = result.files.single.path;
    if (filePath != null) {
      String fileName = path.basename(filePath);
      try {
        if (!showInvalidExtensionDialog(context, filePath: filePath, expectedExtension: '.jwlplaylist')) return;

        // Affiche le dialogue d'importation et attend son BuildContext.
        BuildContext? dialogContext = await showJwImport(context, fileName);

        Playlist? playlist = await JwLifeApp.userdata.importPlaylistFromFile(File(filePath));

        // Ferme le dialogue de chargement une fois l'importation terminée.
        if (dialogContext != null) {
          Navigator.of(dialogContext).pop();
        }

        // Gère le résultat de l'importation.
        if (playlist == null) {
          showImportFileError(context, '.jwplaylist');
        }
        else {
          // on refresh les playlist
          GlobalKeyService.personalKey.currentState?.openPlaylist(playlist);

          if (context.mounted) {
            showBottomMessage('Import de la liste de lecture réussi.');
          }
        }
      }
      catch (e) {
        if (context.mounted) {
          showBottomMessage('Échec de l’import de la liste de lecture : $e');
        }
      }
    }
  }
}

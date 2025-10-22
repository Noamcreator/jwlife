import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';

import 'package:jwlife/data/models/userdata/playlistItem.dart';
import 'package:jwlife/features/personal/pages/playlist_player.dart';
import '../../../app/services/global_key_service.dart';
import '../../../core/utils/utils_dialog.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/models/userdata/playlist.dart';
import '../widgets/rectangle_playlistItem_item.dart';

class PlaylistPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistPage({super.key, required this.playlist});

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late Playlist _playlist;
  List<PlaylistItem> _filteredPlaylistItem = [];

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    playlistItemByPlaylist();
  }

  Future<void> playlistItemByPlaylist() async {
    List<PlaylistItem> playlistItem =
    await JwLifeApp.userdata.getPlaylistItemByPlaylistId(_playlist.id);

    setState(() {
      _filteredPlaylistItem = playlistItem;
    });
  }

  void _playAll() async {
    showPlaylistPlayer(_filteredPlaylistItem);
  }

  void _playRandom() async {
    showPlaylistPlayer(_filteredPlaylistItem, randomMode: true);
  }

  Widget _buildOutlinedButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle =
    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _playlist);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_playlist.name, style: textStyleTitle),
            Text('${_filteredPlaylistItem.length} éléments',
                style: textStyleSubtitle),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(JwIcons.pencil),
            onPressed: () async {
              Playlist? updatedCategory = await showEditTagDialog(context, _playlist) as Playlist?;
              if (updatedCategory != null) {
                setState(() {
                  _playlist = updatedCategory;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(JwIcons.trash),
            onPressed: () async {
              await showDeleteTagDialog(context, _playlist, items: _filteredPlaylistItem).then((value) {
                if (value != null && value) {
                  Navigator.pop(context);
                }
              });

            },
          ),
          IconButton(
            icon: const Icon(JwIcons.share),
            onPressed: () {
              showSharePlaylist(context, _playlist, items: _filteredPlaylistItem);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        // <-- SingleChildScrollView englobe tout le contenu
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SCROLL HORIZONTAL POUR LES DEUX BOUTONS ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: Row(
                  children: [
                    _buildOutlinedButton(JwIcons.play, "TOUT LIRE", _playAll),
                    const SizedBox(width: 10),
                    _buildOutlinedButton(JwIcons.arrows_twisted_right, "LECTURE ALÉATOIRE", _playRandom),
                  ],
                ),
              ),

              const SizedBox(height: 5), // Petit espace

              // --- LISTE DES ÉLÉMENTS (Intégrée dans la Column) ---
              ..._filteredPlaylistItem.asMap().entries.map((entry) {
                int index = entry.key;
                PlaylistItem item = entry.value;
                return Column(
                  children: [
                    RectanglePlaylistItemItem(
                      items: _filteredPlaylistItem,
                      item: item,
                      onDelete: (itemToDelete) {
                        setState(() {
                          _filteredPlaylistItem.remove(itemToDelete);
                        });
                      },
                    ),
                    if (index < _filteredPlaylistItem.length - 1)
                      const SizedBox(height: 3),
                  ],
                );
              }).toList(),

              const SizedBox(height: 8), // Petit espace avant le bouton importer

              // --- BOUTON IMPORTER UN FICHIER EN BAS ---
              Padding(
                padding:
                const EdgeInsets.only(bottom: 8.0, left: 3.0, right: 3.0),
                child: InkWell(
                  onTap: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.any,
                      allowMultiple: true,
                    );

                    // Mettez les extensions en minuscules pour une comparaison non sensible à la casse.
                    List<String> allowedExtensions = [
                      'png',
                      'jpg',
                      'jpeg',
                      'mp4',
                      'm4v',
                      '3gp',
                      'mov',
                      'mp3',
                      'aac',
                      'heic',
                      'webp'
                    ];

                    List<String> invalidFiles = [];

                    if (result != null) {
                      for (var file in result.files) {

                        BuildContext? dialogContext = await showJwImport(context, file.name);

                        // L'extension de PlatformFile peut être nulle, et doit être mise en minuscules.
                        String? fileExtension = file.extension?.toLowerCase();

                        // On vérifie si l'extension n'est PAS dans la liste des extensions autorisées.
                        if (fileExtension != null && allowedExtensions.contains(fileExtension)) {
                          // ✅ Fichier accepté : on l'insère dans la playlist.
                          if (file.path != null) {
                            await JwLifeApp.userdata.insertIndependentMediaInPlaylist(widget.playlist, file.path!);
                          }
                        }
                        else {
                          // ❌ Fichier rejeté : on ajoute son nom à la liste des fichiers invalides.
                          invalidFiles.add(file.name);
                        }

                        // Ferme le dialogue de chargement une fois l'importation terminée.
                        if (dialogContext != null) {
                          Navigator.of(dialogContext).pop();
                        }
                      }

                      // --- Affichage du dialogue si des fichiers ont été rejetés ---
                      if (invalidFiles.isNotEmpty) {
                        String message;
                        if (invalidFiles.length == 1) {
                          message = 'Le fichier "${invalidFiles.first}" n\'a pas une extension autorisée.';
                        } else {
                          message = 'Les fichiers suivants n\'ont pas une extension autorisée :\n- ${invalidFiles.join('\n- ')}';
                        }

                        // Affichez votre dialogue personnalisé
                        // (Assurez-vous d'avoir accès au BuildContext ici pour les dialogues.)
                        showJwDialog(
                          context: context, // Utilisez le BuildContext de votre Widget
                          titleText: 'Fichier(s) Non Supporté(s)',
                          contentText: message,
                          buttons: [
                            JwDialogButton(
                              label: 'OK'
                            ),
                          ]
                        );
                      }

                      // rafraishir la playlist
                      playlistItemByPlaylist();

                      // on met à jour les playlist sur la vue personelle
                      GlobalKeyService.personalKey.currentState?.refreshPlaylist();
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: DottedBorder(
                    options: RectDottedBorderOptions(
                      strokeWidth: 1.5,
                      dashPattern: [5, 3],
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(JwIcons.plus),
                          const SizedBox(width: 6),
                          const Text(
                            "Importer un fichier",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
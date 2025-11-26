import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_app_bar.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils_tag_dialogs.dart';

import 'package:jwlife/features/personal/pages/playlist_player.dart';
import '../../../app/app_page.dart';
import '../../../app/services/global_key_service.dart';
import '../../../core/utils/utils_dialog.dart';
import '../../../core/utils/utils_pub.dart';
import '../../../data/models/userdata/playlist.dart';
import '../../../data/models/userdata/playlist_item.dart';
import '../../../i18n/i18n.dart';
import '../../../widgets/responsive_appbar_actions.dart';
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
    // Assurez-vous que cette fonction utilise ORDER BY Position ASC dans TagMap
    List<PlaylistItem> playlistItem = await JwLifeApp.userdata.getPlaylistItemByPlaylistId(_playlist.id);

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

  // --- LOGIQUE DE RÉORDONNANCEMENT ---

  void _onReorder(int oldIndex, int newIndex) {
    // Les indices réordonnables commencent à 1, donc nous les ajustons
    if (oldIndex == 0 || oldIndex == _filteredPlaylistItem.length + 1) return;
    if (newIndex == 0 || newIndex == _filteredPlaylistItem.length + 1) return;

    // Ajustement des indices pour correspondre à la liste interne
    int internalOldIndex = oldIndex - 1;
    int internalNewIndex = newIndex - 1;

    setState(() {
      if (internalOldIndex < internalNewIndex) {
        internalNewIndex -= 1;
      }

      final PlaylistItem item = _filteredPlaylistItem.removeAt(internalOldIndex);
      _filteredPlaylistItem.insert(internalNewIndex, item);

      _updatePlaylistItemOrderInDatabase();
    });
  }

  Future<void> _updatePlaylistItemOrderInDatabase() async {
    List<int> itemIdsInNewOrder = _filteredPlaylistItem.map((item) => item.playlistItemId).toList();
    await JwLifeApp.userdata.reorderPlaylistItemInPlaylist(_playlist.id, itemIdsInNewOrder);
  }

  void _onDeleteItem(PlaylistItem itemToDelete) {
    setState(() {
      _filteredPlaylistItem.remove(itemToDelete);
      _updatePlaylistItemOrderInDatabase();
    });
  }

  // ------------------------------------

  Widget _buildOutlinedButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  // --- LOGIQUE D'IMPORTATION DE FICHIERS (Factorisée) ---
  Future<void> _handleFileImport() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    List<String> allowedExtensions = [
      'png', 'jpg', 'jpeg', 'mp4', 'm4v', '3gp', 'mov', 'mp3', 'aac', 'heic', 'webp'
    ];

    List<String> invalidFiles = [];

    if (result != null) {
      for (var file in result.files) {
        BuildContext? dialogContext = await showJwImport(context, file.name);
        String? fileExtension = file.extension?.toLowerCase();

        if (fileExtension != null && allowedExtensions.contains(fileExtension)) {
          if (file.path != null) {
            await JwLifeApp.userdata.insertIndependentMediaInPlaylist(widget.playlist, file.path!);
          }
        }
        else {
          invalidFiles.add(file.name);
        }

        if (dialogContext != null) {
          Navigator.of(dialogContext).pop();
        }
      }

      if (invalidFiles.isNotEmpty) {
        String message;
        if (invalidFiles.length == 1) {
          message = 'Le fichier "${invalidFiles.first}" n\'a pas une extension autorisée.';
        } else {
          message = 'Les fichiers suivants n\'ont pas une extension autorisée :\n- ${invalidFiles.join('\n- ')}';
        }

        showJwDialog(
            context: context,
            titleText: i18n().message_file_not_supported_title,
            contentText: message,
            buttons: [ JwDialogButton(label: i18n().action_close_upper) ]
        );
      }

      await playlistItemByPlaylist();
      GlobalKeyService.personalKey.currentState?.refreshPlaylist();
    }
  }
  // --------------------------------------------------------

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

    return AppPage(
      appBar: JwLifeAppBar(
        title: _playlist.name,
        subTitle: '${i18n().label_playlist_items(_filteredPlaylistItem.length)} · ${i18n().label_duration(getPlaylistDuration(_filteredPlaylistItem))}',
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.pencil),
            onPressed: (BuildContext context) async {
              Playlist? updatedCategory = await showEditTagDialog(context, _playlist) as Playlist?;
              if (updatedCategory != null) {
                setState(() {
                  _playlist = updatedCategory;
                });
              }
            },
          ),
          IconTextButton(
            icon: const Icon(JwIcons.trash),
            onPressed: (BuildContext context) async {
              await showDeleteTagDialog(context, _playlist, items: _filteredPlaylistItem).then((value) {
                if (value != null && value) {
                  Navigator.pop(context);
                }
              });

            },
          ),
          IconTextButton(
            icon: const Icon(JwIcons.share),
            onPressed: (BuildContext context) {
              showSharePlaylist(context, _playlist, items: _filteredPlaylistItem);
            },
          ),
        ],
      ),
      // *** LE BODY CONTIENT DIRECTEMENT LE ReorderableListView ***
      body: ReorderableListView.builder(
        onReorder: _onReorder,
        physics: const ClampingScrollPhysics(),
        // Padding latéral pour les items
        padding: const EdgeInsets.symmetric(horizontal: 5.0),

        // Taille totale : Liste + 1 élément en tête + 1 élément en pied
        itemCount: _filteredPlaylistItem.length + 2,

        itemBuilder: (context, index) {

          // --- 1. BOUTONS D'ACTION (INDEX 0) ---
          if (index == 0) {
            return Padding(
              key: const ValueKey('playlist_header_buttons'),
              padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildOutlinedButton(JwIcons.play, i18n().action_play_all.toUpperCase(), _playAll),
                    const SizedBox(width: 10),
                    _buildOutlinedButton(JwIcons.arrows_twisted_right, i18n().action_shuffle.toUpperCase(), _playRandom),
                  ],
                ),
              ),
            );
          }

          // --- 2. BOUTON IMPORTER (DERNIER INDEX) ---
          if (index == _filteredPlaylistItem.length + 1) {
            return Padding(
              key: const ValueKey('playlist_footer_import'),
              padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
              child: InkWell(
                onTap: _handleFileImport,
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
                        Text(i18n().action_import_file, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // --- 3. ITEMS RÉORDONNABLES (INDEX 1 à N) ---

          // L'index réel de l'élément dans la liste _filteredPlaylistItem est index - 1
          final itemIndex = index - 1;
          final item = _filteredPlaylistItem[itemIndex];

          return Column(
            // La clé doit être sur le widget enfant direct de ReorderableListView
            key: ValueKey('playlist_item_${item.playlistItemId}'),
            children: [
              _KeepAlivePlaylistItemItem(
                item: item,
                items: _filteredPlaylistItem,
                onDelete: _onDeleteItem,
              ),
              if (itemIndex < _filteredPlaylistItem.length - 1)
                const SizedBox(height: 3),
            ],
          );
        },
      ),
    );
  }

  String getPlaylistDuration(List<PlaylistItem> filteredPlaylistItem) {
    // Utilisez un BigInt ou un double pour la somme initiale si les ticks sont très grands,
    // mais une simple addition suffit souvent si Flutter gère bien les grands entiers (64-bit).
    // Nous utiliserons un int (64-bit) pour le total des ticks.
    int totalTicks = 0;

    // 1. Calcul de la durée totale en Ticks
    for (var item in filteredPlaylistItem) {
      totalTicks += item.durationTicks ?? item.baseDurationTicks ?? 0;
    }

    // Si la durée est zéro, on retourne 0:00
    if (totalTicks == 0) {
      return '0:00';
    }

    // 2. Conversion en secondes (division par 10^7 pour les 100-nanoseconde ticks)
    // Utiliser la division entière (~) pour rester en entier, car nous ne voulons pas des ms ici.
    final int totalSeconds = totalTicks ~/ 10000000;

    // 3. Conversion en Heures, Minutes, Secondes
    final int seconds = totalSeconds % 60;
    final int totalMinutes = totalSeconds ~/ 60;
    final int minutes = totalMinutes % 60;
    final int hours = totalMinutes ~/ 60;

    // 4. Formatage en String

    // Les secondes et minutes (si format H:MM:SS) doivent toujours avoir deux chiffres (ex: 05, 12)
    final String secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      // Format H:MM:SS (ex: 1:25:00)
      final String minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    } else {
      // Format M:SS (ex: 1:15)
      final String minutesStr = totalMinutes.toString(); // Pas de padLeft pour les minutes
      return '$minutesStr:$secondsStr';
    }
  }
}

// =========================================================================
// WIDGET DE MAINTIEN DE L'ÉTAT (KEEP ALIVE) - DÉFINI EN DEHORS DE LA CLASSE PRINCIPALE
// =========================================================================

class _KeepAlivePlaylistItemItem extends StatefulWidget {
  final PlaylistItem item;
  final List<PlaylistItem> items;
  final Function(PlaylistItem) onDelete;

  const _KeepAlivePlaylistItemItem({
    super.key,
    required this.item,
    required this.items,
    required this.onDelete,
  });

  @override
  State<_KeepAlivePlaylistItemItem> createState() => _KeepAlivePlaylistItemItemState();
}

class _KeepAlivePlaylistItemItemState extends State<_KeepAlivePlaylistItemItem>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true; // Indique à Flutter de maintenir l'état

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RectanglePlaylistItemItem(
      items: widget.items,
      item: widget.item,
      onDelete: widget.onDelete,
    );
  }
}
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';

import 'package:jwlife/data/models/userdata/playlistItem.dart';
import '../../../data/models/userdata/tag.dart';
import '../widgets/rectangle_playlistItem_item.dart';

class PlaylistPage extends StatefulWidget {
  final Tag playlist;

  const PlaylistPage({super.key, required this.playlist});

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late Tag _playlist;
  List<PlaylistItem> _filteredPlaylistItem = [];

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    playlistItemByPlaylist();
  }

  Future<void> playlistItemByPlaylist() async {
    // Fetch notes by category first
    List<PlaylistItem> playlistItem = await JwLifeApp.userdata.getPlaylistItemByPlaylistId(_playlist.id);

    // Now update the state with the fetched notes
    setState(() {
      _filteredPlaylistItem = playlistItem;
    });
  }

  String _formatDuration(int? offsetTicks) {
    if (offsetTicks == null) return "0:00";
    // Convertir les ticks en secondes (10 000 000 ticks = 1 seconde)
    int totalSeconds = (offsetTicks / 10000000).round();
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  void _playAll() async {
    //JwLifeApp.audioPlayer.playAudios(widget.category, allAudios);
  }

  void _playRandom() async {
    /*
    if (allAudios.isEmpty) return;
    final randomIndex = Random().nextInt(allAudios.length);
    JwLifeApp.audioPlayer.playAudios(widget.category, allAudios, id: randomIndex, randomMode: true);

     */
  }

  Widget _buildOutlinedButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        overlayColor: Theme.of(context).brightness == Brightness.dark ? Color(0xFF8e8e8e) : Color(0xFF757575),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Styles partagés
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
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
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _playlist);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _playlist.name,
              style: textStyleTitle
            ),
            Text(
              '${_filteredPlaylistItem.length} éléments',
              style: textStyleSubtitle
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(JwIcons.pencil),
            onPressed: () async {
              // Utiliser await à l'extérieur du setState
              /*
              Playlist? updatedCategory = await showEditPlaylistDialog(context, _tag);

              // Si la catégorie a été mise à jour, on applique le setState
              if (updatedCategory != null) {
                setState(() {
                  _tag = updatedCategory;
                });
              }
              */
            },
          ),
          IconButton(
            icon: Icon(JwIcons.trash),
            onPressed: () async {
              /*
               await showDeletePlaylistDialog(context, _tag).then((value) => setState(() {}));
               Navigator.pop(context);
               */
            },
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Action de partage
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Boutons de contrôle
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Wrap(
              spacing: 10,
              children: [
                _buildOutlinedButton(Icons.playlist_play, "TOUT LIRE", _playAll),
                _buildOutlinedButton(Icons.shuffle, "LECTURE ALÉATOIRE", _playRandom),
              ],
            ),
          ),
          // Liste des éléments
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(5.0),
              itemCount: _filteredPlaylistItem.length,
              itemBuilder: (context, index) => RectanglePlaylistItemItem(
                item: _filteredPlaylistItem[index],
              ),
              separatorBuilder: (context, index) => const SizedBox(height: 3), // espace entre éléments
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () {
                // Action d'importation
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () {
                    // Action d'importation
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: DottedBorder(
                    options: RectDottedBorderOptions(
                      strokeWidth: 1.5,
                      dashPattern: [5, 3],
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                    child: SizedBox(
                      width: double.infinity, // prend toute la largeur
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, // centre le texte et l'icône
                        children: [
                          Icon(
                            JwIcons.plus,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Importer un fichier",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ),
              )
            ),
          )
        ],
      ),
    );
  }
}
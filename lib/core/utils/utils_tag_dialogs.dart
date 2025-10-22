import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/data/models/userdata/playlist.dart';
import 'package:jwlife/features/personal/pages/playlist_page.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/userdata/playlistItem.dart';
import '../../data/models/userdata/tag.dart';
import '../../features/personal/pages/tag_page.dart';
import 'common_ui.dart';

Future<Tag?> showAddTagDialog(BuildContext context, bool isPlaylist, {bool showTagPage = true}) async {
  final textController = TextEditingController();

  // Affichage du dialogue via showJwDialog
  final Tag? result = await showJwDialog<Tag?>(
    context: context,
    titleText: isPlaylist
        ? "Créer une liste de lecture"
        : "Ajouter une catégorie",
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: textController,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: isPlaylist
              ? "Nom de la liste de lecture"
              : "Nom de la catégorie",
        ),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    ),
    buttons: [
      JwDialogButton(
        label: "ANNULER",
        closeDialog: true,
      ),
      JwDialogButton(
        label: "OK",
        closeDialog: false, // Ne ferme pas automatiquement
        onPressed: (dialogContext) async {
          final name = textController.text.trim();

          if (name.isEmpty) {
            // Optionnel : affichage d’un message d’erreur ou simple retour
            return;
          }

          // Création du tag
          final tag = await JwLifeApp.userdata.addTag(name, isPlaylist ? 2 : 1);

          // Ferme la boîte de dialogue avec la valeur créée
          Navigator.of(dialogContext).pop(tag);

          // Si besoin, ouvrir la page associée
          if (tag != null && showTagPage) {
            if (!context.mounted) return;
            if (isPlaylist) {
              await showPage(PlaylistPage(playlist: tag as Playlist));
            } else {
              await showPage(TagPage(tag: tag));
            }
          }
        },
      ),
    ],
  );

  return result;
}


Future<Tag?> showEditTagDialog(BuildContext context, Tag tag) async {
  TextEditingController textController = TextEditingController(text: tag.name);

  // Affichage du dialogue avec la structure showJwDialog
  Tag? result = await showJwDialog<Tag>(
    context: context,
    titleText: "Renommer",
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: textController,
        decoration: InputDecoration(
          hintText: tag.type == 2 ? "Nom de la liste de lecture" : "Nom de la catégorie",
        ),
      ),
    ),
    buttons: [
      JwDialogButton(
        label: "ANNULER",
      ),
      JwDialogButton(
        label: "RENOMMER",
        closeDialog: false,
        onPressed: (buildContext) async {
          String categoryName = textController.text.trim();
          if (categoryName.isNotEmpty) {
            Tag? updatedCategory = await JwLifeApp.userdata.updateTag(tag, categoryName);
            if (updatedCategory != null) {
              Navigator.pop(buildContext, updatedCategory); // Ferme avec la catégorie mise à jour
            }
            else {
              Navigator.pop(buildContext); // Ferme sans rien renvoyer
            }
          }
        },
      ),
    ],
  );

  return result;
}

Future<bool?> showDeleteTagDialog(BuildContext context, Tag tag, {List<PlaylistItem>? items}) async {
  bool isPlaylist = tag.type == 2;

  // Affichage du dialogue
  return await showJwDialog<bool?>(
    context: context,
    titleText: isPlaylist
        ? "Supprimer la liste de lecture"
        : "Supprimer la catégorie",
    contentText: isPlaylist
        ? "Cette action supprimera la liste de lecture « ${tag.name} »."
        : "Cette action supprimera la catégorie « ${tag.name} » mais les notes ne seront pas supprimées.",
    buttons: [
      // Bouton ANNULER -> ferme juste le dialog
      JwDialogButton(
        label: "ANNULER",
        closeDialog: true,
      ),

      // Bouton SUPPRIMER -> supprime puis renvoie 'true'
      JwDialogButton(
        label: "SUPPRIMER",
        closeDialog: false,
        onPressed: (BuildContext dialogContext) async {
          await JwLifeApp.userdata.deleteTag(tag, items: items);
          Navigator.pop(dialogContext, true);
        },
      ),
    ],
  );
}

Future<bool?> showSharePlaylist(BuildContext context, Playlist playlist, {List<PlaylistItem>? items}) async {
  try {
    // 🔹 Exporter la playlist
    File? file = await JwLifeApp.userdata.exportPlaylistToFile(playlist, items: items);

    // 🔹 Si le fichier est valide → Partager
    if (file != null && await file.exists()) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      await file.delete();

      return true;
    }
    // 🔹 Sinon → Alerte utilisateur
    else {
      await showJwDialog(
        context: context,
        titleText: 'Erreur',
        contentText: 'Impossible d’exporter la playlist "${playlist.name}".',
        buttons: [
          JwDialogButton(label: 'OK')
        ]
      );
      return false;
    }
  }
  catch (e) {
    return false;
  }
}
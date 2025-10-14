import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/features/personal/pages/playlist_page.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';

import '../../data/models/userdata/playlistItem.dart';
import '../../data/models/userdata/tag.dart';
import '../../features/personal/pages/tag_page.dart';
import 'common_ui.dart';

Future<void> showAddTagDialog(BuildContext context, bool isPlaylist) async {
  TextEditingController textController = TextEditingController();

  // Affichage du dialogue avec la structure showJwDialog
  await showJwDialog<void>(
    context: context,
    titleText: isPlaylist ? "Créer une liste de lecture" : "Ajouter une catégorie",
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: textController,
        decoration: InputDecoration(
          hintText: isPlaylist ? "Nom de la liste de lecture" : "Nom de la catégorie",
        ),
      ),
    ),
    buttons: [
      JwDialogButton(
        label: "ANNULER",
        closeDialog: true,
      ),
      JwDialogButton(
        label: "OK",
        closeDialog: false, // ← Ne ferme pas automatiquement
        onPressed: (buildContext) async {
          String name = textController.text.trim();
          if (name.isNotEmpty) {
            Tag? tag = await JwLifeApp.userdata.addTag(name, isPlaylist ? 2 : 1);
            Navigator.pop(buildContext);
            if (tag != null) {
              if (isPlaylist) {
                await showPage(PlaylistPage(playlist: tag));
              }
              else {
                await showPage(TagPage(tag: tag));
              }
            }
          }
        },
      ),
    ],
  );
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
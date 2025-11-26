import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/data/controller/tags_controller.dart';
import 'package:jwlife/data/models/userdata/playlist.dart';
import 'package:jwlife/features/personal/pages/playlist_page.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/userdata/playlist_item.dart';
import '../../data/models/userdata/tag.dart';
import '../../features/personal/pages/tag_page.dart';
import '../../i18n/i18n.dart';
import 'common_ui.dart';

Future<Tag?> showAddTagDialog(BuildContext context, bool isPlaylist, {bool showTagPage = true}) async {
  final textController = TextEditingController();

  // Affichage du dialogue via showJwDialog
  final Tag? result = await showJwDialog<Tag?>(
    context: context,
    titleText: isPlaylist
        ? i18n().action_create_a_playlist
        : i18n().action_add_a_tag,
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: textController,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    ),
    buttons: [
      JwDialogButton(
        label: i18n().action_cancel_uppercase,
        closeDialog: true,
      ),
      JwDialogButton(
        label: i18n().action_ok,
        closeDialog: false, // Ne ferme pas automatiquement
        onPressed: (dialogContext) async {
          final name = textController.text.trim();

          if (name.isEmpty) {
            // Optionnel : affichage d’un message d’erreur ou simple retour
            return;
          }

          // Création du tag
          Tag tag = await context.read<TagsController>().addTag(name, type: isPlaylist ? 2 : 1);

          // Ferme la boîte de dialogue avec la valeur créée
          Navigator.of(dialogContext).pop();

          // Si besoin, ouvrir la page associée
          if (showTagPage) {
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
    titleText: i18n().action_rename,
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: textController,
      ),
    ),
    buttons: [
      JwDialogButton(
        label: i18n().action_cancel_uppercase,
      ),
      JwDialogButton(
        label: i18n().action_rename_uppercase,
        closeDialog: false,
        onPressed: (buildContext) async {
          String categoryName = textController.text.trim();
          if (categoryName.isNotEmpty) {
            context.read<TagsController>().renameTag(tag.id, categoryName);
            Navigator.pop(buildContext);
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
        ? i18n().message_delete_playlist_title
        : i18n().action_remove_tag,
    contentText: isPlaylist
        ? i18n().message_delete_playlist(tag.name)
        : i18n().message_remove_tag(tag.name),
    buttons: [
      // Bouton ANNULER -> ferme juste le dialog
      JwDialogButton(
        label: i18n().action_cancel_uppercase,
        closeDialog: true,
      ),

      // Bouton SUPPRIMER -> supprime puis renvoie 'true'
      JwDialogButton(
        label: i18n().action_delete_uppercase,
        closeDialog: false,
        onPressed: (BuildContext dialogContext) async {
          context.read<TagsController>().removeTag(tag.id, type: tag.type, items: items);
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
          JwDialogButton(label: i18n().action_ok)
        ]
      );
      return false;
    }
  }
  catch (e) {
    return false;
  }
}
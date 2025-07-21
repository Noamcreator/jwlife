import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/features/personal/views/tag_page.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';

import '../../data/models/userdata/tag.dart';
import 'common_ui.dart';

void showAddTagDialog(BuildContext context) async {
  TextEditingController textController = TextEditingController();

  // Affichage du dialogue avec la structure showJwDialog
  await showJwDialog(
    context: context,
    titleText: "Ajouter une catégorie",
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: textController,
        decoration: InputDecoration(
          hintText: "Nom de la catégorie",
        ),
      ),
    ),
    buttons: [
      JwDialogButton(
        label: "ANNULER",
      ),
      JwDialogButton(
        label: "OK",
        onPressed: (buildContext) async {
          String name = textController.text.trim();
          if (name.isNotEmpty) {
            Tag? tag = await JwLifeApp.userdata.addTag(name, 1);
            if (tag != null) {
              showPage(buildContext, TagPage(tag: tag));
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
          hintText: "Nom de la catégorie",
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
          }
        },
      ),
    ],
  );

  return result;
}

Future<Tag?> showDeleteTagDialog(BuildContext context, Tag tag) async {
  // Affichage du dialogue avec la structure showJwDialog
  Tag? result = await showJwDialog<Tag>(
    context: context,
    titleText: "Supprimer la catégorie",
    contentText: "Cette action supprimera la catégorie « ${tag.name} » mais les notes ne seront pas supprimées.",
    buttons: [
      JwDialogButton(
        label: "ANNULER",
        onPressed: (buildContext) {
          Navigator.pop(buildContext); // Ferme sans rien renvoyer
        },
      ),
      JwDialogButton(
        label: "SUPPRIMER",
        closeDialog: false, // Ne ferme pas immédiatement
        onPressed: (buildContext) async {
          await JwLifeApp.userdata.deleteTag(tag);
          Navigator.pop(buildContext); // Ferme après la suppression
        },
      ),
    ],
  );

  return result;
}
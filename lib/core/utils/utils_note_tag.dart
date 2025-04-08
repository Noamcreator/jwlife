import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/modules/personal/views/category_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';

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
          String categoryName = textController.text.trim();
          if (categoryName.isNotEmpty) {
            var category = await JwLifeApp.userdata.addCategory(categoryName, 1);
            showPage(buildContext, CategoryView(category: category));
          }
        },
      ),
    ],
  );
}

Future<Map<String, dynamic>?> showEditTagDialog(BuildContext context, Map<String, dynamic> category) async {
  TextEditingController textController = TextEditingController(text: category['Name'] ?? '');

  // Affichage du dialogue avec la structure showJwDialog
  Map<String, dynamic>? result = await showJwDialog<Map<String, dynamic>>(
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
            var updatedCategory = await JwLifeApp.userdata.updateCategory(category, categoryName);
            Navigator.pop(buildContext, updatedCategory); // Ferme avec la catégorie mise à jour
          }
        },
      ),
    ],
  );

  return result;
}

Future<Map<String, dynamic>?> showDeleteTagDialog(BuildContext context, Map<String, dynamic> category) async {
  // Affichage du dialogue avec la structure showJwDialog
  Map<String, dynamic>? result = await showJwDialog<Map<String, dynamic>>(
    context: context,
    titleText: "Supprimer la catégorie",
    contentText: "Cette action supprimera la catégorie « ${category['Name']} » mais les notes ne seront pas supprimées.",
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
          await JwLifeApp.userdata.deleteCategory(category);
          Navigator.pop(buildContext); // Ferme après la suppression
        },
      ),
    ],
  );

  return result;
}
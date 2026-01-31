import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:jwlife/i18n/i18n.dart';

Future<void> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required VoidCallback onConfirm,
  String? confirmText,
  String? cancelText,
}) async {
  // On utilise la logique de ton second bloc pour afficher le dialogue
  final bool? confirmed = await showJwDialog(
    context: context,
    titleText: title,
    contentText: content,
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
        // Utilise cancelText si fourni, sinon fallback sur la traduction i18n
        label: (cancelText ?? i18n().action_no).toUpperCase(),
        closeDialog: false,
        onPressed: (buildContext) {
          Navigator.of(buildContext).pop(false);
        },
      ),
      JwDialogButton(
        // Utilise confirmText si fourni, sinon fallback sur la traduction i18n
        label: (confirmText ?? i18n().action_yes).toUpperCase(),
        closeDialog: false,
        onPressed: (buildContext) {
          Navigator.of(buildContext).pop(true);
        },
      ),
    ],
  );

  // Si l'utilisateur a cliqué sur "Oui", on exécute la fonction de rappel
  if (confirmed == true) {
    onConfirm();
  }
}
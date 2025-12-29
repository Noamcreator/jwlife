import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/jwlife_app.dart';
import '../../app/services/global_key_service.dart';
import '../../data/databases/userdata.dart';
import '../../i18n/i18n.dart';
import '../icons.dart';
import 'common_ui.dart';

Future<void> handleImport(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null) return;

    final file = result.files.first;
    final filePath = file.path ?? '';

    // Validation du fichier
    final allowedExtensions = ['jwlibrary', 'jwlife'];
    final fileExtension = filePath.split('.').last.toLowerCase();

    if (!allowedExtensions.contains(fileExtension)) {
      await showErrorDialog(context, i18n().message_file_not_supported_title, i18n().message_file_not_supported_2_extensions('.jwlibrary', '.jwlife'));
      return;
    }

    // Validation ZIP
    if (!await _isValidZipFile(filePath)) {
      return;
    }

    // Récupération des infos et confirmation
    final info = await getBackupInfo(File(filePath));
    if (info == null) {
      await showErrorDialog(context, i18n().message_restore_failed, i18n().message_restore_failed_explanation);
      return;
    }

    final shouldRestore = await _showRestoreConfirmation(context, info);
    if (shouldRestore != true) return;

    await _performRestore(context, File(filePath));
  }
  catch (e) {
    await showErrorDialog(context, i18n().message_restore_failed, i18n().message_restore_failed);
  }
}

Future<void> handleExport(BuildContext context) async {
  BuildContext? dialogContext;

  showJwDialog(
    context: context,
    titleText: i18n().message_exporting_userdata,
    content: Builder(
      builder: (ctx) {
        dialogContext = ctx;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: SizedBox(
            height: 50,
            child: getLoadingWidget(Theme.of(context).primaryColor),
          ),
        );
      },
    ),
  );

  try {
    final backupFile = await JwLifeApp.userdata.exportBackup();
    if (dialogContext != null) Navigator.of(dialogContext!).pop();

    if (backupFile != null) {
      await SharePlus.instance.share(ShareParams(files: [XFile(backupFile.path)]));
    }

    // On supprime le fichier
    if (backupFile != null) await File(backupFile.path).delete();
  }
  catch (e) {
    if (dialogContext != null) Navigator.of(dialogContext!).pop();
    await showErrorDialog(context, 'Erreur', 'Erreur lors de l\'exportation.');
  }
}

Future<void> handleResetUserdata(BuildContext context) async {
  final confirm = await showJwDialog<bool>(
    context: context,
    titleText: i18n().message_confirm_userdata_reset_title,
    contentText: i18n().message_confirm_userdata_reset,
    buttons: [
      JwDialogButton(
        label: i18n().action_cancel_uppercase,
        closeDialog: true,
        result: false,
      ),
      JwDialogButton(
        label: i18n().action_reset_uppercase,
        closeDialog: true,
        result: true,
      ),
    ],
    buttonAxisAlignment: MainAxisAlignment.end,
  );

  if (confirm != true) return;

  // ÉTAPE 2: Affichage du dialogue d'attente (Spinner)
  BuildContext? dialogContext;
  showJwDialog(
    context: context,
    titleText: i18n().message_userdata_reseting,
    content: Builder(
      builder: (ctx) {
        // L'ASSIGNATION du Context du dialogue se fait ici.
        dialogContext = ctx;
        return Center(
          child: SizedBox(
            height: 70,
            child: getLoadingWidget(Theme.of(context).primaryColor),
          ),
        );
      },
    ),
  );

  // ÉTAPE 3: Exécution de l'opération asynchrone
  try {
    await JwLifeApp.userdata.deleteBackup();

    // Utilisation du Context GARANTI non-null.
    if (dialogContext != null) {
      // Ferme le dialogue d'attente.
      Navigator.of(dialogContext!).pop();

      // Dialogue de confirmation.
      await showJwDialog(
        context: context,
        titleText: i18n().message_delete_userdata_title,
        contentText: i18n().message_delete_userdata,
        buttons: [
          JwDialogButton(
            label: i18n().action_ok,
            closeDialog: true,
          ),
        ],
        buttonAxisAlignment: MainAxisAlignment.end,
      );
    }

    // Mises à jour de l'interface
    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }
  catch (e) {
    // S'assurer de fermer le dialogue d'attente même en cas d'erreur.
    if (dialogContext != null) {
      Navigator.of(dialogContext!).pop();
    }

    print(e);
    await showErrorDialog(context, 'Erreur', 'Erreur lors de la suppression. $e');
  }
}

Future<bool> _isValidZipFile(String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    ZipDecoder().decodeBytes(bytes);
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool?> _showRestoreConfirmation(BuildContext context, BackupInfo? info) async {
  return await showJwDialog<bool>(
    context: context,
    titleText: i18n().action_restore_a_backup,
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n().message_restore_a_backup_explanation,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 15),
          info == null  ? SizedBox.shrink() : Text(info.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
          info == null  ? SizedBox.shrink() : const SizedBox(height: 5),
          info == null  ? SizedBox.shrink() : Text(timeAgo(info.lastModified)),
        ],
      ),
    ),
    buttons: [
      JwDialogButton(
        label: i18n().action_cancel_uppercase,
        closeDialog: true,
        result: false,
      ),
      JwDialogButton(
        label: i18n().action_restore_uppercase,
        closeDialog: true,
        result: true,
      ),
    ],
    buttonAxisAlignment: MainAxisAlignment.end,
  );
}

Future<void> _performRestore(BuildContext context, File file) async {
  BuildContext? dialogContext;

  showJwDialog(
    context: context,
    titleText: i18n().message_restore_in_progress,
    content: Builder(
      builder: (ctx) {
        dialogContext = ctx;
        return Center(
          child: SizedBox(
            height: 70,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: getLoadingWidget(Theme.of(context).primaryColor),
            ),
          ),
        );
      },
    ),
  );

  try {
    await JwLifeApp.userdata.importBackup(file);

    if (dialogContext != null) Navigator.of(dialogContext!).pop();

    await showJwDialog(
      context: context,
      titleText: i18n().message_restore_successful,
      content: Center(
        child: Icon(
          JwIcons.check,
          color: Theme.of(context).primaryColor,
          size: 70,
        ),
      ),
      buttons: [
        JwDialogButton(
          label: i18n().action_close_upper,
          closeDialog: true,
        ),
      ],
      buttonAxisAlignment: MainAxisAlignment.end,
    );

    GlobalKeyService.personalKey.currentState?.refreshUserdata();
  }
  catch (e) {
    if (dialogContext != null) Navigator.of(dialogContext!).pop();
    await showErrorDialog(context, i18n().message_restore_failed, i18n().message_restore_failed);
  }
}

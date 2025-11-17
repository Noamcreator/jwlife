import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:path/path.dart' as path;

import '../../core/icons.dart';
import '../../core/utils/common_ui.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_jwpub.dart';
import '../../core/jworg_uri.dart';
import '../../core/utils/utils_pub.dart';
import '../../core/utils/widgets_utils.dart';
import '../../data/databases/catalog.dart';
import '../../data/databases/userdata.dart';
import '../../data/models/userdata/playlist.dart';
import '../../features/publication/pages/menu/local/publication_menu_view.dart';
import '../../core/utils/utils_dialog.dart';
import '../../i18n/i18n.dart';

class FileHandlerService {
  static final FileHandlerService _instance = FileHandlerService._internal();
  factory FileHandlerService() => _instance;
  FileHandlerService._internal();

  static const MethodChannel _channel = MethodChannel('org.noam.jwlife.filehandler');

  // Callbacks pour traiter les fichiers et URLs reçus
  Function(String filePath, String fileType)? onFileReceived;
  Function(String url)? onUrlReceived;

  Future<void> initialize() async {
    // Écouter les fichiers et URLs entrants
    _channel.setMethodCallHandler(_handleMethodCall);

    // Vérifier s'il y a un fichier ou URL en attente au démarrage
    await _checkPendingContent();

    // Définir le callback pour les fichiers reçus
    onFileReceived = (filePath, fileType) {
      print('Fichier reçu: $filePath de type $fileType');

      switch (fileType) {
        case 'jwlibrary':
          processJwLibraryFile(filePath);
          break;
        case 'jwlplaylist':
          processJwPlaylistFile(filePath);
          break;
        case 'jwpub':
          processJwPubFile(filePath);
          break;
      }
    };

    // Callback pour les URLs JW.org
    onUrlReceived = (url) {
      print('URL JW.org reçue: $url');

      processJwOrgUrl(url);
    };
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFileReceived':
        final String filePath = call.arguments['filePath'];
        final String fileType = _getFileType(filePath);

        print('Fichier reçu: $filePath (type: $fileType)');

        if (onFileReceived != null) {
          onFileReceived!(filePath, fileType);
        } else {
          // Stocker pour traitement ultérieur
          _pendingFilePath = filePath;
          _pendingFileType = fileType;
        }
        break;

      case 'onUrlReceived':
        final String url = call.arguments['url'];

        print('URL reçue: $url');

        if (onUrlReceived != null) {
          onUrlReceived!(url);
        } else {
          // Stocker pour traitement ultérieur
          _pendingUrl = url;
        }
        break;
    }
  }

  String? _pendingFilePath;
  String? _pendingFileType;
  String? _pendingUrl;

  Future<void> _checkPendingContent() async {
    try {
      final Map<String, dynamic>? result =
      await _channel.invokeMapMethod('getPendingFile');

      if (result != null) {
        if (result['filePath'] != null) {
          final String filePath = result['filePath'];
          final String fileType = _getFileType(filePath);

          print('Fichier en attente au démarrage: $filePath');

          if (onFileReceived != null) {
            onFileReceived!(filePath, fileType);
          } else {
            _pendingFilePath = filePath;
            _pendingFileType = fileType;
          }
        } else if (result['url'] != null) {
          final String url = result['url'];

          print('URL en attente au démarrage: $url');

          if (onUrlReceived != null) {
            onUrlReceived!(url);
          } else {
            _pendingUrl = url;
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification du contenu en attente: $e');
    }
  }

  // Traite le contenu en attente quand les callbacks sont définis
  void processPendingContent() {
    // Traiter fichier en attente
    if (_pendingFilePath != null && onFileReceived != null) {
      onFileReceived!(_pendingFilePath!, _pendingFileType!);
      _pendingFilePath = null;
      _pendingFileType = null;
    }

    // Traiter URL en attente
    if (_pendingUrl != null && onUrlReceived != null) {
      onUrlReceived!(_pendingUrl!);
      _pendingUrl = null;
    }
  }

  // Méthode pour réinitialiser après traitement (à appeler une fois le dialogue fermé)
  Future<void> resetProcessedContent() async {
    // Signaler à Android que le fichier a été traité
    try {
      await _channel.invokeMethod('fileProcessed');
    } catch (e) {
      print('Erreur lors de la réinitialisation Android: $e');
    }
  }

  // Méthode pour traiter les URLs JW.org
  Future<void> processJwOrgUrl(String url) async {
    try {
      print('Traitement de l\'URL JW.org: $url');

      // Parser l'URL avec votre classe JwOrgUri existante
      final uri = JwOrgUri.parse(url);

      // Utiliser votre système de navigation existant
      final context = GlobalKeyService.jwLifeAppKey.currentState?.context;
      if (context != null) {
        GlobalKeyService.jwLifeAppKey.currentState!.handleUri(uri);
      }
      else {
        // Si le contexte n'est pas encore prêt, stocker l'URI pour plus tard
        JwOrgUri.startUri = uri;
      }

    } catch (e) {
      print('Erreur lors du traitement de l\'URL JW.org: $e');
    }
  }

  String _getFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jwlibrary':
        return 'jwlibrary';
      case '.jwlplaylist':
        return 'jwlplaylist';
      case '.jwpub':
        return 'jwpub';
      default:
        return 'unknown';
    }
  }

  // Méthodes existantes pour traiter chaque type de fichier
  Future<void> processJwLibraryFile(String filePath) async {
    try {
      print('Traitement du fichier JW Library: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier non trouvé: $filePath');
      }

      await _importJwLibraryFile(file);

      // enlever le fichier
      await file.delete();

    } catch (e) {
      print('Erreur lors du traitement du fichier JW Library: $e');
      throw e;
    }
  }

  Future<void> processJwPlaylistFile(String filePath) async {
    try {
      print('Traitement du fichier JW Playlist: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier non trouvé: $filePath');
      }

      await _importJwPlaylistFile(file);

      // enlever le fichier
      await file.delete();

    } catch (e) {
      print('Erreur lors du traitement du fichier JW Playlist: $e');
      throw e;
    }
  }

  Future<void> processJwPubFile(String filePath, {String keySymbol = '', int issueTagNumber = 0, int mepsLanguageId = 0}) async {
    try {
      print('Traitement du fichier JW Publication: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier non trouvé: $filePath');
      }

      await _importJwPubFile(file, keySymbol: keySymbol, issueTagNumber: issueTagNumber, mepsLanguageId: mepsLanguageId);

      // enlever le fichier
      await file.delete();

    } catch (e) {
      print('Erreur lors du traitement du fichier JW Publication: $e');
      throw e;
    }
  }

  // Méthodes d'importation existantes
  Future<void> _importJwLibraryFile(File file) async {
    BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().context;

    // Teste que c'est bien une archive ZIP valide
    bool isValidZip = false;
    try {
      final bytes = file.readAsBytesSync();
      ZipDecoder().decodeBytes(bytes);
      isValidZip = true;
    } catch (_) {
      isValidZip = false;
    }

    if (!isValidZip) {
      await showJwDialog(
        context: context,
        titleText: i18n().message_restore_failed,
        contentText: i18n().message_restore_failed_explanation,
        buttons: [
          JwDialogButton(
            label: i18n().action_ok,
            closeDialog: true,
          ),
        ],
        buttonAxisAlignment: MainAxisAlignment.end,
      );
      // Réinitialiser après affichage de l'erreur
      resetProcessedContent();
      return;
    }

    // Récupération des infos de sauvegarde
    final info = await getBackupInfo(file);
    if (info == null) {
      await showJwDialog(
        context: context,
        titleText: i18n().message_restore_failed,
        contentText: i18n().message_restore_failed_explanation,
        buttons: [
          JwDialogButton(
            label: i18n().action_ok,
            closeDialog: true,
          ),
        ],
        buttonAxisAlignment: MainAxisAlignment.end,
      );
      // Réinitialiser après affichage de l'erreur
      resetProcessedContent();
      return;
    }

    // Confirmation avant restauration
    final shouldRestore = await showJwDialog<bool>(
      context: context,
      titleText: i18n().action_restore_a_backup,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              i18n().message_restore_a_backup_explanation,
            ),
            const SizedBox(height: 15),
            Text(
              info.deviceName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(timeAgo(info.lastModified)),
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

    if (shouldRestore == true) {
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
                child: getLoadingWidget(Theme.of(context).primaryColor),
              ),
            );
          },
        ),
      );

      await JwLifeApp.userdata.importBackup(file);

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
            label: i18n().action_ok,
            closeDialog: true,
          ),
        ],
        buttonAxisAlignment: MainAxisAlignment.end,
      );

      if (dialogContext != null) Navigator.of(dialogContext!).pop();
      GlobalKeyService.homeKey.currentState?.refreshFavorites();
      GlobalKeyService.personalKey.currentState?.refreshUserdata();

      // Réinitialiser après succès
      resetProcessedContent();
    } else {
      // Réinitialiser si l'utilisateur annule
      resetProcessedContent();
    }
  }

  Future<void> _importJwPlaylistFile(File file) async {
    // Récupère le contexte de la page actuelle.
    BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.navigatorKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].currentState!.context;

    // Sépare le nom du fichier du chemin complet.
    String fileName = file.path.split('/').last;

    // Affiche le dialogue d'importation et attend son BuildContext.
    BuildContext? dialogContext = await showJwImport(context, fileName);

    Playlist? playlist = await JwLifeApp.userdata.importPlaylistFromFile(file);

    // Ferme le dialogue de chargement une fois l'importation terminée.
    if (dialogContext != null) {
      Navigator.of(dialogContext).pop();
    }

    // Gère le résultat de l'importation.
    if (playlist == null) {
      showImportFileError(context, '.jwplaylist');
      // Réinitialiser après erreur
      resetProcessedContent();
    }
    else {
      // on refresh les playlist
      GlobalKeyService.personalKey.currentState?.openPlaylist(playlist);

      if (context.mounted) {
        showBottomMessage(i18n().message_import_playlist_successful);
      }

      // N'oublie pas de réinitialiser aussi ici
      resetProcessedContent();
    }
  }

  Future<void> _importJwPubFile(File file, {String keySymbol = '', int issueTagNumber = 0, int mepsLanguageId = 0}) async {
    // Récupère le contexte de la page actuelle.
    BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.navigatorKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].currentState!.context;

    // Sépare le nom du fichier du chemin complet.
    String fileName = file.path.split('/').last;

    // Affiche le dialogue d'importation et attend son BuildContext.
    BuildContext? dialogContext = await showJwImport(context, fileName);

    // Dézippe le fichier .jwpub en arrière-plan.
    Publication? jwpub = await jwpubUnzip(file.readAsBytesSync());

    // Ferme le dialogue de chargement une fois l'importation terminée.
    if (dialogContext != null) {
      Navigator.of(dialogContext).pop();
    }

    // Gère le résultat de l'importation.
    if (jwpub == null) {
      showImportFileError(context, '.jwpub');
      // Réinitialiser après erreur
      resetProcessedContent();
    }
    else {
      if(keySymbol.isNotEmpty) {
        showJwPubNotGoodFile(keySymbol);
        PubCatalog.updateCatalogCategories();
        GlobalKeyService.homeKey.currentState!.refreshFavorites();
      }
      else {
        showPage(PublicationMenuView(publication: jwpub));
      }

      // Réinitialiser après succès
      resetProcessedContent();
    }
  }
}
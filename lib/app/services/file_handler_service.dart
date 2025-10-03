import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:path/path.dart' as path;

import '../../core/utils/common_ui.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/utils_jwpub.dart';
import '../../core/jworg_uri.dart';
import '../../core/utils/utils_pub.dart';
import '../../core/utils/widgets_utils.dart';
import '../../data/databases/userdata.dart';
import '../../features/publication/pages/menu/local/publication_menu_view.dart';
import '../../widgets/dialog/utils_dialog.dart';

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
      } else {
        // Si le contexte n'est pas encore prêt, stocker l'URI pour plus tard
        JwOrgUri.startUri = uri;
      }

    } catch (e) {
      print('Erreur lors du traitement de l\'URL JW.org: $e');
      // En cas d'erreur de parsing, on peut essayer d'ouvrir dans un navigateur web
      // ou afficher une erreur à l'utilisateur
    }
  }

  String _getFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jwlibrary':
        return 'jwlibrary';
      case '.jwplaylist':
        return 'jwplaylist';
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

    } catch (e) {
      print('Erreur lors du traitement du fichier JW Playlist: $e');
      throw e;
    }
  }

  Future<void> processJwPubFile(String filePath) async {
    try {
      print('Traitement du fichier JW Publication: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier non trouvé: $filePath');
      }

      await _importJwPubFile(file);

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
        titleText: 'Fichier invalide',
        contentText: 'Le fichier sélectionné n’est pas une archive valide.',
        buttons: [
          JwDialogButton(
            label: 'OK',
            closeDialog: true,
          ),
        ],
        buttonAxisAlignment: MainAxisAlignment.end,
      );
      return;
    }

    // Récupération des infos de sauvegarde
    final info = await getBackupInfo(file);
    if (info == null) {
      await showJwDialog(
        context: context,
        titleText: 'Erreur',
        contentText: 'Le fichier de sauvegarde est invalide ou corrompu. Veuillez choisir un autre fichier.',
        buttons: [
          JwDialogButton(
            label: 'OK',
            closeDialog: true,
          ),
        ],
        buttonAxisAlignment: MainAxisAlignment.end,
      );
      return;
    }

    // Confirmation avant restauration
    final shouldRestore = await showJwDialog<bool>(
      context: context,
      titleText: 'Importer une sauvegarde',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Les données de votre étude individuelle sur cet appareil seront écrasées.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF676767),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Appareil : ${info.deviceName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text('Dernière modification : ${timeAgo(info.lastModified)}'),
          ],
        ),
      ),
      buttons: [
        JwDialogButton(
          label: 'ANNULER',
          closeDialog: true,
          result: false,
        ),
        JwDialogButton(
          label: 'RESTAURER',
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
        titleText: 'Importation en cours…',
        content: Builder(
          builder: (ctx) {
            dialogContext = ctx;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                height: 50,
                child: getLoadingWidget(Theme.of(context).primaryColor),
              ),
            );
          },
        ),
      );

      await JwLifeApp.userdata.importBackup(file);

      await showJwDialog(
        context: context,
        titleText: 'Sauvegarde importée',
        contentText: 'La sauvegarde a bien été importée.',
        buttons: [
          JwDialogButton(
            label: 'OK',
            closeDialog: true,
          ),
        ],
        buttonAxisAlignment: MainAxisAlignment.end,
      );

      if (dialogContext != null) Navigator.of(dialogContext!).pop();
      GlobalKeyService.homeKey.currentState?.refreshFavorites();
      GlobalKeyService.personalKey.currentState?.refreshUserdata();
    }
  }

  Future<void> _importJwPlaylistFile(File file) async {
    print('Import JW Playlist: ${file.path}');
  }

  Future<void> _importJwPubFile(File file) async {
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
      showJwpubError(context);
    } else {
      showPage(PublicationMenuView(publication: jwpub));
    }
  }
}
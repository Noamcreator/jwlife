import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:jwlife/data/models/audio.dart';
import 'package:path/path.dart' as path;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_language_dialog.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/publication.dart';

import '../../app/services/global_key_service.dart';
import '../../features/publication/widgets/audio_download_content.dart';
import 'utils_dialog.dart';
import '../api/api.dart';

PopupMenuItem getPubShareMenuItem(Publication publication) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.share),
        SizedBox(width: 8),
        Text('Envoyer le lien'),
      ],
    ),
    onTap: () async {
      publication.shareLink();
    },
  );
}

PopupMenuItem getPubLanguagesItem(BuildContext context, String title, Publication publication) {
  return PopupMenuItem(
    child: Row(
      children: [
        Icon(JwIcons.language),
        SizedBox(width: 8),
        Text(title),
      ],
    ),
    onTap: () {
      showLanguagePubDialog(context, publication).then((languagePub) async {
        if(languagePub != null) {
          languagePub.showMenu(context);
        }
      });
    },
  );
}

PopupMenuItem getPubFavoriteItem(Publication pub) {
  return PopupMenuItem(
    child: Row(
      children: [
        pub.isFavoriteNotifier.value ? Icon(JwIcons.star__fill) : Icon(JwIcons.star),
        SizedBox(width: 8),
        pub.isFavoriteNotifier.value ? Text('Supprimer des favoris') : Text('Ajouter aux favoris')
      ],
    ),
    onTap: () async {
      if (pub.isFavoriteNotifier.value) {
        await JwLifeApp.userdata.removeAFavorite(pub);
        pub.isFavoriteNotifier.value = false;
      }
      else {
        await JwLifeApp.userdata.addInFavorite(pub);
        pub.isFavoriteNotifier.value = true;
      }

      GlobalKeyService.homeKey.currentState?.refreshFavorites();
    },
  );
}

PopupMenuItem getPubDownloadItem(BuildContext context, Publication publication) {
  return PopupMenuItem(
    child: Row(
      children: [
        publication.isDownloadedNotifier.value ? Icon(JwIcons.trash) : Icon(JwIcons.cloud_arrow_down),
        SizedBox(width: 8),
        publication.isDownloadedNotifier.value ? Text('Supprimer') : Text('Télécharger'),
      ],
    ),
    onTap: () async {
      if (publication.isDownloadedNotifier.value) {
         publication.remove(context);
      }
      else {
        publication.download(context);
      }
    },
  );
}

Future<String> extractPublicationDescription(Publication? publication, {String? symbol, int? issueTagNumber, String? mepsLanguage}) async {
  String s = publication?.keySymbol ?? symbol ?? '';
  int iTn = publication?.issueTagNumber ?? issueTagNumber ?? 0;
  String mL = publication?.mepsLanguage.symbol ?? mepsLanguage ?? '';

  // La condition d'appel (iTn == 0 && s.isNotEmpty && mL.isNotEmpty) reste la même
  if (s.isNotEmpty && mL.isNotEmpty) {
    String wolLinkJwOrg = issueTagNumber == 0 ? 'https://www.jw.org/finder?wtlocale=$mL&pub=$s' : 'https://www.jw.org/finder?wtlocale=$mL&pub=$s&issue=$iTn';
    printTime('Fetching publication content: $wolLinkJwOrg');

    try {
      final response = await Api.httpGetWithHeaders(wolLinkJwOrg);
      if (response.statusCode == 200) {
        var document = htmlParser.parse(response.body);

        // --- NOUVELLE VÉRIFICATION DE LA PAGE D'ACCUEIL ---
        // Vérifie si l'élément <body> a l'ID de la page d'accueil.
        // Si c'est le cas, cela signifie qu'il y a eu une redirection (lien invalide),
        // et on retourne une chaîne vide ('').
        var bodyElement = document.querySelector('body');
        if (bodyElement?.attributes['id'] == 'mid1011200') {
          printTime('Redirection vers la page d\'accueil détectée. Retourne une description vide.');
          return '';
        }
        // ----------------------------------------------------

        // La logique existante pour extraire la balise meta 'description'
        var metaDescription = document.querySelector('meta[name="description"]');

        if (metaDescription != null) {
          return metaDescription.attributes['content']?.trim() ?? '';
        }
        // Si la balise meta n'est pas trouvée (et que ce n'est pas la page d'accueil), on retourne aussi une chaîne vide.
        return '';
      }
      else {
        throw Exception('Failed to load publication content (Status: ${response.statusCode})');
      }
    }
    catch (e) {
      printTime('Error fetching publication content: $e');
      return '';
    }
  }
  return '';
}

Future<BuildContext?> showDownloadMediasDialog(BuildContext context, Publication publication) async {
  Completer<BuildContext?> completer = Completer<BuildContext?>();

  List<Audio> audios = publication.audios;

  // Calcul de la taille totale des fichiers audio (avec gestion des valeurs nulles)
  int totalSize = audios.fold(0, (previousValue, element) => previousValue + (element.fileSize ?? 0));

  showJwDialog(
    context: context,
    // Utilisation du Builder pour obtenir le BuildContext (ctx) du dialogue
    content: Builder(
      builder: (ctx) {
        // Le dialogue est construit, on complète le Future
        if (!completer.isCompleted) {
          completer.complete(ctx);
        }

        // On passe le BuildContext du dialogue (ctx) au widget à état
        return AudioDownloadContent(
          audios: audios,
          totalSize: totalSize,
          dialogContext: ctx, // Le contexte nécessaire pour l'appel à download()
        );
      },
    ),
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
        label: 'FERMER',
        closeDialog: true,
      ),
    ],
  );

  return completer.future;
}

Future<BuildContext?> showJwImport(BuildContext context, String fileName) async {
  Completer<BuildContext?> completer = Completer<BuildContext?>();

  showJwDialog(
    context: context,
    titleText: 'Importation du fichier $fileName en cours…',
    content: Builder(
      builder: (ctx) {
        // Le dialogue est construit ici, et le BuildContext est maintenant disponible
        if (!completer.isCompleted) {
          completer.complete(ctx);
        }
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

  return completer.future;
}

void showJwPubNotGoodFile(String keySymbol) {
  final BuildContext context = GlobalKeyService.jwLifePageKey.currentState!.getCurrentState().context;

  showJwDialog(
    context: context,
    titleText: 'Mauvaise publication', // Plus concis
    // Meilleure formulation pour l'utilisateur
    contentText: 'Le fichier .jwpub sélectionné ne correspond pas à la publication requise. Veuillez choisir une publication avec pour symbol "$keySymbol".',
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
        label: 'OK',
        closeDialog: true,
      ),
    ],
  );
}

void showImportFileError(BuildContext context, String extension) {
  showJwDialog(
    context: context,
    titleText: 'Erreur de fichier',
    contentText: 'Le fichier $extension sélectionné est corrompu ou invalide. Veuillez vérifier le fichier et réessayer.',
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
        label: 'OK',
        closeDialog: true,
      ),
    ],
  );
}

bool showInvalidExtensionDialog(BuildContext context, {required String filePath, required String expectedExtension}) {
  // Récupérer proprement l’extension du fichier sélectionné
  String ext = path.extension(filePath).toLowerCase();

  if(ext == expectedExtension) return true;

  // Si aucune extension trouvée
  if (ext.isEmpty) ext = '(aucune extension)';

  showJwDialog(
    context: context,
    titleText: 'Format de fichier invalide',
    contentText:
    'Le fichier sélectionné ($ext) n’est pas au bon format.\n\n'
        'Format attendu : $expectedExtension',
    buttonAxisAlignment: MainAxisAlignment.end,
    buttons: [
      JwDialogButton(
        label: 'OK',
        closeDialog: true,
      ),
    ],
  );

  return false;
}
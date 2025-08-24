import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/app/jwlife_page.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/home/pages/home_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';

import '../../app/services/global_key_service.dart';
import '../../features/publication/pages/document/local/documents_manager.dart';
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
      LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: publication);
      showDialog<Publication?>(
        context: context,
        builder: (context) => languageDialog,
      ).then((languagePub) {
          if (languagePub != null) {
            languagePub.showMenu(context);
          }
        }
      );
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

PopupMenuItem getPubDownloadItem(BuildContext context, Publication publication, {void Function(double downloadProgress)? update}) {
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
  String s = publication?.symbol ?? symbol ?? '';
  int iTn = publication?.issueTagNumber ?? issueTagNumber ?? 0;
  String mL = publication?.mepsLanguage.symbol ?? mepsLanguage ?? '';

  if (iTn == 0 && s.isNotEmpty && mL.isNotEmpty) {
    String wolLinkJwOrg = 'https://www.jw.org/finder?wtlocale=$mL&pub=$s';
    printTime('Fetching publication content: $wolLinkJwOrg');

    try {
      final response = await Api.httpGetWithHeaders(wolLinkJwOrg);
      if (response.statusCode == 200) {
        var document = htmlParser.parse(response.body);
        var metaDescription = document.querySelector('meta[name="description"]');

        if (metaDescription != null) {
          return metaDescription.attributes['content']?.trim() ?? '';
        }
      }
      else {
        throw Exception('Failed to load publication content');
      }
    }
    catch (e) {
      printTime('Error fetching publication content: $e');
      return '';
    }
  }
  return '';
}
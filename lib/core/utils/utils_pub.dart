import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/home/views/home_page.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';

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
      showDialog<Publication>(
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
        await JwLifeApp.userdata.removePubFavorite(pub);
        pub.isFavoriteNotifier.value = false;
      }
      else {
        await JwLifeApp.userdata.addPubFavorite(pub);
        pub.isFavoriteNotifier.value = true;
      }

      HomePage.refreshHomePage();
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
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
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
      showDialog(
        context: context,
        builder: (context) => languageDialog,
      ).then((value) {
          if (value != null) {
            //showPage(context, PublicationMenu(publication: publication, publicationLanguage: value));
          }
        }
      );
    },
  );
}

PopupMenuItem getPubFavoriteItem(Publication pub) {
  bool isFavorite = JwLifeApp.userdata.isPubFavorite(pub);

  return PopupMenuItem(
    child: Row(
      children: [
        isFavorite ? Icon(JwIcons.star_fill) : Icon(JwIcons.star),
        SizedBox(width: 8),
        isFavorite ? Text('Supprimer des favoris') : Text('Ajouter aux favoris')
      ],
    ),
    onTap: () async {
      if (isFavorite) {
        await JwLifeApp.userdata.removePubFavorite(pub);
      }
      else {
        await JwLifeApp.userdata.addPubFavorite(pub);
      }

      HomeView.refreshHomeView();
    },
  );
}

PopupMenuItem getPubDownloadItem(BuildContext context, Publication publication, {void Function(double downloadProgress)? update}) {
  return PopupMenuItem(
    child: Row(
      children: [
        publication.isDownloaded ? Icon(JwIcons.trash) : Icon(JwIcons.cloud_arrow_down),
        SizedBox(width: 8),
        publication.isDownloaded ? Text('Supprimer') : Text('Télécharger'),
      ],
    ),
    onTap: () async {
      if (publication.isDownloaded) {
         publication.remove(context, update: update);
      }
      else {
        publication.download(context, update: update);
      }
    },
  );
}
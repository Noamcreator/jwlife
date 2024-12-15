import 'package:flutter/material.dart';
import 'package:jwlife/utils/utils_jwpub.dart';
import 'package:share_plus/share_plus.dart';

import '../jwlife.dart';
import '../pages/library_pages/publication_pages/online/publication_menu.dart';
import '../widgets/dialog/language_dialog_pub.dart';

PopupMenuItem getPubShareMenuItem(dynamic pub) {
  return PopupMenuItem(
    child: Text('Envoyé le lien'),
    onTap: () async {
      String issue = pub['IssueTagNumber'] == 0 ? '' : "&issue=${pub['IssueTagNumber']}";
      Share.share(
        'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${pub['LanguageSymbol']}&prefer=lang&pub=${pub['Symbol']}$issue',
        subject: pub['Title'],
      );
    },
  );
}

PopupMenuItem getPubLanguagesItem(BuildContext context, String title, dynamic pub) {
  return PopupMenuItem(
    child: Text(title),
    onTap: () {
      LanguagesPubDialog languageDialog = LanguagesPubDialog(publication: pub);
      showDialog(
        context: context,
        builder: (context) => languageDialog,
      ).then((value) {
        if (value != null) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                return PublicationMenu(publication: pub, publicationLanguage: value);
              },
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      }
      );
    },
  );
}

PopupMenuItem getPubFavoriteItem(dynamic pub) {
  bool isFavorite = pub['isFavorite'] == 1 ? true : false;
  return PopupMenuItem(
    child: isFavorite ? Text('Supprimer des favoris') : Text('Ajouter aux favoris'),
    onTap: () async {
      if (isFavorite) {
        await JwLifeApp.userdata.removePubFavorite(pub);
        pub['isFavorite'] = false;
      }
      else {
        await JwLifeApp.userdata.addPubFavorite(pub);
        pub['isFavorite'] = true;
      }
    },
  );
}

PopupMenuItem getPubDownloadItem(BuildContext context, dynamic pub) {
  bool isDownload = pub['isDownload'] == 1 ? true : false;
  return PopupMenuItem(
    child: isDownload ? Text('Supprimer') : Text('Télécharger'),
    onTap: () async {
      if (isDownload) {
        await removeJwpubFile(pub);
        pub['isDownload'] = false;
      }
      else {
        Map<String, dynamic> jwpub = await downloadJwpubFile(pub, context);
        pub['isDownload'] = true;
        pub['Path'] = jwpub['Path'];
        pub['DatabasePath'] = jwpub['DatabasePath'];
        pub['Hash'] = jwpub['Hash'];
      }
    },
  );
}
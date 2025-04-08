import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_menu_local.dart';
import 'package:jwlife/modules/library/views/publication/online/publication_menu.dart';
import 'package:jwlife/widgets/dialog/language_dialog_pub.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

import 'common_ui.dart';
import 'utils_jwpub.dart';

void showPublicationMenu(BuildContext context, dynamic publication) async {
  if (publication['isDownload'] == 1) {
    showPage(context, PublicationMenuLocal(publication: publication));
  }
  else {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    if(connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.ethernet)) {
      showPage(context, PublicationMenu(publication: publication));
    }
    else {
      showNoConnectionDialog(context);
    }
  }
}

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
            showPage(context, PublicationMenu(publication: pub, publicationLanguage: value));
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
        pub['isFavorite'] = 0;
      }
      else {
        await JwLifeApp.userdata.addPubFavorite(pub);
        pub['isFavorite'] = 1;
      }

      HomeView.setStateFavorites();
    },
  );
}

PopupMenuItem getPubDownloadItem(BuildContext context, Map<String, dynamic> pub, {void Function()? update}) {
  bool isDownload = pub['isDownload'] == 1;
  return PopupMenuItem(
    child: isDownload ? Text('Supprimer') : Text('Télécharger'),
    onTap: () async {
      if (isDownload) {
         removePublication(context, pub, update: update);
      }
      else {
        downloadPublication(context, pub, update: update);
      }
    },
  );
}

void downloadPublication(BuildContext context, Map<String, dynamic> pub, {void Function()? update}) async {
  Map<String, dynamic> jwpub = await downloadJwpubFile(pub, context, update: update);
  pub['isDownload'] = 1;
  pub['Path'] = jwpub['Path'];
  pub['DatabasePath'] = jwpub['DatabasePath'];
  pub['Hash'] = jwpub['Hash'];

  if (update != null) {
    update();
  }

  showBottomMessageWithAction(context, 'Publication téléchargée',
  SnackBarAction(
      label: 'Ouvrir',
      textColor: Theme.of(context).primaryColor,
      onPressed: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showPage(context, PublicationMenuLocal(publication: pub));
      }
  ));
}

void removePublication(BuildContext context, Map<String, dynamic> pub, {void Function()? update}) async {
  await removeJwpubFile(pub);
  pub['isDownload'] = 0;
  pub['Path'] = null;
  pub['DatabasePath'] = null;
  pub['Hash'] = null;

  if (update != null) {
    update();
  }

  showBottomMessage(context, 'Publication supprimée');
}
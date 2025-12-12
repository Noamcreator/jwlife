import 'package:flutter/material.dart';
import 'package:jwlife/data/models/userdata/playlist.dart';
import 'package:jwlife/i18n/i18n.dart';

import '../../../app/app_page.dart';
import '../../../app/jwlife_app_bar.dart';
import '../../../app/services/global_key_service.dart';
import '../../../core/icons.dart';
import '../../../core/utils/utils_import_export.dart';
import '../../../data/databases/history.dart';
import '../../../widgets/responsive_appbar_actions.dart';
import 'study_page.dart';

class PersonalPage extends StatefulWidget {
  const PersonalPage({super.key});

  @override
  PersonalPageState createState() => PersonalPageState();
}

class PersonalPageState extends State<PersonalPage> {
  final GlobalKey<StudyTabViewState> _studyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  // 🔹 Méthode pour forcer le refresh
  void refreshUserdata() {
    _studyKey.currentState?.reloadData();
  }

  void refreshPlaylist() {
    _studyKey.currentState?.refreshPlaylist();
  }

  void openPlaylist(Playlist playlist) {
    // fermer d'abord toutes les pages
    GlobalKeyService.jwLifePageKey.currentState?.changeNavBarIndex(5, goToFirstPage: true);
    _studyKey.currentState?.openPlaylist(playlist);
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = Directionality.of(context) == TextDirection.rtl;
    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().navigation_personal,
        actions: [
          IconTextButton(
              icon: const Icon(JwIcons.cloud_arrow_up),
              text: i18n().settings_userdata_import,
              onPressed: (anchorContext) {
                final List<PopupMenuEntry> menuItems = [
                  PopupMenuItem(
                    value: 'import', // champ: year, ordre: descendant (car année > -> plus récent)
                    child: Text(i18n().settings_userdata_import),
                  ),
                  PopupMenuItem(
                    value: 'export', // champ: year, ordre: ascendant
                    child: Text(i18n().settings_userdata_export),
                  ),

                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'reset',
                    child: Text(i18n().settings_userdata_reset),
                  ),
                ];

                // 2. Afficher le menu avec les options
                showMenu(
                  context: context,
                  elevation: 8.0,
                  items: menuItems,
                  initialValue: null,
                  position: RelativeRect.fromLTRB(
                    isRtl ? 10 : MediaQuery.of(context).size.width - 210, // left
                    40, // top
                    isRtl ? MediaQuery.of(context).size.width - 210 : 10, // right
                    0, // bottom
                  ),
                ).then((res) {
                  if (res != null) {
                    switch (res) {
                      case 'import':
                        handleImport(context);
                        break;
                      case 'export':
                        handleExport(context);
                        break;
                      case 'reset':
                        handleResetUserdata(context);
                        break;
                    }
                  }
                });
              }
          ),
          IconTextButton(text: i18n().action_history, icon: Icon(JwIcons.arrow_circular_left_clock), onPressed: (anchorContext) { History.showHistoryDialog(context); }),
        ],
      ),
      body: StudyTabView(
        key: _studyKey, // 🔹 associer la clé
      ),
    );
  }
}
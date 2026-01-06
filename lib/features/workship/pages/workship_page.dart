import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_page.dart';
import '../../../app/jwlife_app.dart';
import '../../../app/jwlife_app_bar.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/app_data/meetings_pubs_service.dart';
import '../../../core/shared_preferences/shared_preferences_keys.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/ui/text_styles.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_audio.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../../data/databases/history.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/userdata/congregation.dart';
import '../../../widgets/dialog/qr_code_dialog.dart';
import '../../../widgets/responsive_appbar_actions.dart';
import '../../document/data/models/document.dart';
import '../../document/local/documents_manager.dart';
import '../../publication/pages/local/publication_menu_view.dart';
import 'brothers_and_sisters_page.dart';
import 'congregations_page.dart';

class WorkShipPage extends StatefulWidget {
  const WorkShipPage({super.key});

  @override
  WorkShipPageState createState() => WorkShipPageState();
}

class WorkShipPageState extends State<WorkShipPage> with TickerProviderStateMixin {
  final _congregationValue = ValueNotifier<Congregation?>(null);
  final _dateOfMeetingValue = ValueNotifier(DateTime.now());

  bool _isOtherPublicationsToggle = true;

  bool _isCircuitCoToggle = true;
  bool _isCircuitBrToggle = true;
  bool _isConventionToggle = true;

  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  int _animKey = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    fetchFirstCongregation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> goToTheMeetingsTab() async {
    _tabController.animateTo(0);
    _dateOfMeetingValue.value = DateTime.now();
    _isOtherPublicationsToggle = true;
    _isCircuitCoToggle = true;
    _isCircuitBrToggle = true;
    _isConventionToggle = true;

    fetchFirstCongregation();
    List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(JwLifeSettings.instance.workshipLanguage.value, date: _dateOfMeetingValue.value);

    setState(() {
      _animKey++; 
    });

    refreshMeetingsPubs(pubs: dayPubs);
  }

  Future<void> fetchFirstCongregation() async {
    final congregation = await JwLifeApp.userdata.getCongregations();
    if (congregation.isEmpty) {
      return;
    }
    _congregationValue.value = congregation.firstOrNull;
  }

  // Afficher un menu qui me propose de choisir toutes les congrégations
  void showCongregationsMenu(Offset tapPosition) async {
    // 1. Récupérer la liste des congrégations
    final congregations = await JwLifeApp.userdata.getCongregations();
    if (congregations.isEmpty) return;

    // 2. Afficher le menu flottant
    final selected = await showMenu<Congregation>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        tapPosition.dx,
        tapPosition.dy,
      ),
      items: congregations.map((cong) {
        return PopupMenuItem<Congregation>(
          value: cong,
          child: Row(
            children: [
              Icon(
                JwIcons.kingdom_hall, 
                color: _congregationValue.value?.guid == cong.guid ? Theme.of(context).primaryColor : Colors.grey
              ),
              const SizedBox(width: 10),
              Text(cong.name),
            ],
          ),
        );
      }).toList(),
    );

    // 3. Mettre à jour la congrégation sélectionnée
    if (selected != null) {
      _congregationValue.value = selected;
    }
  }

  void refreshSelectedDay(DateTime selectedDay) {
    _dateOfMeetingValue.value = selectedDay;

    setState(() {
    _animKey++; 
    });
  }

  int getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysPassed = date.difference(firstDayOfYear).inDays;
    return (daysPassed / 7).ceil();
  }

  String formatWeekRange(DateTime date) {
    // Utilisation de la locale sécurisée (gère le fallback pour 'ay', etc.)
    final String locale = getSafeLocale();

    // Fonction pour normaliser une date en supprimant l'heure
    DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

    // Normalisation de la date reçue
    DateTime normalizedDate = normalize(date);

    // Déterminer la semaine associée à "date" (Lundi au Dimanche)
    DateTime firstDayOfWeek = normalize(
        normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1)));
    DateTime lastDayOfWeek = normalize(
        firstDayOfWeek.add(const Duration(days: 6)));

    // Déterminer le début de la semaine actuelle pour la comparaison
    final now = DateTime.now();
    DateTime currentWeekStart = normalize(
        now.subtract(Duration(days: now.weekday - 1)));

    // Formatage jours et mois avec la locale sécurisée
    String day1 = DateFormat('d', locale).format(firstDayOfWeek);
    String day2 = DateFormat('d', locale).format(lastDayOfWeek);
    String month1 = DateFormat('MMMM', locale).format(firstDayOfWeek);
    String month2 = DateFormat('MMMM', locale).format(lastDayOfWeek);

    // Texte formaté via i18n
    String base = month1 == month2
        ? i18n().label_date_range_one_month(day1, day2, month1)
        : i18n().label_date_range_two_months(day1, day2, month1, month2);

    // Vérification : est-ce la semaine actuelle ?
    // Si le lundi de la date choisie est le même que le lundi d'aujourd'hui
    bool isThisWeek = firstDayOfWeek.isAtSameMomentAs(currentWeekStart);

    // Ajout du label "Cette semaine"
    if (isThisWeek) {
      return "$base • ${i18n().labels_this_week}";
    }

    return base;
  }

  void _showPublicTalksDialog() async {
    DocumentsManager documentsManager;

    if (AppDataService.instance.publicTalkPub.value!.documentsManager != null) {
      documentsManager = AppDataService.instance.publicTalkPub.value!.documentsManager!;
    }
    else {
      documentsManager = DocumentsManager(publication: AppDataService.instance.publicTalkPub.value!);
      await documentsManager.initializeDatabaseAndData();
    }

    final result = await showDialog<Document>(
      context: context,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        List<Document> filteredDocuments = List.from(documentsManager.documents);

        return StatefulBuilder(
          builder: (context, localSetState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: MediaQuery
                    .of(context)
                    .size
                    .width,
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                      child: Text(
                        i18n().action_public_talk_choose,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Icon(
                            JwIcons.magnifying_glass,
                            color: const Color(0xFF9d9d9d),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              autocorrect: false,
                              enableSuggestions: false,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                hintText: 'Rechercher un discours',
                                hintStyle: TextStyle(fontSize: 18),
                              ),
                              onChanged: (value) {
                                localSetState(() {
                                  filteredDocuments =
                                      documentsManager.documents.where((
                                          document) {
                                        return document.title
                                            .toLowerCase()
                                            .contains(value.toLowerCase());
                                      }).toList();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredDocuments.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocuments[index];
                          return ListTile(
                            title: Text(
                              doc.title,
                              style: TextStyle(
                                color: Theme
                                    .of(context)
                                    .brightness == Brightness.dark
                                    ? const Color(0xFF9fb9e3)
                                    : const Color(0xFF4a6da7),
                                fontSize: 16.0,
                                height: 1.2,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context, doc);
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        child: Text(
                          i18n().action_cancel_uppercase,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                            color: Theme
                                .of(context)
                                .primaryColor,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, null);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      AppDataService.instance.selectedPublicTalk.value = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color defaultMeetingColor = Color(0xFF2C3E50);

    final TabBar tabBarWidget = TabBar(
      controller: _tabController,
      tabAlignment: TabAlignment.fill,
      tabs: [
        Tab(text: i18n().navigation_workship_meetings),
        Tab(text: i18n().navigation_workship_conventions),
      ],
      dividerHeight: 1,
      dividerColor: const Color(0xFF686868),
    );

    return AppPage(
      appBar: JwLifeAppBar(
        canPop: false,
        title: i18n().navigation_workship,
        subTitleWidget: ValueListenableBuilder(valueListenable: JwLifeSettings.instance.workshipLanguage, builder: (context, value, child) {
          return Text(value.vernacular, style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle);
        }),
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.language),
            text: i18n().label_languages_more,
            onPressed: (anchorContext) {
              showLanguageDialog(context, firstSelectedLanguage: JwLifeSettings.instance.workshipLanguage.value.symbol).then((language) async {
                if (language != null) {
                  if (language['Symbol'] != JwLifeSettings.instance.workshipLanguage.value.symbol) {
                    await AppSharedPreferences.instance.setWorkshipLanguage(language);
                    AppDataService.instance.changeWorkshipLanguageAndRefresh();
                  }
                }
              });
            },
          ),
          IconTextButton(
            icon: const Icon(JwIcons.calendar),
            text: i18n().label_select_a_week,
            onPressed: (anchorContext) async {
              DateTime? selectedDay = await showMonthCalendarDialog(context, _dateOfMeetingValue.value);
              if (selectedDay != null) {
                List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(JwLifeSettings.instance.workshipLanguage.value, date: selectedDay);

                refreshSelectedDay(selectedDay);
                refreshMeetingsPubs(pubs: dayPubs, date: selectedDay);
              }
            },
          ),
          IconTextButton(
            text: i18n().action_history,
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: (anchorContext) {
              JwLifeApp.history.showHistoryDialog(context);
            },
          ),
          IconTextButton(
            text: i18n().action_open_in_share,
            icon: const Icon(JwIcons.share),
            onPressed: (anchorContext) {
              String uri = JwOrgUri.meetings(
                  wtlocale: JwLifeSettings.instance.workshipLanguage.value.symbol,
                  date: convertDateTimeToIntDate(_dateOfMeetingValue.value).toString()
              ).toString();

              SharePlus.instance.share(
                  ShareParams(title: formatWeekRange(_dateOfMeetingValue.value),
                      uri: Uri.tryParse(uri))
              );
            },
          ),
          IconTextButton(
            text: i18n().action_qr_code,
            icon: const Icon(JwIcons.qr_code),
            onPressed: (anchorContext) {
              String uri = JwOrgUri.meetings(
                  wtlocale: JwLifeSettings.instance.workshipLanguage.value.symbol,
                  date: convertDateTimeToIntDate(_dateOfMeetingValue.value).toString()
              ).toString();

              showQrCodeDialog(context, formatWeekRange(_dateOfMeetingValue.value), uri);
            },
          ),
          IconTextButton(
            text: i18n().action_congregations,
            icon: const Icon(JwIcons.kingdom_hall),
            onPressed: (anchorContext) {
              showPage(CongregationsPage());
            },
          ),
          IconTextButton(
            text: i18n().action_meeting_management,
            icon: const Icon(JwIcons.calendar),
            onPressed: (anchorContext) {
              //showPage(CongregationsPage());
            },
          ),
          IconTextButton(
            text: i18n().action_brothers_and_sisters,
            icon: const Icon(JwIcons.brother_sister),
            onPressed: (anchorContext) {
              showPage(BrothersAndSistersPage());
            },
          ),
        ],
      ),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) =>
        [
          SliverAppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            pinned: true,
            backgroundColor: Theme
                .of(context)
                .brightness == Brightness.dark
                ? const Color(0xFF111111)
                : Colors.white,
            bottom: PreferredSize(
              preferredSize: tabBarWidget.preferredSize,
              child: tabBarWidget,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: RÉUNIONS
            SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ValueListenableBuilder(
                    valueListenable: _dateOfMeetingValue,
                    builder: (context, value, child) {
                      return ValueListenableBuilder(
                        valueListenable: _congregationValue,
                        builder: (context, congregation, child) {
                          return congregation == null || congregation.nextMeeting(value) == null
                              ? const SizedBox.shrink()
                              : Builder(
                            builder: (context) {
                              final nextMeeting = congregation.nextMeeting(value);
                              final nextNextMeeting = congregation.nextNextMeeting(value);
                          
                              if (nextMeeting == null) return const SizedBox.shrink();
                          
                              // --- Données Réunion 1 ---
                              final date1 = nextMeeting["date"] as DateTime;
                              final type = nextMeeting["type"] as String;
                              final icon = (type == "midweek") ? JwIcons.sheep : JwIcons.watchtower;
                          
                              // --- Données Réunion 2 ---
                              DateTime? date2;
                              String? formatData2;
                              
                              if (nextNextMeeting != null) {
                                date2 = nextNextMeeting["date"] as DateTime;
                              }
                          
                              final locale = getSafeLocale();
  
                              // Formater la réunion 1
                              final dateStr1 = DateFormat("EEEE d MMMM", locale).format(date1);
                              final formatData1 = i18n().label_date_next_meeting(
                                dateStr1, 
                                DateFormat("HH", locale).format(date1), 
                                DateFormat("mm", locale).format(date1)
                              );
                          
                              // Formater la réunion 2 (si elle existe)
                              if (date2 != null) {
                                final dateStr2 = DateFormat("EEEE d MMMM", locale).format(date2);
                                formatData2 = i18n().label_date_next_meeting(
                                  dateStr2, 
                                  DateFormat("HH", locale).format(date2), 
                                  DateFormat("mm", locale).format(date2)
                                );
                              }

                              Offset tapPosition = Offset.zero;
                          
                              return Material(
                                color: Colors.transparent,
                                child: GestureDetector(
                                  onTapDown: (details) => tapPosition = details.globalPosition,
                                  child: InkWell(
                                    onTap: () => showPage(CongregationsPage()),
                                    onLongPress: () => showCongregationsMenu(tapPosition),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Colors.transparent,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(width: 20),
                                          AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 300), // 300ms pour sortir, 300ms pour entrer = 600ms total
                                            
                                            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                              if (previousChildren.isNotEmpty) {
                                                return previousChildren.first; 
                                              }
                                              return currentChild ?? const SizedBox.shrink();
                                            },
                                                            
                                            transitionBuilder: (Widget child, Animation<double> animation) {
                                              final isRTL = Directionality.of(context) == TextDirection.rtl;
                                              
                                              // On définit le décalage vers le bord
                                              final edgeOffset = isRTL ? const Offset(8.0, 0.0) : const Offset(-8.0, 0.0);
                                                            
                                              final isEntering = child.key == ValueKey<int>(_animKey);
                                                            
                                              return SlideTransition(
                                                position: Tween<Offset>(
                                                  // Entrée : Bord -> Centre (0.0)
                                                  // Sortie : Centre (0.0) -> Bord
                                                  begin: isEntering ? edgeOffset : Offset.zero,
                                                  end: isEntering ? Offset.zero : edgeOffset,
                                                ).animate(CurvedAnimation(
                                                  parent: animation,
                                                  // On utilise la même courbe pour les deux, mais inversée par le Tween
                                                  curve: Curves.easeInOutQuart
                                                )),
                                                child: child,
                                              );
                                            },
                                            
                                            child: Icon(
                                              icon,
                                              key: ValueKey<int>(_animKey),
                                              color: Theme.of(context).primaryColor,
                                              size: 50,
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  congregation.name,
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme
                                                        .of(context)
                                                        .brightness == Brightness.dark
                                                        ? Colors.white70
                                                        : const Color(0xFF686868),
                                                  ),
                                                ),
                                                Text(
                                                  formatData1,
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Theme
                                                        .of(context)
                                                        .brightness == Brightness.dark
                                                        ? Colors.white70
                                                        : const Color(0xFF686868),
                                                  ),
                                                ),
                                                if (formatData2 != null) ...[
                                                  Text(
                                                    formatData2,
                                                    textAlign: TextAlign.left,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Theme
                                                          .of(context)
                                                          .brightness == Brightness.dark
                                                          ? Colors.white70
                                                          : const Color(0xFF686868),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      );
                    }
                  ),

                  const SizedBox(height: 5),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -2), // Rend la liste plus compacte
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          DateTime newDate = _dateOfMeetingValue.value.subtract(const Duration(days: 7));
                          List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(JwLifeSettings.instance.workshipLanguage.value, date: newDate);

                          refreshSelectedDay(newDate);
                          refreshMeetingsPubs(pubs: dayPubs, date: newDate);
                        },
                        icon: Icon(JwIcons.chevron_left),
                      ),
                      TextButton(
                        onPressed: () async {
                          DateTime? selectedDay = await showMonthCalendarDialog(context, _dateOfMeetingValue.value);
                          if (selectedDay != null) {
                            List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(JwLifeSettings.instance.workshipLanguage.value, date: selectedDay);

                            refreshSelectedDay(selectedDay);
                            refreshMeetingsPubs(pubs: dayPubs, date: selectedDay);
                          }
                        },
                        child: ValueListenableBuilder(
                          valueListenable: _dateOfMeetingValue,
                          builder: (context, value, _) {
                            return Text(formatWeekRange(value), style: const TextStyle(fontSize: 15), maxLines: 2);
                          },
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          DateTime newDate = _dateOfMeetingValue.value.add(const Duration(days: 7));
                          List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(JwLifeSettings.instance.workshipLanguage.value, date: newDate);

                          refreshSelectedDay(newDate);
                          refreshMeetingsPubs(pubs: dayPubs, date: newDate);
                        },
                        icon: Icon(JwIcons.chevron_right),
                      ),
                    ],
                  ),

                  // Carte Réunion Vie et Ministère
                  _buildMeetingCard(
                    context: context,
                    title: i18n().navigation_workship_life_and_ministry,
                    icon: JwIcons.sheep,
                    child: _isMidweekMeetingContentIsDownload(context, _dateOfMeetingValue.value),
                  ),

                  const SizedBox(height: 25),

                  // Carte Étude de la Tour de Garde
                  _buildMeetingCard(
                    context: context,
                    title: i18n().navigation_workship_watchtower_study,
                    icon: JwIcons.watchtower,
                    child: _isWeekendMeetingContentIsDownload(context, _dateOfMeetingValue.value),
                  ),

                  const SizedBox(height: 25),

                  // Carte Autres Publications
                  _buildExpandableCard(
                    context: context,
                    title: i18n().label_other_meeting_publications,
                    icon: JwIcons.book_stack,
                    color: defaultMeetingColor,
                    child: _meetingsPublications(context),
                    isExpanded: _isOtherPublicationsToggle,
                    onToggle: () {
                      setState(() =>
                      _isOtherPublicationsToggle = !_isOtherPublicationsToggle);
                    },
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),

            // TAB 2: ASSEMBLÉES
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte Assemblée de Circonscription (BR)
                  _buildExpandableCard(
                    context: context,
                    title: i18n().navigation_workship_assembly_br,
                    icon: JwIcons.arena,
                    color: defaultMeetingColor,
                    child: _isCircuitBrContentIsDownload(context),
                    isExpanded: _isCircuitBrToggle,
                    onToggle: () {
                      setState(() => _isCircuitBrToggle = !_isCircuitBrToggle);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Carte Assemblée de Circonscription (CO)
                  _buildExpandableCard(
                    context: context,
                    title: i18n().navigation_workship_assembly_co,
                    icon: JwIcons.arena,
                    color: defaultMeetingColor,
                    child: _isCircuitCoContentIsDownload(context),
                    isExpanded: _isCircuitCoToggle,
                    onToggle: () {
                      setState(() => _isCircuitCoToggle = !_isCircuitCoToggle);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Carte Assemblée Régionale/Internationale
                  _buildExpandableCard(
                    context: context,
                    title: i18n().navigation_workship_convention,
                    icon: JwIcons.arena,
                    color: defaultMeetingColor,
                    child: _isConventionContentIsDownload(context),
                    isExpanded: _isConventionToggle,
                    onToggle: () {
                      setState(() =>
                      _isConventionToggle = !_isConventionToggle);
                    },
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child
  }) {
    TextDirection textDirection = JwLifeSettings.instance.workshipLanguage.value.isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Column(
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme
                    .of(context)
                    .brightness == Brightness.dark ? Colors.white : Colors
                    .black,
              ),
            ),
          ],
        ),

        // Separator
        const SizedBox(height: 2),

        Directionality(textDirection: textDirection, child: child)
      ],
    );
  }

  Widget _buildExpandableCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque, // Améliore la zone de clic
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white 
                        : Colors.black,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  JwIcons.chevron_right,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        ClipRect( // Évite les débordements d'animation
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? SizedBox(
                      width: double.infinity,
                      child: child,
                    )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        )
      ],
    );
  }

  Widget _isMidweekMeetingContentIsDownload(BuildContext context, DateTime weekRange) {
    return ValueListenableBuilder<Publication?>(
      valueListenable: AppDataService.instance.midweekMeetingPub,
      builder: (context, midweekPub, _) {

        // --- 1) Aucune publication disponible ---
        if (midweekPub == null) {
          return _buildEmptyState(
            context,
            i18n().message_no_midweek_meeting_content,
            JwIcons.sheep,
          );
        }

        // --- 2) Écoute si la publication est téléchargée ---
        return ValueListenableBuilder<bool>(
          valueListenable: midweekPub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {

            // Publication non téléchargée → bouton télécharger
            if (!isDownloaded) {
              return _buildDownloadState(context, midweekPub);
            }

            // --- 3) Publication téléchargée → écouter le contenu généré ---
            return ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: AppDataService.instance.midweekMeeting,
              builder: (context, midweekMeetingData, _) {

                // Contenu généré et disponible → afficher le contenu
                if (midweekMeetingData != null) {
                  return _buildMidweekContentState(context, midweekPub, midweekMeetingData);
                }

                // Publication téléchargée mais contenu pas encore généré
                return const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }

  Widget _isWeekendMeetingContentIsDownload(BuildContext context, DateTime weekRange) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFF9fb9e3) : const Color(0xFF4a6da7);
    final subtitleColor = isDark ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final TextStyle titleStyle = TextStyle(fontSize: 15, color: titleColor, height: 1.1);

    final TextStyle contextStyle = TextStyle(fontSize: 13, color: subtitleColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ValueListenableBuilder<Publication?>(
          valueListenable: AppDataService.instance.publicTalkPub,
          builder: (context, publicTalkPub, _) {
            if (publicTalkPub == null) return const SizedBox.shrink();

            final isRTL = publicTalkPub.mepsLanguage.isRtl;

            return Directionality(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: ValueListenableBuilder<Document?>(
                valueListenable: AppDataService.instance.selectedPublicTalk,
                builder: (context, selectedTalk, _) {
                  return Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onLongPress: _showPublicTalksDialog,
                          onTap: () {
                            if (selectedTalk != null) {
                              showPageDocument(
                                  publicTalkPub, selectedTalk.mepsDocumentId);
                            } else {
                              _showPublicTalksDialog();
                            }
                          },
                          child: Stack(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    margin: EdgeInsetsDirectional.only(end: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        color: isDark
                                            ? const Color(0xFF4f4f4f)
                                            : const Color(0xFF8e8e8e),
                                        child: const Center(
                                          child: Icon(
                                            JwIcons.document_speaker,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(top: 4.0, end: 30),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(publicTalkPub.getTitle().toUpperCase(), style: contextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2.0),
                                          Text(selectedTalk?.title ?? i18n().label_workship_public_talk_choosing, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              PositionedDirectional(
                                top: -15,
                                end: -7,
                                child: PopupMenuButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_horiz,
                                      color: Color(0xFF9d9d9d)),
                                  itemBuilder: (context) {
                                    return [
                                      PopupMenuItem(
                                        onTap: _showPublicTalksDialog,
                                        child: Row(
                                          children: [
                                            Icon(
                                              JwIcons.document_speaker,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(selectedTalk != null
                                                ? i18n().action_public_talk_replace
                                                : i18n().action_public_talk_choose),
                                          ],
                                        ),
                                      ),
                                      if (selectedTalk != null)
                                        PopupMenuItem(
                                          onTap: () {
                                            AppDataService.instance.selectedPublicTalk.value = null;
                                          },
                                          child: Row(
                                            children: [
                                              Icon(JwIcons.trash,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black),
                                              const SizedBox(width: 8),
                                              Text(i18n().action_public_talk_remove),
                                            ],
                                          ),
                                        ),
                                    ];
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
            );
          },
        ),

        // ----------------------------------------------------------
        // B) PUBLICATION DU WEEK-END
        // ----------------------------------------------------------
        ValueListenableBuilder<Publication?>(
          valueListenable: AppDataService.instance.weekendMeetingPub,
          builder: (context, weekendPub, _) {
            if (weekendPub == null) {
              return _buildEmptyState(
                context,
                i18n().message_no_weekend_meeting_content,
                JwIcons.watchtower,
              );
            }

            return ValueListenableBuilder<bool>(
              valueListenable: weekendPub.isDownloadedNotifier,
              builder: (context, isDownloaded, _) {
                if (!isDownloaded) {
                  return _buildDownloadState(context, weekendPub);
                }

                return ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: AppDataService.instance.weekendMeeting,
                  builder: (context, weekendMeetingData, _) {
                    if (weekendMeetingData == null) {
                      return const SizedBox.shrink();
                    }

                    return _buildWeekendContent(
                        context, weekendPub, weekendMeetingData);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _meetingsPublications(BuildContext context) {
    return ValueListenableBuilder<Publication?>(
      valueListenable: AppDataService.instance.midweekMeetingPub,
      builder: (context, midweekPub, _) {
        return ValueListenableBuilder<Publication?>(
          valueListenable: AppDataService.instance.weekendMeetingPub,
          builder: (context, weekendPub, _) {
            return ValueListenableBuilder<Publication?>(
              valueListenable: AppDataService.instance.publicTalkPub,
              builder: (context, publicTalkPub, _) {
                return ValueListenableBuilder<List<Publication>>(
                  valueListenable: AppDataService.instance.otherMeetingsPublications,
                  builder: (context, otherPubs, _) {

                    // --- Construire la liste complète des publications ---
                    final List<Publication> publications = [
                      if (midweekPub != null) midweekPub,
                      if (weekendPub != null) weekendPub,
                      if (publicTalkPub != null) publicTalkPub,
                      ...otherPubs
                    ];

                    // --- Construire les widgets ---
                    final List<Widget> children = [];

                    for (int i = 0; i < publications.length; i++) {
                      children.add(
                        RectanglePublicationItem(
                          publication: publications[i],
                          backgroundColor: Colors.transparent,
                          height: 70,
                        ),
                      );

                      if (i < publications.length - 1) {
                        children.add(const SizedBox(height: 8));
                      }
                    }

                    final bool isRtl = JwLifeSettings.instance.workshipLanguage.value.isRtl;
                    final TextDirection textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;

                    return Directionality(
                      textDirection: textDirection,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    return Padding(
        padding: EdgeInsetsGeometry.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
    );
  }

  Widget _buildDownloadState(BuildContext context, Publication publication) {
    return Padding(
        padding: const EdgeInsetsGeometry.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              publication.issueTitle,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<double>(
              valueListenable: publication.progressNotifier,
              builder: (context, value, _) {
                if (value == 0) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme
                          .of(context)
                          .primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      publication.download(context);
                    },
                    child: Text(
                      i18n().action_download_uppercase,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
                return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: value == -1 ? null : value,
                            minHeight: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme
                                .of(context)
                                .primaryColor),
                            backgroundColor: Theme
                                .of(context)
                                .brightness == Brightness.dark ? Colors
                                .grey[800] : Colors.grey[300],
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton(
                          onPressed: () {
                            publication.cancelDownload();
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(JwIcons.x),
                        ),
                      ],
                    )
                );
              },
            ),
          ],
        )
    );
  }

  Widget _buildMidweekContentState(BuildContext context, Publication midweekPub, Map<String, dynamic> midweekMeeting) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFF9fb9e3) : const Color(0xFF4a6da7);
    final Color subtitleColor = isDark ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final TextStyle titleStyle = TextStyle(fontSize: 15, color: titleColor, height: 1.1);
    final TextStyle contextStyle = TextStyle(fontSize: 13, color: subtitleColor);

    final String imageFullPath = '${midweekPub.path!}/${midweekMeeting['FilePath']}';
    final isRTL = midweekPub.mepsLanguage.isRtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: ValueListenableBuilder(
        valueListenable: midweekPub.audiosNotifier,
        builder: (context, audioList, child) {
          Audio? audio = audioList.firstWhereOrNull((audio) => audio.documentId == midweekMeeting['MepsDocumentId']);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                  onTap: () => showDocumentView(context, midweekMeeting['MepsDocumentId'], midweekPub.mepsLanguage.id),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            margin: const EdgeInsetsDirectional.only(end: 10, start: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: Image.file(
                                File(imageFullPath),
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (frame == null) {
                                    return Container(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e));
                                  }
                                  return child;
                                },
                                fit: BoxFit.cover,
                                cacheWidth: 180,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(top: 4.0, end: 30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (midweekMeeting['Subtitle'] != null)
                                    Text(midweekMeeting['Subtitle'], style: contextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2.0),
                                  Text(midweekMeeting['Title'].trim(), style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      PositionedDirectional(
                        top: -15.0,
                        end:  -7,
                        child: PopupMenuButton(
                          // On utilise padding: EdgeInsets.zero pour annuler l'espace par défaut autour de l'icône
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
                          itemBuilder: (context) {
                            List<PopupMenuEntry> items = [
                              PopupMenuItem(child: Row(children: [
                                Icon(JwIcons.share, color: Theme
                                    .of(context)
                                    .brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black),
                                const SizedBox(width: 8.0),
                                Text(i18n().action_open_in_share,
                                    style: TextStyle(color: Theme
                                        .of(context)
                                        .brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black))
                              ]), onTap: () {
                                midweekPub.documentsManager?.getDocumentFromMepsDocumentId(midweekMeeting['MepsDocumentId']).share();
                              }),
                              PopupMenuItem(child: Row(children: [
                                Icon(JwIcons.qr_code, color: Theme
                                    .of(context)
                                    .brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black),
                                const SizedBox(width: 8.0),
                                Text(i18n().action_qr_code,
                                    style: TextStyle(color: Theme
                                        .of(context)
                                        .brightness == Brightness.dark ? Colors
                                        .white : Colors.black))
                              ]), onTap: () {
                                String? uri = midweekPub.documentsManager?.getDocumentFromMepsDocumentId(midweekMeeting['MepsDocumentId']).share(hide: true);
                                if(uri != null) {
                                  showQrCodeDialog(context, midweekMeeting['Title'], uri);
                                }
                              }),
                            ];
                            if (audio != null && audio.fileSize !=
                                null) { // Ajout de la vérification audio.fileSize != null
                              items.add(PopupMenuItem(child: Row(children: [
                                Icon(JwIcons.cloud_arrow_down, color: Theme
                                    .of(context)
                                    .brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black),
                                const SizedBox(width: 8.0),
                                ValueListenableBuilder<bool>(
                                    valueListenable: audio.isDownloadingNotifier,
                                    builder: (context, isDownloading, child) {
                                      return Text(isDownloading ? i18n()
                                          .message_download_in_progress : audio
                                          .isDownloadedNotifier.value
                                          ? i18n()
                                          .action_remove_audio_size(
                                          formatFileSize(audio.fileSize!))
                                          : i18n()
                                          .action_download_audio_size(
                                          formatFileSize(audio.fileSize!)),
                                          style: TextStyle(color: Theme
                                              .of(context)
                                              .brightness == Brightness.dark
                                              ? Colors
                                              .white
                                              : Colors.black));
                                    }),
                              ]), onTap: () {
                                if (audio.isDownloadedNotifier.value) {
                                  audio.remove(context);
                                } else {
                                  audio.download(context);
                                }
                              }),
                              );
                              items.add(PopupMenuItem(child: Row(children: [
                                Icon(
                                    JwIcons.headphones__simple, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                const SizedBox(width: 8.0),
                                Text(
                                    i18n().action_play_audio,
                                    style: TextStyle(color: Theme
                                        .of(context)
                                        .brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black))
                              ]), onTap: () {
                                int index = midweekPub.audiosNotifier.value.indexWhere((audio) =>
                                audio.documentId ==
                                    midweekMeeting['MepsDocumentId']);
                                if (index != -1) {
                                  showAudioPlayerPublicationLink(context, midweekPub, index);
                                }
                              }),
                              );
                            }
                            return items;
                          },
                        ),
                      ),
                      _buildDownloadIndicator(midweekPub, midweekMeeting['MepsDocumentId']),
                    ],
                  )
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildWeekendContent(BuildContext context, Publication weekendPub, Map<String, dynamic> weekendMeeting) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFF9fb9e3) : const Color(0xFF4a6da7);
    final Color subtitleColor = isDark ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final TextStyle titleStyle = TextStyle(fontSize: 15, color: titleColor, height: 1.1);
    final TextStyle contextStyle = TextStyle(fontSize: 13, color: subtitleColor);

    final String imageFullPath = '${weekendPub.path!}/${weekendMeeting['FilePath']}';
    final isRTL = weekendPub.mepsLanguage.isRtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: ValueListenableBuilder(
        valueListenable: weekendPub.audiosNotifier,
        builder: (context, audioList, child) {
          Audio? audio = audioList.firstWhereOrNull((audio) => audio.documentId == weekendMeeting['MepsDocumentId']);

          return Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: () => showDocumentView(context, weekendMeeting['MepsDocumentId'], weekendPub.mepsLanguage.id),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              margin: EdgeInsetsDirectional.only(end: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4.0),
                                child: Image.file(
                                  File(imageFullPath),
                                  frameBuilder: (context, child, frame,
                                      wasSynchronouslyLoaded) {
                                    if (frame == null && wasSynchronouslyLoaded) {
                                      return Container(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e));
                                    }
                                    return child;
                                  },
                                  fit: BoxFit.cover,
                                  cacheWidth: 180,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(top: 4.0, end: 30),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (weekendMeeting['ContextTitle'] != null)
                                      Text(weekendMeeting['ContextTitle'], style: contextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2.0),
                                    Text(weekendMeeting['Title'].trim(), style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        PositionedDirectional(
                          top: -15.0,
                          end: -7,
                          child: PopupMenuButton(
                            // On utilise padding: EdgeInsets.zero pour annuler l'espace par défaut autour de l'icône
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
                            itemBuilder: (context) {
                              List<PopupMenuEntry> items = [
                                PopupMenuItem(child: Row(children: [
                                  Icon(JwIcons.share, color: Theme
                                      .of(context)
                                      .brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(i18n().action_open_in_share,
                                      style: TextStyle(color: Theme
                                          .of(context)
                                          .brightness == Brightness.dark ? Colors
                                          .white : Colors.black))
                                ]), onTap: () {
                                  weekendPub.documentsManager?.getDocumentFromMepsDocumentId(weekendMeeting['MepsDocumentId']).share();
                                }),
                                PopupMenuItem(child: Row(children: [
                                  Icon(JwIcons.qr_code, color: Theme
                                      .of(context)
                                      .brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(i18n().action_qr_code,
                                      style: TextStyle(color: Theme
                                          .of(context)
                                          .brightness == Brightness.dark ? Colors
                                          .white : Colors.black))
                                ]), onTap: () {
                                  String? uri = weekendPub.documentsManager?.getDocumentFromMepsDocumentId(weekendMeeting['MepsDocumentId']).share(hide: true);
                                  if(uri != null) {
                                    showQrCodeDialog(context, weekendMeeting['Title'], uri);
                                  }
                                }),
                              ];
                              if (audio != null && audio.fileSize !=
                                  null) { // Ajout de la vérification audio.fileSize != null
                                items.add(PopupMenuItem(child: Row(children: [
                                  Icon(JwIcons.cloud_arrow_down, color: Theme
                                      .of(context)
                                      .brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black),
                                  const SizedBox(width: 8.0),
                                  ValueListenableBuilder<bool>(
                                      valueListenable: audio.isDownloadingNotifier,
                                      builder: (context, isDownloading, child) {
                                        return Text(isDownloading ? i18n()
                                            .message_download_in_progress : audio
                                            .isDownloadedNotifier.value
                                            ? i18n().action_remove_audio_size(
                                            formatFileSize(audio.fileSize!))
                                            : i18n().action_download_audio_size(
                                            formatFileSize(audio.fileSize!)),
                                            style: TextStyle(color: Theme
                                                .of(context)
                                                .brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.black));
                                      }),
                                ]), onTap: () {
                                  if (audio.isDownloadedNotifier.value) {
                                    audio.remove(context);
                                  } else {
                                    audio.download(context);
                                  }
                                }),
                                );
                                items.add(PopupMenuItem(child: Row(children: [
                                  Icon(JwIcons.headphones__simple, color: Theme
                                      .of(context)
                                      .brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(i18n().action_play_audio,
                                      style: TextStyle(color: Theme
                                          .of(context)
                                          .brightness == Brightness.dark ? Colors
                                          .white : Colors.black))
                                ]), onTap: () {
                                  int index = weekendPub.audiosNotifier.value.indexWhere((audio) =>
                                  audio.documentId == weekendMeeting['MepsDocumentId']);
                                  if (index != -1) {
                                    showAudioPlayerPublicationLink(context, weekendPub, index);
                                  }
                                }),
                                );
                              }
                              return items;
                            },
                          ),
                        ),
                        _buildDownloadIndicator(weekendPub, weekendMeeting['MepsDocumentId']),
                      ],
                    )
                )),
          );
        }
      ),
    );
  }

   Widget _buildDownloadIndicator(Publication publication, int mepsDocumentId) {
    return ValueListenableBuilder<List<Audio>>(
      valueListenable: publication.audiosNotifier,
      builder: (context, audios, _) {
        final audio = audios.firstWhereOrNull((a) => a.documentId == mepsDocumentId);
        if (audio == null) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: audio.isDownloadingNotifier,
          builder: (context, isDownloading, _) {
            if (!isDownloading) return const SizedBox.shrink();
            return PositionedDirectional(
              bottom: 5,
              start: 70,
              end: 40,
              child: ValueListenableBuilder<double>(
                valueListenable: audio.progressNotifier,
                builder: (context, progress, _) => LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _isConventionContentIsDownload(BuildContext context) {
    return ValueListenableBuilder<Publication?>(
      valueListenable: AppDataService.instance.conventionPub,
      builder: (context, conventionPub, _) {
        if (conventionPub == null) {
          return _buildEmptyState(
            context,
            "Pas de programme pour l'Assemblée Régionale",
            JwIcons.watchtower,
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: conventionPub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            // La clé combine l'ID et l'état de téléchargement pour forcer le refresh
            return KeyedSubtree(
              key: ValueKey('conv_${conventionPub.id}_$isDownloaded'),
              child: !isDownloaded
                  ? _buildDownloadState(context, conventionPub)
                  : PublicationMenuPage(
                      publication: conventionPub,
                      showAppBar: false,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _isCircuitBrContentIsDownload(BuildContext context) {
    return ValueListenableBuilder<Publication?>(
      valueListenable: AppDataService.instance.circuitBrPub,
      builder: (context, circuitBrPub, _) {
        if (circuitBrPub == null) {
          return _buildEmptyState(
            context,
            "Pas de programme pour l'Assemblée de circonscription avec un représentant de la filiale",
            JwIcons.watchtower,
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: circuitBrPub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            return KeyedSubtree(
              key: ValueKey('br_${circuitBrPub.id}_$isDownloaded'),
              child: !isDownloaded
                  ? _buildDownloadState(context, circuitBrPub)
                  : PublicationMenuPage(
                      publication: circuitBrPub,
                      showAppBar: false,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _isCircuitCoContentIsDownload(BuildContext context) {
    return ValueListenableBuilder<Publication?>(
      valueListenable: AppDataService.instance.circuitCoPub,
      builder: (context, circuitCoPub, _) {
        if (circuitCoPub == null) {
          return _buildEmptyState(
            context,
            "Pas de programme pour l'Assemblée de circonscription avec le responsable de circonscription",
            JwIcons.watchtower,
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: circuitCoPub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            return KeyedSubtree(
              key: ValueKey('co_${circuitCoPub.id}_$isDownloaded'),
              child: !isDownloaded
                  ? _buildDownloadState(context, circuitCoPub)
                  : PublicationMenuPage(
                      publication: circuitCoPub,
                      showAppBar: false,
                    ),
            );
          },
        );
      },
    );
  }
}
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/uri/jworg_uri.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/congregation/pages/brothers_and_sisters_page.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_page.dart';
import '../../../app/jwlife_app.dart';
import '../../../app/jwlife_app_bar.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/app_data/meetings_pubs_service.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/ui/text_styles.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_audio.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../../data/databases/history.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/userdata/congregation.dart';
import '../../../widgets/responsive_appbar_actions.dart';
import '../../congregation/pages/congregations_page.dart';
import '../../publication/pages/document/data/models/document.dart';
import '../../publication/pages/document/local/documents_manager.dart';
import '../../publication/pages/menu/local/publication_menu_view.dart';

class WorkShipPage extends StatefulWidget {
  const WorkShipPage({super.key});

  @override
  WorkShipPageState createState() => WorkShipPageState();
}

class WorkShipPageState extends State<WorkShipPage> with TickerProviderStateMixin {
  Congregation? _congregation;
  final _dateOfMeetingValue = ValueNotifier(DateTime.now());

  bool _isOtherPublicationsToggle = true;

  bool _isCircuitCoToggle = true;
  bool _isCircuitBrToggle = true;
  bool _isConventionToggle = true;

  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

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
    List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(date: _dateOfMeetingValue.value);

    refreshMeetingsPubs(pubs: dayPubs);
  }

  Future<void> fetchFirstCongregation() async {
    final congregation = await JwLifeApp.userdata.getCongregations();
    if (congregation.isEmpty) {
      return;
    }
    setState(() {
      _congregation = congregation.firstOrNull;
    });
  }

  void refreshSelectedDay(DateTime selectedDay) {
    _dateOfMeetingValue.value = selectedDay;
  }

  int getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysPassed = date
        .difference(firstDayOfYear)
        .inDays;
    return (daysPassed / 7).ceil();
  }

  String formatWeekRange(DateTime date) {
    DateTime firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    DateTime lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    String day1 = DateFormat('d', JwLifeSettings.instance.locale.languageCode).format(
        firstDayOfWeek);
    String day2 = DateFormat('d', JwLifeSettings.instance.locale.languageCode).format(
        lastDayOfWeek);
    String month1 = DateFormat('MMMM', JwLifeSettings.instance.locale.languageCode)
        .format(firstDayOfWeek);
    String month2 = DateFormat('MMMM', JwLifeSettings.instance.locale.languageCode)
        .format(lastDayOfWeek);

    return month1 == month2 ? i18n().label_date_range_one_month(
        day1, day2, month1) : i18n().label_date_range_two_months(
        day1, day2, month1, month2);
  }

  void _showPublicTalksDialog() async {
    DocumentsManager documentsManager;

    if (AppDataService.instance.publicTalkPub.value!.documentsManager != null) {
      documentsManager = AppDataService.instance.publicTalkPub.value!.documentsManager!;
    }
    else {
      documentsManager = DocumentsManager(publication: AppDataService.instance.publicTalkPub.value!, mepsDocumentId: -1);
      await documentsManager.initializeDatabaseAndData();
    }

    final result = await showDialog<Document>(
      context: context,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        List<Document> filteredDocuments = List.from(
            documentsManager.documents);

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
        subTitleWidget: ValueListenableBuilder(valueListenable: JwLifeSettings.instance.currentLanguage, builder: (context, value, child) {
          return Text(value.vernacular, style: Theme.of(context).extension<JwLifeThemeStyles>()!.appBarSubTitle);
        }),
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.language),
            text: i18n().label_languages_more,
            onPressed: (anchorContext) {
              showLanguageDialog(context).then((language) async {
                if (language != null) {
                  if (language['Symbol'] != JwLifeSettings.instance.currentLanguage.value.symbol) {
                    await AppSharedPreferences.instance.setLibraryLanguage(language);
                    AppDataService.instance.changeLanguageAndRefreshContent();
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
                List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(date: selectedDay);

                refreshSelectedDay(selectedDay);
                refreshMeetingsPubs(pubs: dayPubs, date: selectedDay);
              }
            },
          ),
          IconTextButton(
            text: i18n().action_history,
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: (anchorContext) {
              History.showHistoryDialog(context);
            },
          ),
          IconTextButton(
            text: i18n().action_open_in_share,
            icon: const Icon(JwIcons.share),
            onPressed: (anchorContext) {
              String uri = JwOrgUri.meetings(
                  wtlocale: JwLifeSettings.instance.currentLanguage.value.symbol,
                  date: convertDateTimeToIntDate(_dateOfMeetingValue.value).toString()
              ).toString();

              SharePlus.instance.share(
                  ShareParams(title: formatWeekRange(_dateOfMeetingValue.value),
                      uri: Uri.tryParse(uri))
              );
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _congregation == null || _congregation?.nextMeeting() == null
                      ? const SizedBox.shrink()
                      : Builder(
                    builder: (context) {
                      final meeting = _congregation!.nextMeeting();

                      if (meeting == null) return const SizedBox.shrink();

                      final date = meeting["date"] as DateTime;
                      final type = meeting["type"] as String;
                      final isMidweek = type == "midweek";

                      final icon = isMidweek ? JwIcons.sheep : JwIcons
                          .watchtower;

                      final dateStr = DateFormat("EEEE d MMMM", JwLifeSettings.instance.locale.languageCode).format(date);
                      final hourStr = DateFormat("HH", JwLifeSettings.instance.locale.languageCode).format(date);
                      final minuteStr = DateFormat("mm", JwLifeSettings.instance.locale.languageCode).format(date);

                      final formatData = i18n().label_date_next_meeting(dateStr, hourStr, minuteStr);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            showPage(CongregationsPage());
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Icon(
                                    icon,
                                    color: Theme
                                        .of(context)
                                        .brightness == Brightness.dark ? Colors
                                        .white70 : const Color(0xFF686868),
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _congregation!.name,
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
                                      const SizedBox(height: 4),
                                      Text(
                                        formatData,
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Theme
                                              .of(context)
                                              .brightness == Brightness.dark
                                              ? Colors.white70
                                              : const Color(0xFF686868),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          DateTime newDate = _dateOfMeetingValue.value.subtract(const Duration(days: 7));
                          List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(date: newDate);

                          refreshSelectedDay(newDate);
                          refreshMeetingsPubs(pubs: dayPubs, date: newDate);
                        },
                        icon: Icon(JwIcons.chevron_left),
                      ),
                      TextButton(
                        onPressed: () async {
                          DateTime? selectedDay = await showMonthCalendarDialog(context, _dateOfMeetingValue.value);
                          if (selectedDay != null) {
                            List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(date: selectedDay);

                            refreshSelectedDay(selectedDay);
                            refreshMeetingsPubs(pubs: dayPubs, date: selectedDay);
                          }
                        },
                        child: ValueListenableBuilder(
                          valueListenable: _dateOfMeetingValue,
                          builder: (context, value, _) {
                            return Text(formatWeekRange(value));
                          },
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          DateTime newDate = _dateOfMeetingValue.value.add(const Duration(days: 7));
                          List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(date: newDate);

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
                  _buildExpandableMeetingCard(
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
                  _buildExpandableMeetingCard(
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
                  _buildExpandableMeetingCard(
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
                  _buildExpandableMeetingCard(
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

        child
      ],
    );
  }

  Widget _buildExpandableMeetingCard({
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
          child: Row(
            children: [
              Expanded(
                child: Text(
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
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Icon(JwIcons.chevron_right,
                    color: Theme
                        .of(context)
                        .brightness == Brightness.dark ? Colors.white : Colors
                        .black, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? child : const SizedBox.shrink(),
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

  Widget _isWeekendMeetingContentIsDownload(
      BuildContext context, DateTime weekRange) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color subtitleColor =
    isDark ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final TextStyle titleStyle = TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black,
        height: 1.1);

    final TextStyle contextStyle =
    TextStyle(fontSize: 13, color: subtitleColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ----------------------------------------------------------
        // A) DISCOURS PUBLIC (bloc séparé totalement)
        // ----------------------------------------------------------
        ValueListenableBuilder<Publication?>(
          valueListenable: AppDataService.instance.publicTalkPub,
          builder: (context, publicTalkPub, _) {
            if (publicTalkPub == null) return const SizedBox.shrink();

            final isRTL = publicTalkPub.mepsLanguage.isRtl;

            return ValueListenableBuilder<Document?>(
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
                                SizedBox(
                                  width: 60,
                                  height: 60,
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(publicTalkPub
                                          .getTitle()
                                          .toUpperCase(), style: contextStyle),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedTalk?.title ??
                                            i18n().label_workship_public_talk_choosing,
                                        style: titleStyle,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                            ),

                            Positioned(
                              top: -15,
                              right: isRTL ? null : -7,
                              left: isRTL ? -7 : null,
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
                                          AppDataService.instance
                                              .selectedPublicTalk.value = null;
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

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
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
                            publication.cancelDownload(context);
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
    final Color subtitleColor = isDark ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final TextStyle titleStyle = TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black, height: 1.1);
    final TextStyle contextStyle = TextStyle(fontSize: 13, color: subtitleColor);

    final String imageFullPath = '${midweekPub.path!}/${midweekMeeting['FilePath']}';
    final isRTL = midweekPub.mepsLanguage.isRtl;
    Audio? audio = midweekPub.audios.firstWhereOrNull((audio) =>
    audio.documentId == midweekMeeting['MepsDocumentId']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: () {
            showDocumentView(context, midweekMeeting['MepsDocumentId'], JwLifeSettings.instance.currentLanguage.value.id);
          },
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60.0,
                        height: 60.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Image.file(
                            File(imageFullPath),
                            frameBuilder: (context, child, frame,
                                wasSynchronouslyLoaded) {
                              if (frame == null) {
                                return Container(color: Theme
                                    .of(context)
                                    .brightness == Brightness.dark
                                    ? const Color(
                                    0xFF4f4f4f)
                                    : const Color(0xFF8e8e8e));
                              }

                              return child;
                            },
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            midweekMeeting['Subtitle'],
                            style: contextStyle, // Style ajusté
                          ),
                          const SizedBox(height: 2),
                          Text(
                            midweekMeeting['Title'],
                            style: titleStyle,
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                  Positioned(
                    top: -15.0,
                    // Ajuste vers le haut pour compenser le Padding vertical de 4.0
                    // Positionnement absolu : Right pour LTR, Left pour RTL.
                    right: isRTL ? null : -7,
                    left: isRTL ? -7 : null,
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
                            midweekPub.documentsManager
                                ?.getDocumentFromMepsDocumentId(
                                midweekMeeting['MepsDocumentId']).share(
                                false);
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
                                JwIcons.headphones__simple, color: Theme
                                .of(context)
                                .brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black),
                            const SizedBox(width: 8.0),
                            Text(
                                i18n().action_play_audio,
                                style: TextStyle(color: Theme
                                    .of(context)
                                    .brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black))
                          ]), onTap: () {
                            int index = midweekPub.audios
                                .indexWhere((audio) =>
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
                ],
              )
          )),
    );
  }

  Widget _buildWeekendContent(BuildContext context, Publication weekendPub, Map<String, dynamic> weekendMeeting) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color subtitleColor = isDark ? const Color(0xFFc3c3c3) : const Color(0xFF626262);

    final TextStyle titleStyle = TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black, height: 1.1);
    final TextStyle contextStyle = TextStyle(fontSize: 13, color: subtitleColor);

    final String imageFullPath = '${weekendPub.path!}/${weekendMeeting['FilePath']}';
    final isRTL = weekendPub.mepsLanguage.isRtl;
    Audio? audio = weekendPub.audios.firstWhereOrNull((audio) =>
    audio.documentId == weekendMeeting['MepsDocumentId']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: () {
            showDocumentView(
              context,
              weekendMeeting['MepsDocumentId'],
              JwLifeSettings.instance.currentLanguage.value.id,
            );
          },
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60.0,
                        height: 60.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Image.file(
                            File(imageFullPath),
                            frameBuilder: (context, child, frame,
                                wasSynchronouslyLoaded) {
                              if (frame == null && wasSynchronouslyLoaded) {
                                return Container(color: Theme
                                    .of(context)
                                    .brightness == Brightness.dark
                                    ? const Color(0xFF4f4f4f)
                                    : const Color(0xFF8e8e8e));
                              }

                              return child;
                            },
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          // mainAxisSize.min est correct pour ne prendre que l'espace vertical nécessaire.
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              weekendMeeting['ContextTitle'],
                              style: contextStyle, // Assurez-vous que contextStyle est défini
                            ),
                            const SizedBox(height: 2),
                            Text(
                              weekendMeeting['Title'],
                              style: titleStyle,
                              // Assurez-vous que titleStyle est défini
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),

                  Positioned(
                    top: -15.0,
                    // Ajuste vers le haut pour compenser le Padding vertical de 4.0
                    // Positionnement absolu : Right pour LTR, Left pour RTL.
                    right: isRTL ? null : -7,
                    left: isRTL ? -7 : null,
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
                            weekendPub.documentsManager
                                ?.getDocumentFromMepsDocumentId(
                                weekendMeeting['MepsDocumentId']).share(
                                false);
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
                            int index = weekendPub.audios
                                .indexWhere((audio) =>
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
                ],
              )
          )),
    );
  }

  Widget _isConventionContentIsDownload(BuildContext context) {
    return ValueListenableBuilder<Publication?>(
      valueListenable: AppDataService.instance.conventionPub,
      builder: (context, conventionPub, _) {
        // ----------------------------------------------------------
        // 1) AUCUNE CONVENTION DISPONIBLE
        // ----------------------------------------------------------
        if (conventionPub == null) {
          return _buildEmptyState(
            context,
            "Pas de programme pour l'Assemblée Régionale",
            JwIcons.watchtower,
          );
        }

        // ----------------------------------------------------------
        // 2) PUBLICATION TROUVÉE
        // ----------------------------------------------------------
        return ValueListenableBuilder<bool>(
          valueListenable: conventionPub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            if (!isDownloaded) {
              return _buildDownloadState(context, conventionPub);
            }

            // ----------------------------------------------------------
            // 3) PUBLICATION TÉLÉCHARGÉE → AFFICHAGE CONTENU
            // ----------------------------------------------------------
            return PublicationMenuView(
              publication: conventionPub,
              showAppBar: false,
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
        // ----------------------------------------------------------
        // 1) PAS DE PROGRAMME DISPONIBLE
        // ----------------------------------------------------------
        if (circuitBrPub == null) {
          return _buildEmptyState(
            context,
            "Pas de programme pour l'Assemblée de circonscription avec un représentant de la filiale",
            JwIcons.watchtower,
          );
        }

        // ----------------------------------------------------------
        // 2) PUBLICATION : ÉTAT DE TÉLÉCHARGEMENT
        // ----------------------------------------------------------
        return ValueListenableBuilder<bool>(
          valueListenable: circuitBrPub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            if (!isDownloaded) {
              return _buildDownloadState(context, circuitBrPub);
            }

            // ----------------------------------------------------------
            // 3) PUBLICATION TÉLÉCHARGÉE → AFFICHAGE DU MENU
            // ----------------------------------------------------------
            return PublicationMenuView(
              publication: circuitBrPub,
              showAppBar: false,
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
        // ----------------------------------------------------------
        // 1) PAS DE PROGRAMME DISPONIBLE
        // ----------------------------------------------------------
        if (circuitCoPub == null) {
          return _buildEmptyState(
            context,
            "Pas de programme pour l'Assemblée de circonscription avec le responsable de circonscription",
            JwIcons.watchtower,
          );
        }

        // ----------------------------------------------------------
        // 2) PUBLICATION : ÉTAT DE TÉLÉCHARGEMENT
        // ----------------------------------------------------------
        return ValueListenableBuilder<bool>(
          valueListenable: circuitCoPub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            if (!isDownloaded) {
              return _buildDownloadState(context, circuitCoPub);
            }

            // ----------------------------------------------------------
            // 3) PUBLICATION TÉLÉCHARGÉE → AFFICHAGE DU MENU
            // ----------------------------------------------------------
            return PublicationMenuView(
              publication: circuitCoPub,
              showAppBar: false,
            );
          },
        );
      },
    );
  }
}
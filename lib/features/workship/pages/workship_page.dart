import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/congregation/pages/brothers_and_sisters_page.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/i18n/i18n.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/jwlife_app.dart';
import '../../../app/services/global_key_service.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_audio.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../../data/databases/history.dart';
import '../../../data/models/audio.dart';
import '../../../data/models/userdata/congregation.dart';
import '../../../widgets/conditional_sized_widget.dart';
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
  DateTime _dateOfMeetingValue = DateTime.now();
  MepsLanguage mepsLanguage = JwLifeSettings().currentLanguage;
  bool isLoading = true;

  Publication? _midweekMeetingPub;
  Publication? _weekendMeetingPub;
  Map<String, dynamic>? _midweekMeeting;
  Map<String, dynamic>? _weekendMeeting;

  Publication? _publicTalkPub;
  Document? selectedPublicTalk;

  Publication? _conventionPub;
  Publication? _circuitCoPub;
  Publication? _circuitBrPub;

  bool _isOtherPublicationsToggle = true;

  bool _isCircuitCoToggle = true;
  bool _isCircuitBrToggle = true;
  bool _isConventionToggle = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    refreshMeetingsPubs();
    refreshConventionsPubs();

    fetchFirstCongregation();

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> goToTheMeetingsTab() async {
    _tabController.animateTo(0);
    _dateOfMeetingValue = DateTime.now();
    _isOtherPublicationsToggle = true;
    _isCircuitCoToggle = true;
    _isCircuitBrToggle = true;
    _isConventionToggle = true;

    fetchFirstCongregation();
    List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: _dateOfMeetingValue);

    refreshMeetingsPubs(publications: dayPubs);
  }

  Future<void> fetchFirstCongregation() async {
    final congregation = await JwLifeApp.userdata.getCongregations();
    if (congregation.isEmpty) {
      return;
    }
    setState(() {
      _congregation = congregation.first;
    });
  }

  Future<void> refreshMeetingsPubs({List<Publication>? publications}) async {
    final pubs = publications ?? PubCatalog.datedPublications;

    _midweekMeetingPub = pubs.firstWhereOrNull((pub) => pub.keySymbol.contains('mwb'));
    _weekendMeetingPub = pubs.firstWhereOrNull((pub) => pub.keySymbol.contains(RegExp(r'(?<!m)w')));
    _publicTalkPub = PublicationRepository().getAllDownloadedPublications().firstWhereOrNull((pub) => pub.keySymbol.contains('S-34'));

    // Suppression et ajout des listeners comme vu plus haut
    _midweekMeetingPub?.isDownloadedNotifier.removeListener(_onMidweekDownloaded);
    _weekendMeetingPub?.isDownloadedNotifier.removeListener(_onWeekendDownloaded);

    if (_midweekMeetingPub != null) {
      _midweekMeetingPub!.isDownloadedNotifier.addListener(_onMidweekDownloaded);
      if (_midweekMeetingPub!.isDownloadedNotifier.value) {
        _midweekMeeting = await fetchMidWeekMeeting(_midweekMeetingPub);
      } else {
        _midweekMeeting = null;
      }
    }

    if (_weekendMeetingPub != null) {
      _weekendMeetingPub!.isDownloadedNotifier.addListener(_onWeekendDownloaded);
      if (_weekendMeetingPub!.isDownloadedNotifier.value) {
        _weekendMeeting = await fetchWeekendMeeting(_weekendMeetingPub);
      } else {
        _weekendMeeting = null;
      }
    }

    setState(() {});
  }

  void _onMidweekDownloaded() async {
    if (_midweekMeetingPub!.isDownloadedNotifier.value) {
      _midweekMeeting = await fetchMidWeekMeeting(_midweekMeetingPub);
    } else {
      _midweekMeeting = null;
    }
    setState(() {});
  }

  void _onWeekendDownloaded() async {
    if (_weekendMeetingPub!.isDownloadedNotifier.value) {
      _weekendMeeting = await fetchWeekendMeeting(_weekendMeetingPub);
    } else {
      _weekendMeeting = null;
    }
    setState(() {});
  }

  void refreshConventionsPubs() {
    setState(() {
      _conventionPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CO-pgm'));
      _circuitCoPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-copgm'));
      _circuitBrPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-brpgm'));
    });
  }

  void refreshSelectedDay(DateTime selectedDay) {
    setState(() {
      _dateOfMeetingValue = selectedDay;
    });
  }

  Future<Map<String, dynamic>?> fetchMidWeekMeeting(Publication? publication) async {
    if (publication != null && publication.isDownloadedNotifier.value) {
      Database db = await openReadOnlyDatabase(publication.databasePath!);

      String weekRange = DateFormat('yyyyMMdd').format(_dateOfMeetingValue);

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT Document.MepsDocumentId, Document.Title, Document.Subtitle, Multimedia.FilePath
        FROM Document
        LEFT JOIN DatedText ON DatedText.DocumentId = Document.DocumentId
        LEFT JOIN DocumentMultimedia ON DocumentMultimedia.DocumentId = Document.DocumentId
        LEFT JOIN Multimedia ON Multimedia.MultimediaId = DocumentMultimedia.MultimediaId
        WHERE Multimedia.CategoryType = ? AND DatedText.FirstDateOffset <= ? AND DatedText.LastDateOffset >= ?
        ORDER BY Multimedia.MultimediaId
        LIMIT 1
      ''', [9, weekRange, weekRange]);

      if (result.isNotEmpty) {
        return result.first;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchWeekendMeeting(Publication? publication) async {
    if (publication != null) {
      Database db = await openDatabase(publication.databasePath!);

      String weekRange = DateFormat('yyyyMMdd').format(this._dateOfMeetingValue);

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT doc.MepsDocumentId, doc.Title, doc.ContextTitle, m.FilePath
        FROM DatedText d
        JOIN DocumentInternalLink dil
            ON d.DocumentId = dil.DocumentId
           AND (
                d.BeginParagraphOrdinal = dil.BeginParagraphOrdinal
                OR d.BeginParagraphOrdinal = dil.EndParagraphOrdinal
                OR d.EndParagraphOrdinal = dil.BeginParagraphOrdinal
                OR d.EndParagraphOrdinal = dil.EndParagraphOrdinal
           )
        JOIN InternalLink il ON dil.InternalLinkId = il.InternalLinkId
        JOIN Document doc ON il.MepsDocumentId = doc.MepsDocumentId
        LEFT JOIN DocumentMultimedia dm ON dm.DocumentId = doc.DocumentId
        LEFT JOIN Multimedia m ON m.MultimediaId = dm.MultimediaId
        WHERE m.CategoryType = ? AND d.FirstDateOffset <= ? AND d.LastDateOffset >= ?
        LIMIT 1
      ''', [9, weekRange, weekRange]);

      if (result.isNotEmpty) {
        return result.first;
      }
    }
    return null;
  }

  int getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysPassed = date.difference(firstDayOfYear).inDays;
    return (daysPassed / 7).ceil();
  }

  String formatWeekRange(DateTime date) {
    DateTime firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    DateTime lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    String day1 = DateFormat('d', JwLifeSettings().locale.languageCode).format(firstDayOfWeek);
    String day2 = DateFormat('d', JwLifeSettings().locale.languageCode).format(lastDayOfWeek);
    String month1 = DateFormat('MMMM', JwLifeSettings().locale.languageCode).format(firstDayOfWeek);
    String month2 = DateFormat('MMMM', JwLifeSettings().locale.languageCode).format(lastDayOfWeek);

    return month1 == month2 ? i18n().label_date_range_one_month(day1, day2, month1) : i18n().label_date_range_two_months(day1, day2, month1, month2);
  }

  void _showPublicTalksDialog() async {
    DocumentsManager documentsManager;

    if (_publicTalkPub!.documentsManager != null) {
      documentsManager = _publicTalkPub!.documentsManager!;
    } else {
      documentsManager = DocumentsManager(publication: _publicTalkPub!, mepsDocumentId: -1);
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
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      child: Text(
                        i18n().action_public_talk_choose,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                                  filteredDocuments = documentsManager.documents.where((document) {
                                    return document.title.toLowerCase().contains(value.toLowerCase());
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
                                color: Theme.of(context).brightness == Brightness.dark
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
                            color: Theme.of(context).primaryColor,
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
      setState(() {
        selectedPublicTalk = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    const Color _midweekColor = Color(0xFF2C3E50);
    const Color _watchtowerColor = Color(0xFF2C3E50);
    const Color _publicationsColor = Color(0xFF2C3E50);

    const Color _assemblyBrColor = Color(0xFF2C3E50);
    const Color _assemblyCoColor = Color(0xFF2C3E50);
    const Color _conventionColor = Color(0xFF2C3E50);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i18n().navigation_workship, style: textStyleTitle),
            Text(JwLifeSettings().currentLanguage.vernacular, style: textStyleSubtitle),
          ],
        ),
        actions: [
          ResponsiveAppBarActions(
            allActions: [
              IconTextButton(
                icon: const Icon(JwIcons.language),
                text: i18n().label_languages_more,
                onPressed: (anchorContext) {
                  showLanguageDialog(context).then((language) async {
                    if (language != null) {
                      if (language['Symbol'] != JwLifeSettings().currentLanguage.symbol) {
                        await setLibraryLanguage(language);
                        GlobalKeyService.homeKey.currentState?.changeLanguageAndRefresh();
                      }
                    }
                  });
                },
              ),
              IconTextButton(
                icon: const Icon(JwIcons.calendar),
                text: i18n().label_select_a_week,
                onPressed: (anchorContext) async {
                  DateTime? selectedDay = await showMonthCalendarDialog(context, _dateOfMeetingValue);
                  if (selectedDay != null) {
                    List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: selectedDay);

                    refreshSelectedDay(selectedDay);
                    refreshMeetingsPubs(publications: dayPubs);
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
                      wtlocale: mepsLanguage.symbol,
                      date: convertDateTimeToIntDate(_dateOfMeetingValue).toString()
                  ).toString();

                  SharePlus.instance.share(
                      ShareParams(title: formatWeekRange(_dateOfMeetingValue), uri: Uri.tryParse(uri))
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
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
            child: TabBar(
              controller: _tabController,
              tabAlignment: TabAlignment.fill,
              tabs: [
                Tab(text: i18n().navigation_workship_meetings),
                Tab(text: i18n().navigation_workship_conventions),
              ],
              dividerHeight: 1,
              dividerColor: const Color(0xFF686868),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: RÉUNIONS
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _congregation?.nextMeeting() == null
                    ? const SizedBox.shrink()
                    : Builder(
                  builder: (context) {
                    final meeting = _congregation!.nextMeeting();

                    if (meeting == null) return const SizedBox.shrink();

                    final date = meeting["date"] as DateTime;
                    final type = meeting["type"] as String;
                    final isMidweek = type == "midweek";

                    final icon = isMidweek ? JwIcons.sheep : JwIcons.watchtower;

                    final dateStr = DateFormat("EEEE d MMMM", JwLifeSettings().locale.languageCode).format(date);
                    final hourStr = DateFormat("HH", JwLifeSettings().locale.languageCode).format(date);
                    final minuteStr = DateFormat("mm", JwLifeSettings().locale.languageCode).format(date);

                    final formatData = i18n().label_date_next_meeting(dateStr, hourStr, minuteStr);

                    return InkWell(
                      onTap: () {
                        showPage(CongregationsPage());
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                icon,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF686868),
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
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF686868),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatData,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF686868),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                        DateTime newDate = _dateOfMeetingValue.subtract(Duration(days: 7));
                        List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: newDate);

                        setState(() {
                          refreshSelectedDay(newDate);
                          refreshMeetingsPubs(publications: dayPubs);
                        });
                      },
                      icon: Icon(Directionality.of(context) == TextDirection.rtl ? JwIcons.chevron_right : JwIcons.chevron_left),
                    ),
                    TextButton(
                      onPressed: () async {
                        DateTime? selectedDay = await showMonthCalendarDialog(context, _dateOfMeetingValue);
                        if (selectedDay != null) {
                          List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: selectedDay);

                          setState(() {
                            refreshSelectedDay(selectedDay);
                            refreshMeetingsPubs(publications: dayPubs);
                          });
                        }
                      },
                      child: Text(formatWeekRange(_dateOfMeetingValue)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        DateTime newDate = _dateOfMeetingValue.add(Duration(days: 7));
                        List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: newDate);

                        setState(() {
                          refreshSelectedDay(newDate);
                          refreshMeetingsPubs(publications: dayPubs);
                        });
                      },
                      icon: Icon(Directionality.of(context) == TextDirection.rtl ? JwIcons.chevron_left : JwIcons.chevron_right),
                    ),
                  ],
                ),

                // Carte Réunion Vie et Ministère
                _buildMeetingCard(
                  context: context,
                  title: i18n().navigation_workship_life_and_ministry,
                  icon: JwIcons.sheep,
                  child: _isMidweekMeetingContentIsDownload(context, _dateOfMeetingValue),
                ),

                const SizedBox(height: 25),

                // Carte Étude de la Tour de Garde
                _buildMeetingCard(
                  context: context,
                  title: i18n().navigation_workship_watchtower_study,
                  icon: JwIcons.watchtower,
                  child: _isWeekendMeetingContentIsDownload(context, _dateOfMeetingValue),
                ),

                const SizedBox(height: 25),

                // Carte Autres Publications
                _buildExpandableMeetingCard(
                  context: context,
                  title: i18n().label_other_meeting_publications,
                  icon: JwIcons.book_stack,
                  color: _publicationsColor,
                  child: _meetingsPublications(context),
                  isExpanded: _isOtherPublicationsToggle,
                  onToggle: () {
                    setState(() => _isOtherPublicationsToggle = !_isOtherPublicationsToggle);
                  },
                ),
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
                  color: _assemblyBrColor,
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
                  color: _assemblyCoColor,
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
                  color: _conventionColor,
                  child: _isConventionContentIsDownload(context),
                  isExpanded: _isConventionToggle,
                  onToggle: () {
                    setState(() => _isConventionToggle = !_isConventionToggle);
                  },
                ),
              ],
            ),
          ),
        ],
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
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),

        // Separator
        const SizedBox(height: 8),

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
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Icon(JwIcons.chevron_right,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
    if (_midweekMeetingPub == null) {
      return _buildEmptyState(
        context,
        i18n().message_no_midweek_meeting_content,
        JwIcons.sheep,
      );
    }

    if (!_midweekMeetingPub!.isDownloadedNotifier.value) {
      return _buildDownloadState(context, _midweekMeetingPub!);
    }
    else {
      if (_midweekMeeting != null && _midweekMeetingPub != null) {
        return _buildMidweekContentState(context);
      }
      return const SizedBox.shrink();
    }
  }

  Widget _isWeekendMeetingContentIsDownload(BuildContext context, DateTime weekRange) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRTL = _publicTalkPub!.mepsLanguage.isRtl;

    // Crée une liste de widgets pour le contenu de la colonne
    List<Widget> children = [];

    // 1. Contenu de la Public Talk (si _publicTalkPub est disponible)
    if(_publicTalkPub != null) {
      children.add(
          InkWell(
              onLongPress: () {
                _showPublicTalksDialog();
              },
              onTap: () async {
                if(selectedPublicTalk != null) {
                  showPageDocument(_publicTalkPub!, selectedPublicTalk!.mepsDocumentId);
                }
                else {
                  _showPublicTalksDialog();
                }
              },
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
                              child: Stack(
                                children: [
                                  Container(
                                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e),
                                  ),
                                  Center(
                                    child: Icon(
                                      JwIcons.document_speaker,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  )
                                ],
                              )
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded( // Use Expanded to ensure the container takes available space
                          child: selectedPublicTalk != null ? Text(selectedPublicTalk!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)) : Text(
                            i18n().label_workship_public_talk_choosing,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ]
                  ),

                  Positioned(
                    top: -10.0, // Ajuste vers le haut pour compenser le Padding vertical de 4.0
                    // Positionnement absolu : Right pour LTR, Left pour RTL.
                    right: isRTL ? null : -8,
                    left: isRTL ? -8 : null,
                    child: PopupMenuButton(
                      // On utilise padding: EdgeInsets.zero pour annuler l'espace par défaut autour de l'icône
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
                      itemBuilder: (context) {
                        List<PopupMenuEntry> items = [
                          PopupMenuItem(child: Row(children: [Icon(JwIcons.document_speaker, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text(selectedPublicTalk != null ? i18n().action_public_talk_replace : i18n().action_public_talk_choose)]), onTap: () => { _showPublicTalksDialog() }),
                          if(selectedPublicTalk != null)
                            PopupMenuItem(child: Row(children: [Icon(JwIcons.trash, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text(i18n().action_public_talk_remove)]), onTap: () => { removePublicTalk()}),
                        ];
                        return items;
                      },
                    ),
                  ),
                ],
              )
          )
      );
      // Ajoutez un SizedBox ou un Padding ici si vous voulez un espacement entre les deux parties
      children.add(const SizedBox(height: 10));
    }


    // 2. Logique du contenu de la réunion de fin de semaine
    if (_weekendMeetingPub == null) {
      children.add(
          _buildEmptyState(
            context,
            i18n().message_no_weekend_meeting_content,
            JwIcons.watchtower,
          )
      );
    } else if (!_weekendMeetingPub!.isDownloadedNotifier.value) {
      children.add(
          _buildDownloadState(context, _weekendMeetingPub!)
      );
    } else {
      if (_weekendMeeting != null && _weekendMeetingPub != null) {
        children.add(
            _buildWeekendContent(context)
        );
      }
    }

    // 3. Retourne la colonne avec tous les éléments
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Alignez le contenu à gauche
      children: children,
    );
  }

  Widget _meetingsPublications(BuildContext context) {
    List<Publication> publications = [
      if (_midweekMeetingPub != null) _midweekMeetingPub!,
      if (_weekendMeetingPub != null) _weekendMeetingPub!,
      ...PubCatalog.otherMeetingsPublications
    ];

    List<Widget> children = [];

    for (int i = 0; i < publications.length; i++) {
      children.add(RectanglePublicationItem(publication: publications[i], backgroundColor: Colors.transparent, height: 70));

      if (i < publications.length - 1) {
        children.add(const SizedBox(height: 8));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300],
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

  Widget _buildMidweekContentState(BuildContext context) {
    final String imageFullPath = '${_midweekMeetingPub!.path!}/${_midweekMeeting!['FilePath']}';
    final isRTL = _midweekMeetingPub!.mepsLanguage.isRtl;
    Audio? audio = _midweekMeetingPub!.audios.firstWhereOrNull((audio) => audio.documentId == _midweekMeeting!['MepsDocumentId']);

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: InkWell(
        onTap: () {
          showDocumentView(context, _midweekMeeting!['MepsDocumentId'], JwLifeSettings().currentLanguage.id);
        },
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
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame == null) {
                          return Container(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e));
                        }

                        return child;
                      },
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConditionalSizedWidget(
                  title: _midweekMeeting!['Title'],
                  subtitle: _midweekMeeting!['Subtitle'],
                ),
              ],
            ),
            Positioned(
              top: -10.0, // Ajuste vers le haut pour compenser le Padding vertical de 4.0
              // Positionnement absolu : Right pour LTR, Left pour RTL.
              right: isRTL ? null : -8,
              left: isRTL ? -8 : null,
              child: PopupMenuButton(
                // On utilise padding: EdgeInsets.zero pour annuler l'espace par défaut autour de l'icône
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
                itemBuilder: (context) {
                  List<PopupMenuEntry> items = [
                    PopupMenuItem(child: Row(children: [Icon(JwIcons.share, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text(i18n().action_open_in_share, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))]), onTap: () { _midweekMeetingPub!.documentsManager?.getDocumentFromMepsDocumentId(_midweekMeeting!['MepsDocumentId']).share(false); }),
                  ];
                  if (audio != null && audio.fileSize != null) { // Ajout de la vérification audio.fileSize != null
                    items.add(PopupMenuItem(child: Row(children: [Icon(JwIcons.cloud_arrow_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), ValueListenableBuilder<bool>(valueListenable: audio.isDownloadingNotifier, builder: (context, isDownloading, child) { return Text(isDownloading ? i18n().message_download_in_progress : audio.isDownloadedNotifier.value ? i18n().action_remove_audio_size(formatFileSize(audio.fileSize!)) : i18n().action_download_audio_size(formatFileSize(audio.fileSize!)), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)); }),]), onTap: () { if (audio.isDownloadedNotifier.value) { audio.remove(context); } else { audio.download(context); } }),
                    );
                    items.add(PopupMenuItem(child: Row(children: [Icon(JwIcons.headphones__simple, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text(i18n().action_play_audio, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))]), onTap: () { int index = _midweekMeetingPub!.audios.indexWhere((audio) => audio.documentId == _midweekMeeting!['MepsDocumentId']); if (index != -1) { showAudioPlayerPublicationLink(context, _midweekMeetingPub!, index); } }),
                    );
                  }
                  return items;
                },
              ),
            ),
          ],
        )
      )
    );
  }

  Widget _buildWeekendContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String imageFullPath = '${_weekendMeetingPub!.path!}/${_weekendMeeting!['FilePath']}';
    final isRTL = _weekendMeetingPub!.mepsLanguage.isRtl;
    Audio? audio = _weekendMeetingPub!.audios.firstWhereOrNull((audio) => audio.documentId == _weekendMeeting!['MepsDocumentId']);

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: InkWell(
            onTap: () {
              showDocumentView(
                context,
                _weekendMeeting!['MepsDocumentId'],
                JwLifeSettings().currentLanguage.id,
              );
            },
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
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (frame == null && wasSynchronouslyLoaded) {
                              return Container(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4f4f4f) : const Color(0xFF8e8e8e));
                            }

                            return child;
                          },
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded( // Added Expanded here to resolve potential width issues
                      child: ConditionalSizedWidget(
                        title: _weekendMeeting!['Title'], // Prend 1 ligne
                        subtitle: _weekendMeeting!['ContextTitle'],
                      ),
                    ),
                  ],
                ),

                Positioned(
                  top: -10.0, // Ajuste vers le haut pour compenser le Padding vertical de 4.0
                  // Positionnement absolu : Right pour LTR, Left pour RTL.
                  right: isRTL ? null : -8,
                  left: isRTL ? -8 : null,
                  child: PopupMenuButton(
                    // On utilise padding: EdgeInsets.zero pour annuler l'espace par défaut autour de l'icône
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz, color: Color(0xFF9d9d9d)),
                    itemBuilder: (context) {
                      List<PopupMenuEntry> items = [
                        PopupMenuItem(child: Row(children: [Icon(JwIcons.share, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text(i18n().action_open_in_share, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))]), onTap: () { _weekendMeetingPub!.documentsManager?.getDocumentFromMepsDocumentId(_midweekMeeting!['MepsDocumentId']).share(false); }),
                      ];
                      if (audio != null && audio.fileSize != null) { // Ajout de la vérification audio.fileSize != null
                        items.add(PopupMenuItem(child: Row(children: [Icon(JwIcons.cloud_arrow_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), ValueListenableBuilder<bool>(valueListenable: audio.isDownloadingNotifier, builder: (context, isDownloading, child) { return Text(isDownloading ? i18n().message_download_in_progress : audio.isDownloadedNotifier.value ? i18n().action_remove_audio_size(formatFileSize(audio.fileSize!)) : i18n().action_download_audio_size(formatFileSize(audio.fileSize!)), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)); }),]), onTap: () { if (audio.isDownloadedNotifier.value) { audio.remove(context); } else { audio.download(context); } }),
                        );
                        items.add(PopupMenuItem(child: Row(children: [Icon(JwIcons.headphones__simple, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), const SizedBox(width: 8.0), Text(i18n().action_play_audio, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))]), onTap: () { int index = _weekendMeetingPub!.audios.indexWhere((audio) => audio.documentId == _midweekMeeting!['MepsDocumentId']); if (index != -1) { showAudioPlayerPublicationLink(context, _weekendMeetingPub!, index); } }),
                        );
                      }
                      return items;
                    },
                  ),
                ),
              ],
            )
        )
    );
  }

  Widget _isConventionContentIsDownload(BuildContext context) {
    if (_conventionPub == null) {
      return const Center(child: Text("Pas de programme pour l'Assemblée Régionale"));
    }

    Publication? publication = PublicationRepository().getPublication(_conventionPub!);

    return ValueListenableBuilder<bool>(
      valueListenable: publication.isDownloadedNotifier,
      builder: (context, isDownloaded, _) {
        if (!isDownloaded) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                publication.title,
                style: const TextStyle(fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    publication.download(context);
                  },
                  child: Text(
                    i18n().action_download.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: publication.progressNotifier,
                builder: (context, value, _) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: value == -1 ? null : value,
                        minHeight: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[300],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        } else {
          return PublicationMenuView(publication: publication, showAppBar: false);
        }
      },
    );
  }

  Widget _isCircuitBrContentIsDownload(BuildContext context) {
    if (_circuitBrPub == null) {
      return const Center(
        child: Text("Pas de programme pour l'Assemblée de circonscription avec un représentant de la filiale", textAlign: TextAlign.center),
      );
    }

    final publicationBr = PublicationRepository().getPublication(_circuitBrPub!);

    Widget buildDownloadSection(Publication pub) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            pub.title,
            style: const TextStyle(fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                pub.download(context);
              },
              child: Text(
                i18n().action_download.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<double>(
            valueListenable: pub.progressNotifier,
            builder: (context, value, _) {
              if (value == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: value == -1 ? null : value,
                    minHeight: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[300],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: publicationBr.isDownloadedNotifier,
      builder: (context, isDownloadedBr, _) {
        if (!isDownloadedBr) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 170,
                child: Center(child: buildDownloadSection(publicationBr)),
              ),
            ],
          );
        }

        return PublicationMenuView(publication: publicationBr, showAppBar: false);
      },
    );
  }

  Widget _isCircuitCoContentIsDownload(BuildContext context) {
    if (_circuitCoPub == null) {
      return const Center(
        child: Text("Pas de programme pour l'Assemblée de circonscription avec le responsable de circonscription", textAlign: TextAlign.center),
      );
    }

    final publicationCo = PublicationRepository().getPublication(_circuitCoPub!);

    Widget buildDownloadSection(Publication pub) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            pub.title,
            style: const TextStyle(fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                pub.download(context);
              },
              child: Text(
                i18n().action_download.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<double>(
            valueListenable: pub.progressNotifier,
            builder: (context, value, _) {
              if (value == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: value == -1 ? null : value,
                    minHeight: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[300],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: publicationCo.isDownloadedNotifier,
      builder: (context, isDownloadedCo, _) {
        if (!isDownloadedCo) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 170,
                child: Center(child: buildDownloadSection(publicationCo)),
              ),
            ],
          );
        }

        return PublicationMenuView(publication: publicationCo, showAppBar: false);
      },
    );
  }

  void removePublicTalk() {
    setState(() {
      selectedPublicTalk = null;
    });
  }
}
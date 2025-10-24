import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/core/utils/utils_dialog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/jwlife_app.dart';
import '../../../app/services/global_key_service.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/utils_language_dialog.dart';
import '../../../data/databases/history.dart';
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

  bool _isCircuitCoToggle = false;
  bool _isCircuitBrToggle = false;
  bool _isConventionToggle = false;

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
    _isCircuitCoToggle = false;
    _isCircuitBrToggle = false;
    _isConventionToggle = false;

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

    String dayStart = DateFormat('d').format(firstDayOfWeek);
    String dayEnd = DateFormat('d').format(lastDayOfWeek);
    String month = DateFormat('MMMM', 'fr_FR').format(date);

    return '$dayStart-$dayEnd $month';
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      child: Text(
                        'Choisir un discours',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          'ANNULER',
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
            Text(localization(context).navigation_workship, style: textStyleTitle),
            Text(formatWeekRange(_dateOfMeetingValue), style: textStyleSubtitle),
          ],
        ),
        actions: [
          ResponsiveAppBarActions(
            allActions: [
              IconTextButton(
                icon: const Icon(JwIcons.language),
                text: 'Autres langues',
                onPressed: () {
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
                text: 'Sélectionner une semaine',
                onPressed: () async {
                  DateTime? selectedDay = await showMonthCalendarDialog(context, _dateOfMeetingValue);
                  if (selectedDay != null) {
                    List<Publication> dayPubs = await PubCatalog.getPublicationsForTheDay(date: selectedDay);

                    refreshMeetingsPubs(publications: dayPubs);
                    refreshSelectedDay(selectedDay);
                  }
                },
              ),
              IconTextButton(
                text: "Historique",
                icon: const Icon(JwIcons.arrow_circular_left_clock),
                onPressed: () {
                  History.showHistoryDialog(context);
                },
              ),
              IconTextButton(
                text: "Envoyer le lien",
                icon: const Icon(JwIcons.share),
                onPressed: () {
                  String uri = JwOrgUri.meetings(
                      wtlocale: mepsLanguage.symbol,
                      date: convertDateTimeToIntDate(_dateOfMeetingValue).toString()
                  ).toString();

                  SharePlus.instance.share(
                      ShareParams(title: formatWeekRange(_dateOfMeetingValue), uri: Uri.tryParse(uri))
                  );
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
              tabs: const [
                Tab(text: 'RÉUNIONS'),
                Tab(text: 'ASSEMBLÉES'),
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

                    final dateStr = DateFormat("EEEE d MMMM 'à' HH'h'mm", JwLifeSettings().currentLanguage.primaryIetfCode).format(date);

                    return GestureDetector(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(
                                  icon,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF686868),
                                  size: 50,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'PROCHAINE RÉUNION',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Color(0xFF686868),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      textAlign: TextAlign.right,
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
                      ),
                      onTap: () {
                        showPage(CongregationsPage());
                      }
                    );
                  },
                ),
                // Carte Réunion Vie et Ministère
                _buildMeetingCard(
                  context: context,
                  title: localization(context).navigation_workship_life_and_ministry,
                  icon: JwIcons.sheep,
                  color: _midweekColor,
                  child: _isMidweekMeetingContentIsDownload(context, _dateOfMeetingValue),
                ),
                const SizedBox(height: 12),

                // Carte Étude de la Tour de Garde
                _buildMeetingCard(
                  context: context,
                  title: localization(context).navigation_workship_watchtower_study,
                  icon: JwIcons.watchtower,
                  color: _watchtowerColor,
                  child: _isWeekendMeetingContentIsDownload(context, _dateOfMeetingValue),
                ),

                const SizedBox(height: 30),

                // Carte Autres Publications
                _buildExpandableMeetingCard(
                  context: context,
                  title: 'Autres publications',
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
                  title: localization(context).navigation_workship_assembly_br,
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
                  title: localization(context).navigation_workship_assembly_co,
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
                  title: localization(context).navigation_workship_convention,
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
    required Color color,
    required Widget child
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
              color: color
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 80),
                  width: double.infinity,
                  padding: const EdgeInsets.all(0),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: color),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: child,
              )
                  : const SizedBox.shrink(),
            )
          ],
        ),
      ),
    );
  }

  Widget _isMidweekMeetingContentIsDownload(BuildContext context, DateTime weekRange) {
    if (_midweekMeetingPub == null) {
      return _buildEmptyState(
        context,
        'Pas de contenu pour la réunion de la semaine',
        JwIcons.sheep,
      );
    }

    if (!_midweekMeetingPub!.isDownloadedNotifier.value) {
      return _buildDownloadState(
        context,
        _midweekMeetingPub!,
        localization(context).action_download,
      );
    }
    else {
      if (_midweekMeeting != null) {
        return _buildContentState(
          context,
          'Réunion du ${_midweekMeeting!['Title']}',
          _midweekMeeting!['Subtitle'],
          '${_midweekMeetingPub!.path!}/${_midweekMeeting!['FilePath']}',
              () => showDocumentView(context, _midweekMeeting!['MepsDocumentId'], JwLifeSettings().currentLanguage.id),
        );
      }
      return const SizedBox.shrink();
    }
  }

  Widget _isWeekendMeetingContentIsDownload(BuildContext context, DateTime weekRange) {
    if (_weekendMeetingPub == null) {
      return _buildEmptyState(
        context,
        'Pas de contenu pour la réunion du week-end',
        JwIcons.watchtower,
      );
    }

    if (!_weekendMeetingPub!.isDownloadedNotifier.value) {
      return _buildDownloadState(
        context,
        _weekendMeetingPub!,
        localization(context).action_download,
      );
    }
    else {
      return _buildWeekendContent(context);
    }
  }

  Widget _meetingsPublications(BuildContext context) {
    List<Publication> publications = [
      if (_midweekMeetingPub != null) _midweekMeetingPub!,
      if (_weekendMeetingPub != null) _weekendMeetingPub!,
      ...PubCatalog.otherMeetingsPublications
    ];

    List<Widget> children = [];

    for (int i = 0; i < publications.length; i++) {
      children.add(RectanglePublicationItem(publication: publications[i], backgroundColor: Theme.of(context).cardColor, height: 70));

      if (i < publications.length - 1) {
        children.add(const SizedBox(height: 8));
      }
    }

    return Padding(
        padding: EdgeInsetsGeometry.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        )
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

  Widget _buildDownloadState(BuildContext context, Publication publication, String buttonText) {
    return Padding(
        padding: const EdgeInsetsGeometry.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              publication.issueTitle,
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                ),
                onPressed: () {
                  publication.download(context);
                },
                child: Text(
                  buttonText.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
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
        )
    );
  }

  Widget _buildContentState(
      BuildContext context,
      String title,
      String subtitle,
      String imagePath,
      VoidCallback onTap,
      ) {
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: EdgeInsetsGeometry.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: ImageCachedWidget(imageUrl: imagePath),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
        )
    );
  }

  Widget _buildWeekendContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
        padding: EdgeInsetsGeometry.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if(_publicTalkPub != null)
              Row(
                children: [
                  Icon(JwIcons.document_speaker, color: Theme.of(context).primaryColor, size: 25),
                  const SizedBox(width: 8),
                  Text(
                    "DISCOURS PUBLIQUE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            if(_publicTalkPub != null)
              const SizedBox(height: 8),

            if(_publicTalkPub != null)
              GestureDetector(
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: selectedPublicTalk != null ? Text(selectedPublicTalk!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)) : Text(
                    "Choisir le numéro de discours ici...",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),

            if(_publicTalkPub != null)
              const SizedBox(height: 20),

            if(_publicTalkPub != null)
              Row(
                children: [
                  Icon(JwIcons.watchtower, color: Theme.of(context).primaryColor, size: 25),
                  const SizedBox(width: 8),
                  Text(
                    "ÉTUDE DE LA TOUR DE GARDE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),

            if(_publicTalkPub != null)
              const SizedBox(height: 8),

            if (_weekendMeeting != null)
              GestureDetector(
                onTap: () {
                  showDocumentView(
                    context,
                    _weekendMeeting!['MepsDocumentId'],
                    JwLifeSettings().currentLanguage.id,
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 65,
                        height: 65,
                        child: ImageCachedWidget(
                          imageUrl: '${_weekendMeetingPub!.path!}/${_weekendMeeting!['FilePath']}',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _weekendMeeting!['ContextTitle'],
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Text(
                            _weekendMeeting!['Title'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
                    localization(context).action_download.toUpperCase(),
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
          return Padding(padding: EdgeInsetsGeometry.all(15), child: PublicationMenuView(publication: publication, showAppBar: false));
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
                localization(context).action_download.toUpperCase(),
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

        return Padding(padding: EdgeInsetsGeometry.all(15), child: PublicationMenuView(publication: publicationBr, showAppBar: false));
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
                localization(context).action_download.toUpperCase(),
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

        return Padding(padding: EdgeInsetsGeometry.all(15), child: PublicationMenuView(publication: publicationCo, showAppBar: false));
      },
    );
  }
}
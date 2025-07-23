import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/features/home/views/home_page.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/jwlife_page.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/utils/common_ui.dart';
import '../../../data/databases/history.dart';
import '../../../widgets/responsive_appbar_actions.dart';
import '../../publication/pages/document/data/models/document.dart';
import '../../publication/pages/document/local/document_page.dart';
import '../../publication/pages/document/local/documents_manager.dart';
import '../../publication/pages/menu/local/publication_menu_view.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  MeetingsPageState createState() => MeetingsPageState();
}

class MeetingsPageState extends State<MeetingsPage> {
  int _initialIndex = 0;
  DateTime dateOfMeetingValue = DateTime.now();
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

  @override
  void initState() {
    super.initState();

    // Déterminer le jour de la semaine
    final now = DateTime.now();
    if (now.weekday >= DateTime.monday && now.weekday <= DateTime.friday) {
      _initialIndex = 0; // Du lundi au vendredi
    }
    else {
      _initialIndex = 1; // Samedi et dimanche
    }

    refreshMeetingsPubs();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> refreshMeetingsPubs({List<Publication>? publications}) async {
    final pubs = publications ?? PubCatalog.datedPublications;

    _midweekMeetingPub = pubs.firstWhereOrNull((pub) => pub.keySymbol.contains('mwb'));
    _weekendMeetingPub = pubs.firstWhereOrNull((pub) => pub.keySymbol.contains(RegExp(r'(?<!m)w')));
    _publicTalkPub = PublicationRepository()
        .getAllDownloadedPublications()
        .firstWhereOrNull((pub) => pub.keySymbol.contains('S-34'));

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

// Méthodes de callback à déclarer dans ta classe pour éviter les fonctions anonymes
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

  Future<Map<String, dynamic>?> fetchMidWeekMeeting(Publication? publication) async {
    if (publication != null && publication.isDownloadedNotifier.value) {
      Database db = await openReadOnlyDatabase(publication.databasePath!);

      String weekRange = DateFormat('yyyyMMdd').format(dateOfMeetingValue);

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

      String weekRange = DateFormat('yyyyMMdd').format(this.dateOfMeetingValue);

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
    // Trouver le premier jour de la semaine (lundi)
    DateTime firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    // Trouver le dernier jour de la semaine (dimanche)
    DateTime lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    // Formater les jours et le mois
    String dayStart = DateFormat('d').format(firstDayOfWeek);
    String dayEnd = DateFormat('d').format(lastDayOfWeek);
    String month = DateFormat('MMMM', 'fr_FR').format(date); // Formatage du mois en français

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

    if (JwLifePage.getHomeGlobalKey().currentState?.isRefreshing ?? true) {
      return getLoadingWidget(Theme.of(context).primaryColor);
    }
    else {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Réunions et Assemblées', style: textStyleTitle),
              Text(formatWeekRange(dateOfMeetingValue), style: textStyleSubtitle),
            ],
          ),
          actions: [
            ResponsiveAppBarActions(
              allActions: [
                IconTextButton(
                  icon: Icon(JwIcons.language),
                  text: 'Autres langues',
                  onPressed: () {
                    // Logique de changement de langue ici
                  },
                ),
                IconTextButton(
                  icon: Icon(JwIcons.calendar),
                  text: 'Sélectionner une semaine',
                  onPressed: () async {
                    DateTime? selectedWeek = await showMonthCalendarDialog(context, dateOfMeetingValue);
                    if (selectedWeek != null) {
                      List<Publication> weeksPubs = await PubCatalog.getPublicationsForTheDay(date: selectedWeek);

                      refreshMeetingsPubs(publications: weeksPubs);

                      setState(() {
                        dateOfMeetingValue = selectedWeek;
                      });
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
              ],
            )
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔝 Prochaine réunion
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[400]!, Colors.indigo[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PROCHAINE RÉUNION',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _initialIndex == 0 ? 'Réunion de semaine' : 'Réunion du week-end',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mercredi 19 octobre à 19h30',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              /// 📌 Section Réunions
              Text('Réunions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 8),

              _buildMeetingCard(
                context: context,
                title: localization(context).navigation_meetings_life_and_ministry,
                icon: JwIcons.sheep,
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: _isMidweekMeetingContentIsDownload(context, dateOfMeetingValue),
              ),
              const SizedBox(height: 16),

              _buildMeetingCard(
                context: context,
                title: localization(context).navigation_meetings_watchtower_study,
                icon: JwIcons.watchtower,
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: _isWeekendMeetingContentIsDownload(context, dateOfMeetingValue),
              ),
              const SizedBox(height: 40),

              /// 🏟️ Section Assemblées
              Text('Assemblées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 8),

              _buildMeetingCard(
                context: context,
                title: localization(context).navigation_meetings_assembly_br,
                icon: JwIcons.arena,
                gradient: const LinearGradient(
                  colors: [Color(0xFFfc4a1a), Color(0xFFf7b733)], // 🔁 Couleurs modifiées
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: _isCircuitBrContentIsDownload(context),
              ),
              const SizedBox(height: 16),

              _buildMeetingCard(
                context: context,
                title: localization(context).navigation_meetings_assembly_co,
                icon: JwIcons.arena,
                gradient: const LinearGradient(
                  colors: [Color(0xFFfd746c), Color(0xFFff9068)], // 🔁 Couleurs modifiées
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: _isCircuitCoContentIsDownload(context),
              ),
              const SizedBox(height: 16),

              _buildMeetingCard(
                context: context,
                title: localization(context).navigation_meetings_convention,
                icon: JwIcons.arena,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: _isConventionContentIsDownload(context),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMeetingCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required LinearGradient gradient,
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
            gradient: gradient,
          ),
          child: Column(
            children: [
              // Header de la card avec glassmorphism
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu de la card
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 100),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Vos méthodes existantes restent inchangées
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

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadState(BuildContext context, Publication publication, String buttonText) {
    return Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              publication.download(context);
            },
            child: Text(
              buttonText.toUpperCase(),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 75,
              height: 75,
              child: ImageCachedWidget(imageUrl: imagePath),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Pour éviter d’occuper trop de place verticalement
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
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
    );
  }

  Widget _buildWeekendContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Titre Discours Publique
        if(_publicTalkPub != null)
          Row(
            children: [
              Icon(JwIcons.document_speaker, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                "DISCOURS PUBLIQUE",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        if(_publicTalkPub != null)
          const SizedBox(height: 8),

        // Container contenu Discours
        if(_publicTalkPub != null)
          GestureDetector(
            onLongPress: () {
              _showPublicTalksDialog();
            },
            onTap: () async {
              if(selectedPublicTalk != null) {
                showPage(
                  context,
                  DocumentPage(
                    publication: _publicTalkPub!,
                    mepsDocumentId: selectedPublicTalk!.mepsDocumentId,
                  ),
                );
              }
              else {
                _showPublicTalksDialog();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: selectedPublicTalk != null ? Text(selectedPublicTalk!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)) : Text(
                "Choisir le numéro de discours ici...", // Remplace ceci par le contenu réel si nécessaire
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),

        if(_publicTalkPub != null)
          const SizedBox(height: 28),

        // Titre Étude de la Tour de Garde
        if(_publicTalkPub != null)
          Row(
            children: [
              Icon(JwIcons.watchtower, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                "ÉTUDE DE LA TOUR DE GARDE",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),

        if(_publicTalkPub != null)
          const SizedBox(height: 8),

        // Contenu de l'étude
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
                    width: 75,
                    height: 75,
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
                          fontSize: 19,
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
          return PublicationMenuView(publication: publication, showAppBar: false);
        }
      },
    );
  }


  Widget _isCircuitBrContentIsDownload(BuildContext context) {
    if (_circuitBrPub == null) {
      return const Center(
        child: Text("Pas de programme pour l'Assemblée de circonscription avec un représentant de la filiale"),
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
          // Les deux non téléchargées : 2 blocs séparés
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
    if (_circuitBrPub == null) {
      return const Center(
        child: Text("Pas de programme pour l'Assemblée de circonscription avec le responsable de circonscription"),
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
          // Les deux non téléchargées : 2 blocs séparés
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
}

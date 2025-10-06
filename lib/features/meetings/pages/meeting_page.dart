import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/constants.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/jworg_uri.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/data/models/meps_language.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/library/widgets/rectangle_publication_item.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/jwlife_app.dart';
import '../../../app/services/global_key_service.dart';
import '../../../app/services/settings_service.dart';
import '../../../core/shared_preferences/shared_preferences_utils.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils.dart';
import '../../../data/databases/history.dart';
import '../../../data/models/userdata/congregation.dart';
import '../../../widgets/dialog/language_dialog.dart';
import '../../../widgets/responsive_appbar_actions.dart';
import '../../publication/pages/document/data/models/document.dart';
import '../../publication/pages/document/local/documents_manager.dart';
import '../../publication/pages/menu/local/publication_menu_view.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  MeetingsPageState createState() => MeetingsPageState();
}

class MeetingsPageState extends State<MeetingsPage> {
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

  @override
  void initState() {
    super.initState();

    refreshMeetingsPubs();
    refreshConventionsPubs();

    fetchFirstCongregation();

    setState(() {
      isLoading = false;
    });
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

    const Color _primaryColor = Color(0xFF1E88E5); // Bleu clair
    const Color _accentColor = Color(0xFFFFB300); // Jaune-orange
    const Color _midweekColor = Color(0xFF5D4037); // Marron foncé
    const Color _watchtowerColor = Color(0xFF26A69A); // Cyan/Teal
    const Color _publicationsColor = Color(0xFF66BB6A); // Vert moyen
    const Color _assemblyBrColor = Color(0xFFEF5350); // Rouge corail
    const Color _assemblyCoColor = Color(0xFFFFCA28); // Jaune vif
    const Color _conventionColor = Color(0xFF42A5F5); // Bleu ciel

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réunions et Assemblées', style: textStyleTitle),
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
                  LanguageDialog languageDialog = LanguageDialog();
                  showDialog(
                    context: context,
                    builder: (context) => languageDialog,
                  ).then((value) async {
                    if (value != null) {
                      if (value['Symbol'] != JwLifeSettings().currentLanguage.symbol) {
                        await setLibraryLanguage(value);
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column( // Empile tous les widgets
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. WIDGET DE LA PROCHAINE RÉUNION (Builder)
            _congregation?.nextMeeting() == null
                ? const SizedBox.shrink()
                : Builder(
              builder: (context) {
                // ... (La logique de détermination de la réunion reste la même)
                final meeting = _congregation!.nextMeeting();

                if (meeting == null) return const SizedBox.shrink();

                final date = meeting["date"] as DateTime;
                final type = meeting["type"] as String;
                final isMidweek = type == "midweek";

                final icon = isMidweek ? JwIcons.sheep : JwIcons.watchtower; // DÉTERMINATION DE L'ICÔNE

                final dateStr = DateFormat("EEEE d MMMM 'à' HH'h'mm", JwLifeSettings().currentLanguage.primaryIetfCode).format(date);

                // Retourne uniquement le Container stylisé, car le Row externe n'est plus nécessaire.
                return Padding(
                  padding: const EdgeInsets.only(bottom: 25.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A6DA7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Le Row principal gère l'alignement horizontal et vertical
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center, // <-- ALIGNEMENT VERTICAL AJOUTÉ
                      children: [
                       Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon( // Icône à gauche (taille 50, comme demandé)
                            icon,
                            color: Colors.white70,
                            size: 50,
                          ),
                         ),
                        Expanded( // <-- WIDGET ESSENTIEL AJOUTÉ
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, // <-- ALIGNE LE TEXTE À DROITE
                            mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement
                            mainAxisSize: MainAxisSize.min, // S'assure que la Column ne prend que l'espace nécessaire
                            children: [
                              const Text(
                                'PROCHAINE RÉUNION',
                                textAlign: TextAlign.right, // <-- ALIGNE LE TEXTE DANS SA ZONE
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4), // Espace réduit
                              Text(
                                dateStr,
                                textAlign: TextAlign.right, // <-- ALIGNE LE TEXTE DANS SA ZONE
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SECTION RÉUNIONS

                // Titre de section plus simple
                const Text(
                  'Réunions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600, // Un peu moins gras que 'bold' pour un look moderne
                    fontSize: 26, // Légèrement plus grand
                  ),
                ),
                const SizedBox(height: 16), // Espacement légèrement augmenté

                // Carte Réunion Vie et Ministère
                _buildMeetingCard(
                  context: context,
                  title: localization(context).navigation_meetings_life_and_ministry,
                  icon: JwIcons.sheep,
                  color: _midweekColor, // Couleur thématique
                  child: _isMidweekMeetingContentIsDownload(context, _dateOfMeetingValue),
                ),
                const SizedBox(height: 12), // Espacement cohérent

                // Carte Étude de la Tour de Garde
                _buildMeetingCard(
                  context: context,
                  title: localization(context).navigation_meetings_watchtower_study,
                  icon: JwIcons.watchtower,
                  color: _watchtowerColor, // Couleur thématique
                  child: _isWeekendMeetingContentIsDownload(context, _dateOfMeetingValue),
                ),
                const SizedBox(height: 12),

                // Carte Autres Publications
                _buildMeetingCard(
                  context: context,
                  title: 'Autres publications',
                  icon: JwIcons.book_stack,
                  color: _publicationsColor, // Couleur thématique
                  child: _meetingsPublications(context),
                ),

                const SizedBox(height: 48), // Grand espacement avant la nouvelle section

                // ---

                // 2. SECTION ASSEMBLÉES

                // Titre de section
                const Text(
                  'Assemblées',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 16),

                // Carte Assemblée de Circonscription (BR)
                _buildMeetingCard(
                  context: context,
                  title: localization(context).navigation_meetings_assembly_br,
                  icon: JwIcons.arena,
                  color: _assemblyBrColor, // Couleur thématique
                  child: _isCircuitBrContentIsDownload(context),
                ),
                const SizedBox(height: 12),

                // Carte Assemblée de Circonscription (CO)
                _buildMeetingCard(
                  context: context,
                  title: localization(context).navigation_meetings_assembly_co,
                  icon: JwIcons.arena,
                  color: _assemblyCoColor, // Couleur thématique
                  child: _isCircuitCoContentIsDownload(context),
                ),
                const SizedBox(height: 12),

                // Carte Assemblée Régionale/Internationale
                _buildMeetingCard(
                  context: context,
                  title: localization(context).navigation_meetings_convention,
                  icon: JwIcons.arena,
                  color: _conventionColor, // Couleur thématique
                  child: _isConventionContentIsDownload(context),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      )
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
              // Header de la card avec glassmorphism
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
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
                          fontSize: 14,
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

  Widget _meetingsPublications(BuildContext context) {
    List<Publication> publications = [
      if (_midweekMeetingPub != null) _midweekMeetingPub!,
      if (_weekendMeetingPub != null) _weekendMeetingPub!,
      ...PubCatalog.otherMeetingsPublications
    ];

    // Création de la liste de Widgets avec les séparateurs
    List<Widget> children = [];

    for (int i = 0; i < publications.length; i++) {
      // 1. Ajout de l'élément de publication
      children.add(RectanglePublicationItem(publication: publications[i], backgroundColor: Theme.of(context).cardColor, imageSize: 70));

      // 2. Ajout du séparateur, sauf après le dernier élément
      if (i < publications.length - 1) {
        children.add(const SizedBox(height: 8));
      }
    }

    // Utilisation de la Column au lieu du ListView
    return Padding(
        padding: EdgeInsetsGeometry.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,

          // Alignement au début (par défaut, mais explicite)
          crossAxisAlignment: CrossAxisAlignment.start,

          // Contenu généré
          children: children,
        )
    );
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
      child: Padding(
          padding: EdgeInsetsGeometry.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 65,
                  height: 65,
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
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 17,
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
                    showPageDocument(_publicTalkPub!, selectedPublicTalk!.mepsDocumentId);
                    /*
                showPage(
                  context,
                  DocumentPage(
                    publication: _publicTalkPub!,
                    mepsDocumentId: selectedPublicTalk!.mepsDocumentId,
                  ),
                );

                 */
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

        return Padding(padding: EdgeInsetsGeometry.all(15), child: PublicationMenuView(publication: publicationCo, showAppBar: false));
      },
    );
  }
}

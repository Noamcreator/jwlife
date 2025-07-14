
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/PublicationRepository.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_menu_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:sqflite/sqflite.dart';

class MeetingsView extends StatefulWidget {
  static late Function() refreshMeetingsPubs;
  static late Function() refreshConventionsPubs;
  const MeetingsView({super.key});

  @override
  _MeetingsViewState createState() => _MeetingsViewState();
}

class _MeetingsViewState extends State<MeetingsView> {
  int initialIndex = 0;
  DateTime weekRange = DateTime.now();
  bool isLoading = true;

  Publication? _midweekMeetingPub;
  Publication? _weekendMeetingPub;
  Map<String, dynamic>? _midweekMeeting;
  Map<String, dynamic>? _weekendMeeting;

  Publication? _conventionPub;
  Publication? _circuitCoPub;
  Publication? _circuitBrPub;

  @override
  void initState() {
    super.initState();

    // Déterminer le jour de la semaine
    final now = DateTime.now();
    if (now.weekday >= DateTime.monday && now.weekday <= DateTime.friday) {
      initialIndex = 0; // Du lundi au vendredi
    }
    else {
      initialIndex = 1; // Samedi et dimanche
    }

    MeetingsView.refreshMeetingsPubs = _refreshMeetingsPubs;
    MeetingsView.refreshConventionsPubs = _refreshConventionsPubs;

    _refreshMeetingsPubs();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _refreshMeetingsPubs() async {
    _midweekMeetingPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('mwb'));
    _weekendMeetingPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('w'));

    if(_midweekMeetingPub != null) {
      _midweekMeetingPub!.isDownloadedNotifier.addListener(() async {
        if (_midweekMeetingPub!.isDownloadedNotifier.value) {
          _midweekMeeting = await fetchMidWeekMeeting(_midweekMeetingPub);
          setState(() {}); // Met à jour l'affichage avec les nouvelles données
        }
        else {
          setState(() {
            _midweekMeeting = null;
          });
        }
      });
      _midweekMeeting = await fetchMidWeekMeeting(_midweekMeetingPub);
      //setState(() {}); // Met à jour l'affichage avec les nouvelles données
    }

    if(_weekendMeetingPub != null) {
      _weekendMeetingPub?.isDownloadedNotifier.addListener(() async {
        if (_weekendMeetingPub!.isDownloadedNotifier.value) {
          _weekendMeeting = await fetchWeekendMeeting(_weekendMeetingPub);
          setState(() {}); // Met à jour l'affichage avec les nouvelles données
        }
        else {
          setState(() {
            _weekendMeeting = null;
          });
        }
      });
    }
  }

  void _refreshConventionsPubs() {
    setState(() {
      _conventionPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CO-pgm'));
      _circuitCoPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-copgm'));
      _circuitBrPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-brpgm'));
    });
  }

  Future<Map<String, dynamic>?> fetchMidWeekMeeting(Publication? publication) async {
    if (publication != null && publication.isDownloadedNotifier.value) {
      Database db = await openReadOnlyDatabase(publication.databasePath!);

      String weekRange = DateFormat('yyyyMMdd').format(this.weekRange);

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT Document.MepsDocumentId, Document.Title, Document.Subtitle, Multimedia.FilePath
        FROM Document
        LEFT JOIN DatedText ON DatedText.DocumentId = Document.DocumentId
        LEFT JOIN DocumentMultimedia ON DocumentMultimedia.DocumentId = Document.DocumentId
        LEFT JOIN Multimedia ON Multimedia.MultimediaId = DocumentMultimedia.MultimediaId
        WHERE Multimedia.CategoryType = ? AND DatedText.FirstDateOffset <= ? AND DatedText.LastDateOffset >= ?
        ORDER BY Multimedia.MultimediaId
        LIMIT 1
      ''', [8, weekRange, weekRange]);

      if (result.isNotEmpty) {
        return result.first;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchWeekendMeeting(Publication? publication) async {
    if (publication != null) {
      Database db = await openDatabase(publication.databasePath!);

      String weekRange = DateFormat('yyyyMMdd').format(this.weekRange);

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT Document.MepsDocumentId, Document.Title, Document.Subtitle, Multimedia.FilePath
        FROM Document
        LEFT JOIN DatedText ON DatedText.DocumentId = Document.DocumentId
        LEFT JOIN DocumentMultimedia ON DocumentMultimedia.DocumentId = Document.DocumentId
        LEFT JOIN Multimedia ON Multimedia.MultimediaId = DocumentMultimedia.MultimediaId
        WHERE Multimedia.CategoryType = ? AND DatedText.FirstDateOffset <= ? AND DatedText.LastDateOffset >= ?
        ORDER BY Multimedia.MultimediaId
        LIMIT 1
      ''', [8, weekRange, weekRange]);

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

  @override
  Widget build(BuildContext context) {
    // Styles partagés
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    if (HomeView.isRefreshing) {
      return getLoadingWidget(Theme.of(context).primaryColor);
    }
    else {
      return Scaffold(
          body: DefaultTabController(
            initialIndex: initialIndex,
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Réunions et Assemblées',
                        style: textStyleTitle
                    ),
                    Text(
                        formatWeekRange(weekRange),
                        style: textStyleSubtitle
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(JwIcons.magnifying_glass),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(JwIcons.language),
                    onPressed: () {},
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        child: Text('Sélectionner une semaine'),
                        onTap: () async {
                          DateTime selectedWeek = await showWeekSelectionDialog(context, weekRange);
                          setState(() {
                            isLoading = true;
                          });

                          List<Publication> weeksPubs = await PubCatalog.getPublicationsForTheDay(date: selectedWeek);

                          if (weeksPubs.isNotEmpty) {
                            //MeetingsView.watchtowerPub = weeksPubs.firstWhere((element) => element.keySymbol.contains('w'));
                            //MeetingsView.meetingWorkbookPub = weeksPubs.firstWhere((element) => element.keySymbol.contains('mwb'));
                          }

                          setState(() {
                            weekRange = selectedWeek;
                            isLoading = false;
                          });
                        },
                      ),
                      PopupMenuItem<String>(
                        child: Text('Voir les médias'),
                        onTap: () {
                          showPage(context, Container());
                        },
                      ),
                      PopupMenuItem<String>(
                        child: Text('Envoyer le lien'),
                        onTap: () {
                          /*
                    int mepsDocumentId = _document['MepsDocumentId'] ?? -1;
                    Share.share(
                      'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${widget.publication['LanguageSymbol']}&prefer=lang&docid=$mepsDocumentId',
                      subject: widget.publication['Title'],
                    );

                     */
                        },
                      ),
                      PopupMenuItem<String>(
                        child: Text('Taille de police'),
                        onTap: () {
                          Future.delayed(
                            Duration.zero,
                                () => showFontSizeDialog(context, null),
                          );
                        },
                      ),
                    ],
                  )
                ],
              ),
              body: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: <Widget>[
                      Tab(text: localization(context).navigation_meetings_life_and_ministry.toUpperCase()),
                      Tab(text: localization(context).navigation_meetings_watchtower_study.toUpperCase()),
                      Tab(text: localization(context).navigation_meetings_assembly.toUpperCase()),
                      Tab(text: localization(context).navigation_meetings_convention.toUpperCase()),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _isMidweekMeetingContentIsDownload(context, weekRange),
                        _isWeekendMeetingContentIsDownload(context, weekRange),
                        _isCircuitContentIsDownload(context),
                        _isConventionContentIsDownload(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      );
    }
  }

  Widget _isMidweekMeetingContentIsDownload(BuildContext context, DateTime weekRange) {
    if (_midweekMeetingPub == null) {
      return const Center(child: Text('Pas de contenu pour la réunion de la semaine'));
    }

    if (!_midweekMeetingPub!.isDownloadedNotifier.value) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _midweekMeetingPub!.issueTitle,
              style: const TextStyle(fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                textStyle: const TextStyle(fontSize: 17),
              ),
              onPressed: () {
                _midweekMeetingPub!.download(context);
              },
              child: Text(localization(context).action_download.toUpperCase()),
            ),
            const SizedBox(height: 10),

            // 🔄 Barre de progression liée au ValueNotifier
            ValueListenableBuilder<double>(
              valueListenable: _midweekMeetingPub!.progressNotifier,
              builder: (context, value, _) {
                if (value == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: LinearProgressIndicator(
                    value: value == -1 ? null : value,
                    minHeight: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[300],
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else {
      if (_midweekMeeting != null) {
        String imagePath = '${_midweekMeetingPub!.path!}/${_midweekMeeting!['FilePath']}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              child: ImageCachedWidget(imageUrl: imagePath),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                showDocumentView(context, _midweekMeeting!['MepsDocumentId'], JwLifeApp.settings.currentLanguage.id);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réunion de semaine du ${_midweekMeeting!['Title']}',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _midweekMeeting!['Subtitle'],
                      style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }
  }

  Widget _isWeekendMeetingContentIsDownload(BuildContext context, DateTime weekRange) {
    if (_weekendMeetingPub == null) {
      return const Center(child: Text('Pas de contenu pour la réunion du week-end'));
    }

    if (!_weekendMeetingPub!.isDownloadedNotifier.value) {
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(child: Column(
              children: [
                Text(_weekendMeetingPub!.issueTitle, style: TextStyle(fontSize: 17)),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                    textStyle: const TextStyle(fontSize: 17),
                  ),
                  onPressed: () {
                    _weekendMeetingPub!.download(context);
                  },
                  child: Text(localization(context).action_download.toUpperCase()),
                ),
              ],
            )),
            _weekendMeetingPub!.progressNotifier.value != 0 ? const Spacer() : Container(),
            _weekendMeetingPub!.progressNotifier.value == -1 ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)) : _weekendMeetingPub!.progressNotifier.value == 0 ? Container():
            LinearProgressIndicator(
                value: _weekendMeetingPub!.progressNotifier.value,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                color: Theme.of(context).primaryColor)
          ]
      );
    }
    else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("DISCOURS PUBLIQUE",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            )
          ),
          const SizedBox(height: 10),
          Text("ÉTUDE DE LA TOUR DE GARDE",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
          ),
        ],
      );
    }
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  publication.title,
                  style: const TextStyle(fontSize: 17),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    textStyle: const TextStyle(fontSize: 17),
                  ),
                  onPressed: () {
                    publication.download(context);
                  },
                  child: Text(localization(context).action_download.toUpperCase()),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<double>(
                  valueListenable: publication.progressNotifier,
                  builder: (context, value, _) {
                    if (value == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: LinearProgressIndicator(
                        value: value == -1 ? null : value,
                        minHeight: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[300],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        } else {
          return PublicationMenuView(publication: publication, showAppBar: false);
        }
      },
    );
  }


  Widget _isCircuitContentIsDownload(BuildContext context) {
    if (_circuitBrPub == null || _circuitCoPub == null) {
      return const Center(child: Text("Pas de programme pour l'Assemblée de circonscription"));
    }

    Publication publicationBr = PublicationRepository().getPublication(_circuitBrPub!)!;
    Publication publicationCo = PublicationRepository().getPublication(_circuitCoPub!)!;

    Widget buildPublicationWidget(Publication pub) {
      return ValueListenableBuilder<bool>(
        valueListenable: pub.isDownloadedNotifier,
        builder: (context, isDownloaded, _) {
          if (!isDownloaded) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  pub.title,
                  style: const TextStyle(fontSize: 17),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    textStyle: const TextStyle(fontSize: 17),
                  ),
                  onPressed: () {
                    pub.download(context);
                  },
                  child: Text(localization(context).action_download.toUpperCase()),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<double>(
                  valueListenable: pub.progressNotifier,
                  builder: (context, value, _) {
                    if (value == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: LinearProgressIndicator(
                        value: value == -1 ? null : value,
                        minHeight: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[300],
                      ),
                    );
                  },
                ),
              ],
            );
          } else {
            return PublicationMenuView(publication: pub, showAppBar: false);
          }
        },
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: publicationBr.isDownloadedNotifier,
      builder: (context, isDownloadedBr, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: publicationCo.isDownloadedNotifier,
          builder: (context, isDownloadedCo, _) {
            bool noneDownloaded = !isDownloadedBr && !isDownloadedCo;

            if (noneDownloaded) {
              // On découpe l'écran en 2 moitiés, avec divider au milieu
              return SizedBox.expand(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(child: buildPublicationWidget(publicationBr)),
                    ),
                    const Divider(height: 2, color: Colors.grey, thickness: 3),
                    Expanded(
                      child: Center(child: buildPublicationWidget(publicationCo)),
                    ),
                  ],
                ),
              );
            } else {
              // Si au moins une publication téléchargée, affichage normal
              return SingleChildScrollView(
                child: Column(
                  children: [
                    buildPublicationWidget(publicationBr),
                    const Divider(height: 50, color: Colors.grey, thickness: 3),
                    buildPublicationWidget(publicationCo),
                    !isDownloadedBr && !isDownloadedCo ? const SizedBox.shrink() : const SizedBox(height: 30),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }
}

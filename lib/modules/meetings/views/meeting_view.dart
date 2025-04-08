import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/data/databases/Publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/i18n/localization.dart';
import 'package:jwlife/modules/home/views/home_view.dart';
import 'package:jwlife/modules/library/views/publication/local/meetings_document_view.dart';
import 'package:jwlife/modules/library/views/publication/local/publication_menu_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';

class MeetingsView extends StatefulWidget {
  static late Function() refreshMeetingsView;
  const MeetingsView({super.key});

  @override
  _MeetingsViewState createState() => _MeetingsViewState();
}

class _MeetingsViewState extends State<MeetingsView> {
  int initialIndex = 0;
  DateTime weekRange = DateTime.now();
  String? docLaM;
  int? docIdLaM;
  String? docWatchtower;
  int? docIdWatchtower;
  Map<String, dynamic>? regional_convention_pub;
  bool isLoading = true;

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

    MeetingsView.refreshMeetingsView = _reloadPage;

    _reloadPage();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _reloadPage() async {
    _conventionPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CO-pgm'));
    _circuitCoPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-copgm'));
    _circuitBrPub = PubCatalog.assembliesPublications.firstWhereOrNull((element) => element.keySymbol.contains('CA-brpgm'));
    setState(() {});
  }

  Future<void> fetchMeetingsOfTheWeek() async {
    /*
    if (HomeView.publicationOfTheDay!.isNotEmpty) {
      String? dailyTextHtml = await PublicationsCatalog.getDatedDocumentForToday(HomeView.publicationOfTheDay!.elementAt(2));
      if (dailyTextHtml != null) {
        setState(() {
          docLaM = dailyTextHtml;
        });
      }
    }

     */
    String languageSymbol = JwLifeApp.settings.currentLanguage.symbol;
    try {
      final response = await http.get(Uri.parse('https://wol.jw.org/wol/finder?wtlocale=$languageSymbol&alias=meetings&date=${DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 1)))}'));

      if (response.statusCode == 200) {
        var htmlPage = html_parser.parse(response.body);

        var linkCard = htmlPage.querySelector('.linkCard')?.querySelector('a');
        if (linkCard != null && linkCard.attributes['href'] != null) {
          final uri = Uri.parse(linkCard.attributes['href']!);
          final pathSegments = uri.pathSegments;
          final newPath = pathSegments.skip(1).join('/');

          final response1 = await http.get(Uri.parse('https://wol.jw.org/' + newPath));

          if (response1.statusCode == 200) {
            final jsonResponse1 = json.decode(response1.body);
            setState(() {
              docLaM = jsonResponse1['content'];
              docIdLaM = int.parse(newPath.split('/').last);
            });
          }
        }

        var linkWt = htmlPage.querySelector('.itemData .groupTOC')?.querySelector('a')?.attributes['href'];
        if (linkWt != null) {
          final uri2 = Uri.parse(linkWt);
          final pathSegments2 = uri2.pathSegments;
          final newPath2 = pathSegments2.skip(1).join('/');
          final response2 = await http.get(Uri.parse('https://wol.jw.org/' + newPath2));

          if (response2.statusCode == 200) {
            final jsonResponse2 = json.decode(response2.body);
            setState(() {
              docWatchtower = jsonResponse2['items'][0]['content'];
              docIdWatchtower = jsonResponse2['items'][0]['did'];
            });
          }
        }
      }
      else {
        throw Exception('Failed to load publication');
      }
    } catch (e) {
      print('Error: $e');
    }
    finally {
      setState(() {
        isLoading = false;
      });
    }
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
    if (HomeView.isRefreshing) {
      return getLoadingWidget();
    }
    else {
      return DefaultTabController(
        initialIndex: initialIndex,
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Réunions et Assemblées',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  formatWeekRange(weekRange),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                    _isMeetingsContentIsDownload(context, PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('mwb')), weekRange, update: (progress) {
                      setState(() {});
                    }),
                    _isMeetingsContentIsDownload(context, PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('w')), weekRange, update: (progress) {
                      setState(() {});
                    }),
                    _isCircuitContentIsDownload(context, update: (progress) {
                      setState(() {});
                    }),
                    _isConventionContentIsDownload(context, update: (progress) {
                      setState(() {});
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _isMeetingsContentIsDownload(BuildContext context, Publication? publication, DateTime weekRange, {void Function(double progress)? update}) {
    if (publication == null) {
      return const Center(child: Text('Pas de contenu pour la semaine'));
    }

    Publication? downloadedPublication = JwLifeApp.pubCollections.getPublication(publication);
    if (!downloadedPublication.isDownloaded) {
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(child: Column(
              children: [
                Text(downloadedPublication.issueTitle, style: TextStyle(fontSize: 17)),
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
                    downloadedPublication.download(context, update: update);
                  },
                  child: Text(localization(context).action_download.toUpperCase()),
                ),
              ],
            )),
            downloadedPublication.downloadProgress != 0 ? const Spacer() : Container(),
            downloadedPublication.downloadProgress == -1 ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)) : downloadedPublication.downloadProgress == 0 ? Container():
            LinearProgressIndicator(
                value: downloadedPublication.downloadProgress,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                color: Theme.of(context).primaryColor)
          ]
      );
    }
    else {
      return MeetingsDocumentView(publication: downloadedPublication, weekRange: DateFormat('yyyyMMdd').format(weekRange));
    }
  }

  Widget _isConventionContentIsDownload(BuildContext context, {void Function(double progress)? update}) {
    if (_conventionPub == null) {
      return const Center(child: Text("Pas de programme pour l'Assemblée Régionale"));
    }

    Publication? downloadedPublication = JwLifeApp.pubCollections.getPublication(_conventionPub!);
    if (!downloadedPublication.isDownloaded) {
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(child: Column(
              children: [
                Text(downloadedPublication.issueTitle, style: TextStyle(fontSize: 17)),
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
                    downloadedPublication.download(context, update: update);
                  },
                  child: Text(localization(context).action_download.toUpperCase()),
                ),
              ],
            )),
            downloadedPublication.downloadProgress != 0 ? const Spacer() : Container(),
            downloadedPublication.downloadProgress == -1 ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)) : downloadedPublication.downloadProgress == 0 ? Container():
            LinearProgressIndicator(
                value: downloadedPublication.downloadProgress,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                color: Theme.of(context).primaryColor)
          ]
      );
    }
    else {
      return PublicationMenuView(publication: downloadedPublication, showAppBar: false);
    }
  }

  Widget _isCircuitContentIsDownload(BuildContext context, {void Function(double progress)? update}) {
    if (_circuitBrPub == null) {
      return const Center(child: Text("Pas de programme pour l'Assemblée Régionale"));
    }

    Publication? downloadedPublication = JwLifeApp.pubCollections.getPublication(_circuitBrPub!);
    Publication? downloadedPublication1 = JwLifeApp.pubCollections.getPublication(_circuitCoPub!);

    if (!downloadedPublication.isDownloaded) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Column(
              children: [
                Text(downloadedPublication.issueTitle, style: TextStyle(fontSize: 17)),
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
                    downloadedPublication.download(context, update: update);
                  },
                  child: Text(localization(context).action_download.toUpperCase()),
                ),
              ],
            ),
          ),
          downloadedPublication.downloadProgress != 0 ? const Spacer() : Container(),
          downloadedPublication.downloadProgress == -1
              ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))
              : downloadedPublication.downloadProgress == 0
              ? Container()
              : LinearProgressIndicator(
              value: downloadedPublication.downloadProgress,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              color: Theme.of(context).primaryColor)
        ],
      );
    }
    else {
      return SingleChildScrollView(
        child: Column(
          children: [
            PublicationMenuView(publication: downloadedPublication, showAppBar: false),
            const Divider(height: 50, color: Colors.grey, thickness: 3),
            PublicationMenuView(publication: downloadedPublication1, showAppBar: false),
          ],
        ),
      );
    }
  }
}

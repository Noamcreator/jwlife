import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils_document.dart';
import 'package:jwlife/core/utils/utils_publication.dart';
import 'package:jwlife/l10n/localization.dart';
import 'package:jwlife/modules/library/views/publication/local/document_view.dart';
import 'package:jwlife/widgets/dialog/utils_dialog.dart';
import 'package:sqflite/sqflite.dart';

class MeetingsView extends StatefulWidget {
  static dynamic meetingWorkbookPub;
  static dynamic watchtowerPub;
  const MeetingsView({super.key});

  @override
  _MeetingsViewState createState() => _MeetingsViewState();
}

class _MeetingsViewState extends State<MeetingsView> {
  int initialIndex = 0;
  String weekRange = '';
  String? docLaM;
  int? docIdLaM;
  String? docWatchtower;
  int? docIdWatchtower;
  Map<String, dynamic>? regional_convention_pub;
  bool isLoading = true;

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

    weekRange = DateFormat('yyyyMMdd').format(DateTime.now());  // Retourne le premier jour de la semaine au format 'yyyy-MM-dd'

    fetchMeetingsOfTheWeek();
    //fetchRegionalConvention();

    setState(() {
      isLoading = false;
    });
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
    String languageSymbol = JwLifeApp.currentLanguage.symbol;
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

  Future<void> fetchRegionalConvention() async {
    int mepsLanguageId = JwLifeApp.currentLanguage.id;

    File catalogosFile = await getCatalogFile();
    File mepsFile = await getMepsFile();

    if (await catalogosFile.exists()) {
      Database catalogDatabase = await openDatabase(catalogosFile.path);

      await catalogDatabase.execute("ATTACH DATABASE ? AS meps", [mepsFile.path]);

      // Changez le type de result ici
      List<Map<String, dynamic>> resultList = await catalogDatabase.rawQuery(''' 
        SELECT DISTINCT
          p.Id AS PublicationId,
          p.KeySymbol,
          p.Symbol,
          p.IssueTagNumber,
          p.Title,
          p.IssueTitle,
          p.ShortTitle,
          p.CoverTitle,
          pam.PublicationAttributeId,
          p.MepsLanguageId,
          meps.Language.Symbol AS LanguageSymbol,
          (SELECT ia.NameFragment
          FROM ImageAsset ia
          JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
          WHERE paim.PublicationAssetId = pa.Id AND ia.NameFragment LIKE '%_sqr-%'
          ORDER BY ia.Width DESC
          LIMIT 1) AS ImageSqr,
          (SELECT ia.NameFragment
          FROM ImageAsset ia
          JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
          WHERE paim.PublicationAssetId = pa.Id AND ia.NameFragment LIKE '%_lsr-%'
          ORDER BY ia.Width DESC
          LIMIT 1) AS ImageLsr
        FROM 
          Publication p
        LEFT JOIN
          PublicationAsset pa ON p.Id = pa.PublicationId
        LEFT JOIN
          PublicationRootKey prk ON p.PublicationRootKeyId = prk.Id
        LEFT JOIN
          PublicationAssetImageMap paim ON pa.Id = paim.PublicationAssetId
        LEFT JOIN
          ImageAsset ia ON paim.ImageAssetId = ia.Id
        LEFT JOIN
          PublicationAttributeMap pam ON pa.PublicationId = pam.PublicationId
        LEFT JOIN
          meps.Language ON p.MepsLanguageId = meps.Language.LanguageId
        WHERE 
          p.MepsLanguageId = ? AND p.KeySymbol LIKE '%CO-pgm%'
        ORDER BY p.Year DESC
        LIMIT 1
        ''', [mepsLanguageId]);

      await catalogDatabase.execute("DETACH DATABASE meps");
      await catalogDatabase.close();

      setState(() {
        // Vérifiez si le résultat n'est pas vide avant d'accéder au premier élément
        regional_convention_pub = resultList.isNotEmpty ? resultList[0] : {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                formatWeekRange(DateTime.now()),
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
                    String selectedWeek = await showWeekSelectionDialog(context);
                    setState(() {
                      isLoading = true;
                    });
                    await Future.delayed(
                      Duration(milliseconds: 20),
                    );
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
                Tab(text: localization(context).navigation_meetings.toUpperCase()),
                Tab(text: localization(context).navigation_meetings_watchtower_study.toUpperCase()),
                Tab(text: localization(context).navigation_meetings_assembly.toUpperCase()),
                Tab(text: localization(context).navigation_meetings_convention.toUpperCase()),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _isContentIsDownload(context, MeetingsView.meetingWorkbookPub, weekRange, update: () {
                    setState(() {});
                  }),
                  _isContentIsDownload(context, MeetingsView.watchtowerPub, weekRange, update: () {
                    setState(() {});
                  }),
                  const Center(child: Text('Assemblé de circonscription')),
                  const Center(child: Text("Pas de contenu pour l'Assemblée régionale")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _isContentIsDownload(BuildContext context, dynamic publication, String weekRange, {void Function()? update}) {
  if (publication == null) {
    return const Center(child: Text('Pas de contenu pour la semaine'));
  }
  else if (publication['Download'] == 0) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(publication['IssueTitle']),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ButtonStyle(shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)))),
            onPressed: () {
              downloadPublication(context, publication, update: update);
            },
            child: Text(localization(context).action_download),
          ),
          publication['inProgress'] != null ? const Spacer() : Container(),
          publication['inProgress'] != null
              ? publication['inProgress'] == -1 ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)):
          LinearProgressIndicator(
              value: publication['inProgress'],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              color: Theme.of(context).primaryColor) : Container()
        ]
    );
  }
  else {
    return DocumentView(publication: publication, weekRange: weekRange);
  }
}

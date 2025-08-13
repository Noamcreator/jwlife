import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../app/services/global_key_service.dart';
import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/utils/common_ui.dart';
import '../../../../data/databases/catalog.dart';
import '../../../../data/models/publication.dart';
import '../../../../data/repositories/PublicationRepository.dart';
import '../../pages/daily_text_page.dart';

class DailyTextWidget extends StatefulWidget {
  const DailyTextWidget({super.key});

  @override
  DailyTextWidgetState createState() => DailyTextWidgetState();
}

class DailyTextWidgetState extends State<DailyTextWidget> {
  String _verseOfTheDay = "";

  late String locale;
  late String formattedDate;

  Publication? verseOfTheDayPub;
  late Publication publication;

  @override
  void initState() {
    super.initState();

    locale = JwLifeSettings().currentLanguage.primaryIetfCode;
    if (!DateFormat.allLocalesWithSymbols().contains(locale)) {
      locale = 'en'; // fallback
    }

    initializeDateFormatting(locale).then((_) {
      final now = DateTime.now();
      setState(() {
        formattedDate = capitalize(DateFormat('EEEE d MMMM yyyy', locale).format(now));
      });
    });

    verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('es'));
    if (verseOfTheDayPub != null) {
      publication = PublicationRepository().getPublication(verseOfTheDayPub!);
    }
  }

  void setVerseOfTheDay(String dailyText) {
    setState(() {
      _verseOfTheDay = dailyText;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (verseOfTheDayPub == null) {
      return Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF121212)
                : Colors.white,
            height: 128,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bienvenue sur JW Life',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Une application pour la vie d'un Témoin de Jéhovah",
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      );
    }

    final now = DateTime.now();

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (publication.isDownloadedNotifier.value) {
              GlobalKeyService.jwLifePageKey.currentState!.toggleNavBarDisable(true);

              final GlobalKey<DailyTextPageState> dailyTextPageKey = GlobalKey<DailyTextPageState>();
              GlobalKeyService.jwLifePageKey.currentState!.webViewPageKeys[GlobalKeyService.jwLifePageKey.currentState!.currentNavigationBottomBarIndex].add(dailyTextPageKey);

              showPage(context, DailyTextPage(key: dailyTextPageKey, publication: publication));
            } else {
              publication.download(context);
            }
          },
          child: Stack(
            children: [
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF121212)
                    : Colors.white,
                height: 128,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: publication.isDownloadedNotifier,
                      builder: (context, isDownloaded, _) {
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: isDownloaded && _verseOfTheDay.isNotEmpty
                                  ? [
                                const Icon(JwIcons.calendar, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(JwIcons.chevron_right, size: 24),
                              ]
                                  : [
                                Text(
                                  'Bienvenue sur JW Life',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<bool>(
                              valueListenable: publication.isDownloadedNotifier,
                              builder: (context, isDownloaded, _) {
                                if (isDownloaded) {
                                  return _verseOfTheDay.isNotEmpty
                                      ? Text(
                                    _verseOfTheDay,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, height: 1.2),
                                    maxLines: 4,
                                  )
                                      : getLoadingWidget(Theme.of(context).primaryColor);
                                } else {
                                  return Text(
                                    "Télécharger le Texte du Jour de l'année ${DateFormat('yyyy').format(now)}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, height: 1.2),
                                    maxLines: 4,
                                  );
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: publication.isDownloadingNotifier,
                builder: (context, isDownloading, _) {
                  if (!isDownloading) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: publication.progressNotifier,
                      builder: (context, progress, _) {
                        return LinearProgressIndicator(
                          value: progress == -1.0 ? null : progress,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                          backgroundColor: Colors.grey[300],
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// Assure-toi d'avoir la fonction capitalize définie
String capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

// Placeholder pour getLoadingWidget, remplace par ta vraie fonction
Widget getLoadingWidget(Color color) {
  return CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(color));
}

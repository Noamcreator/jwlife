import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/utils/common_ui.dart';
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/widgets_utils.dart';
import '../../../../data/databases/catalog.dart';
import '../../../../data/models/publication.dart';

class DailyTextWidget extends StatefulWidget {
  const DailyTextWidget({super.key});

  @override
  DailyTextWidgetState createState() => DailyTextWidgetState();
}

class DailyTextWidgetState extends State<DailyTextWidget> {
  String _verseOfTheDay = "";

  late String formattedDate;

  Publication? _verseOfTheDayPub;

  @override
  void initState() {
    super.initState();
    _verseOfTheDayPub = PubCatalog.datedPublications.firstWhereOrNull((element) => element.keySymbol.contains('es'));
  }

  void setVersePub(Publication pub) {
    String locale = JwLifeSettings().currentLanguage.primaryIetfCode;
    if (!DateFormat.allLocalesWithSymbols().contains(locale)) {
      locale = 'en'; // fallback
    }

    initializeDateFormatting(locale).then((_) {
      final now = DateTime.now();
      setState(() {
        formattedDate = capitalize(DateFormat('EEEE d MMMM yyyy', locale).format(now));
        _verseOfTheDayPub = pub;
      });
    });
  }

  void setVerseOfTheDay(String dailyText) {
    setState(() {
      _verseOfTheDay = dailyText;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verseOfTheDayPub == null) {
      return Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF121212)
                : Colors.white,
            height: 128,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
            if (_verseOfTheDayPub == null) return;
            if (_verseOfTheDayPub!.isDownloadedNotifier.value) {
              showPageDailyText(_verseOfTheDayPub!);
            }
            else {
              _verseOfTheDayPub!.download(context);
            }
          },
          child: Stack(
            children: [
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF121212)
                    : Colors.white,
                height: 128,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _verseOfTheDayPub!.isDownloadedNotifier,
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
                                Icon(Directionality.of(context) == TextDirection.rtl ? JwIcons.chevron_left : JwIcons.chevron_right, size: 24),
                              ] : [
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
                              valueListenable: _verseOfTheDayPub!.isDownloadedNotifier,
                              builder: (context, isDownloaded, _) {
                                if (isDownloaded) {
                                  return _verseOfTheDay.isNotEmpty ? Text(
                                    _verseOfTheDay,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, height: 1.2),
                                    maxLines: 4,
                                  ) : getLoadingWidget(Theme.of(context).primaryColor);
                                }
                                else {
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
                valueListenable: _verseOfTheDayPub!.isDownloadingNotifier,
                builder: (context, isDownloading, _) {
                  if (!isDownloading) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _verseOfTheDayPub!.progressNotifier,
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
        const SizedBox(height: 5),
      ],
    );
  }
}
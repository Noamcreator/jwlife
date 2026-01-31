import 'package:collection/collection.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:jwlife/data/databases/meps_languages.dart';
import 'package:jwlife/data/repositories/PublicationRepository.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/services/global_key_service.dart';
import '../../data/databases/catalog.dart';
import '../../data/models/audio.dart';
import '../../data/models/publication.dart';
import '../../data/models/video.dart';
import '../../data/realm/catalog.dart';
import '../../features/bible/pages/bible_chapter_page.dart';
import '../app_data/meetings_pubs_service.dart';
import '../utils/common_ui.dart';
import '../utils/utils_document.dart';
import '../utils/utils_video.dart';
import 'jworg_uri.dart';

Future<void> handleUri(JwOrgUri uri) async {
  final context = GlobalKeyService.jwLifePageKey.currentContext!;

  try {
    if (uri.isPublication) {
      Publication? publication = await CatalogDb.instance.searchPub(uri.pub!, uri.issue!, uri.wtlocale);
      if (publication != null) {
        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0);
        publication.showMenu(context);
      }
    }
    else if (uri.isDocument) {
      int? mepsLanguageId = MepsLanguages.getMepsLanguageIdFromSymbol(uri.wtlocale);
      if (mepsLanguageId == null) return;

      int? startParagraphId;
      int? endParagraphId;

      String? parStr = uri.par; // ex: "4" ou "4-6"

      if(parStr != null) {
        if (parStr.contains('-')) {
          final parts = parStr.split('-');
          startParagraphId = int.parse(parts[0]);
          endParagraphId = int.parse(parts[1]);
        } else {
          startParagraphId = int.parse(parStr);
          endParagraphId = startParagraphId;
        }
      }

      GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0);

      showDocumentView(
        context,
        uri.docid!,
        mepsLanguageId,
        startParagraphId: startParagraphId,
        endParagraphId: endParagraphId,
      );
    }
    else if (uri.isBibleBook) {
      Publication? biblePub = PublicationRepository().getLookUpBible();
      if (biblePub == null) return;

      GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(1, goToFirstPage: true);

      showPage(
          BibleChapterPage(
              bible: biblePub,
              book: uri.book!
          ));
    }
    else if (uri.isBibleChapter) {
      String bibleStr = uri.bible!; // ex: "01003015" ou "01003000-01003999"

      int bibleBook;
      int bibleChapter;
      int firstVerse;
      int lastVerse;

      if (bibleStr.contains('-')) {
        // Plage de versets
        final parts = bibleStr.split('-');
        final start = int.parse(parts[0]);
        final end = int.parse(parts[1]);

        bibleBook = start ~/ 1000000;
        bibleChapter = (start ~/ 1000) % 1000;
        firstVerse = start % 1000;
        lastVerse = end % 1000;
      }
      else {
        // Verset unique
        final value = int.parse(bibleStr);
        bibleBook = value ~/ 1000000;
        bibleChapter = (value ~/ 1000) % 1000;
        firstVerse = value % 1000;
        lastVerse = firstVerse;
      }

      Publication? biblePub = PublicationRepository().getLookUpBible();
      if (biblePub == null) return;

      GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(1, goToFirstPage: true);

      showPageBibleChapter(
        biblePub,
        bibleBook,
        bibleChapter,
        firstVerse: firstVerse,
        lastVerse: lastVerse,
      );
    }
    else if (uri.isMediaItem) {
      Duration startTime = Duration.zero;

      if (uri.ts != null && uri.ts!.isNotEmpty) {
        final parts = uri.ts!.split('-');
        if (parts.isNotEmpty) {
          startTime = JwOrgUri.parseDuration(parts[0]) ?? Duration.zero;
        }
        if (parts.length > 1) {
        }
      }

      RealmMediaItem? mediaItem = getMediaItemFromLank(uri.lank!, uri.wtlocale);

      if (mediaItem == null) return;

      if(mediaItem.type == 'AUDIO') {
        Audio audio = Audio.fromJson(mediaItem: mediaItem);
        audio.showPlayer(context, initialPosition: startTime);
      }
      else {
        GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0, goToFirstPage: true);
        Video video = Video.fromJson(mediaItem: mediaItem);
        video.showPlayer(context, initialPosition: startTime);
      }
    }
    else if (uri.isDailyText) {
      final date = (uri.date == null || uri.date == 'today') ? DateTime.now() : DateTime.parse(uri.date!);

      List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(JwLifeSettings.instance.dailyTextLanguage.value, date: date);

      // Si Publication a un champ 'id' ou 'symbol' à tester
      Publication? dailyTextPub = dayPubs.firstWhereOrNull((p) => p.keySymbol.contains('es')); // ou p.symbol, p.title, etc.

      if (dailyTextPub == null) return;

      GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(0, goToFirstPage: true);
      showPageDailyText(dailyTextPub, date: date);
    }
    else if (uri.isMeetings) {
      final date = (uri.date == null) ? DateTime.now() : DateTime.parse(uri.date!);

      List<Publication> dayPubs = await CatalogDb.instance.getPublicationsForTheDay(JwLifeSettings.instance.dailyTextLanguage.value, date: date);

      refreshMeetingsPubs(pubs: dayPubs);
      GlobalKeyService.workShipKey.currentState!.refreshSelectedDay(date);

      GlobalKeyService.jwLifePageKey.currentState!.changeNavBarIndex(3, goToFirstPage: true);
    }
    else {
      // ouvrir le lien
      await launchUrl(Uri.parse(uri.toString()));
    }
  }
  catch (e) {
    print('Erreur parsing JwLifeUri: $e');
  }
}
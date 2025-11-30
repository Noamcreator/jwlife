import 'package:collection/collection.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/features/publication/pages/document/data/models/dated_text.dart';

import '../../app/jwlife_app.dart';
import '../../features/publication/pages/document/data/models/document.dart';
import '../models/userdata/note.dart';

class NotesController extends ChangeNotifier {
  BuildContext? context;
  List<Note> notes = [];

  String get formattedTimestamp => DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(DateTime.now().toUtc());

  Future<void> loadNotes() async {
    final fetched = await JwLifeApp.userdata.fetchNotes();

    // éviter doublons (si des notes ont déjà été chargées par document)
    final existingGuids = notes.map((e) => e.guid).toSet();
    final newOnes = fetched.where((n) => !existingGuids.contains(n.guid)).toList();

    if (newOnes.isNotEmpty) {
      notes.addAll(newOnes);
      notifyListeners();
    }
  }

  Future<Note> addNote({String? title, String? content, List<int>? tagsIds, int? styleIndex, int? colorIndex, int? blockType, int? identifier, Document? document, DatedText? datedText}) async {
    Note note = await JwLifeApp.userdata.addNote(
        title: title,
        content: content,
        tagsIds: tagsIds,
        styleIndex: styleIndex,
        colorIndex: colorIndex,
        document: document,
        blockType: blockType,
        identifier: identifier,
        datedText: datedText
    );

    // éviter doublon
    if (!notes.any((n) => n.guid == note.guid)) {
      notes = [...notes, note]; // immutable ajout
      notifyListeners();
    }

    return note;
  }

  Future<void> addNoteWithGuid(String guid, String title, String? userMarkGuid, int blockType, int identifier, int styleIndex, int colorIndex, {Document? document, DatedText? datedText}) async {
    Note note = await JwLifeApp.userdata.addNoteToDocId(
        guid,
        title,
        userMarkGuid,
        blockType,
        identifier,
        styleIndex,
        colorIndex,
        document: document,
        datedText: datedText
    );

    // éviter doublon
    if (!notes.any((n) => n.guid == note.guid)) {
      notes = [...notes, note]; // immutable ajout
      notifyListeners();
    }
  }

  Future<void> removeNote(String guid) async {
    await JwLifeApp.userdata.removeNoteWithGuid(guid);

    final before = notes.length;
    notes.removeWhere((n) => n.guid == guid);

    if (notes.length != before) notifyListeners();
  }

  Future<void> updateNote(String guid, String title, String content) async {
    await JwLifeApp.userdata.updateNoteWithGuid(guid, title, content);

    final index = notes.indexWhere((n) => n.guid == guid);
    if (index != -1) {
      notes[index] = notes[index].copyWith(title: title, content: content, lastModified: formattedTimestamp);
      notifyListeners();
    }
  }

  Future<void> changeNoteColor(String guid, int styleIndex, int colorIndex) async {
    await JwLifeApp.userdata.updateNoteColorWithGuid(guid, styleIndex, colorIndex);

    final index = notes.indexWhere((n) => n.guid == guid);
    if (index != -1) {
      notes[index] = notes[index].copyWith(colorIndex: colorIndex, lastModified: formattedTimestamp);
      notifyListeners();
    }
  }

  Future<void> changeNoteUserMark(String noteGuid, String userMarkGuid, int styleIndex, int colorIndex) async {
    await JwLifeApp.userdata.changeNoteUserMark(noteGuid, userMarkGuid);

    final index = notes.indexWhere((n) => n.guid == noteGuid);
    if (index != -1) {
      notes[index] = notes[index].copyWith(userMarkGuid: userMarkGuid, lastModified: formattedTimestamp);
      notifyListeners();
    }
  }

  Note? getNoteByGuid(String guid) {
    return notes.firstWhereOrNull((n) => n.guid == guid);
  }

  List<Note> getNotesByDocument({
    Document? document,
    DatedText? datedText,
    int? mepsDocumentId,
    String? keySymbol,
    int? mepsLanguageId,
    int? firstBookNumber,
    int? lastBookNumber,
    int? firstChapterNumber,
    int? lastChapterNumber,
    int? firstBlockIdentifier,
    int? lastBlockIdentifier,
  }) {
    // --- 1) CAS : Document fourni ---
    if (document != null) {
      final langId = document.mepsLanguageId;

      // Cas spécial Bible
      if (document.isBibleChapter()) {
        return notes.where((n) =>
        n.location.keySymbol == document.publication.keySymbol &&
            n.location.bookNumber == document.bookNumber &&
            n.location.chapterNumber == document.chapterNumberBible
        ).toList();
      }

      // Cas document normal
      return notes.where((n) =>
          n.location.mepsDocumentId == document.mepsDocumentId
      ).toList();
    }

    else if (datedText != null) {
      final langId = datedText.mepsLanguageId;

      // Cas document normal
      return notes.where((n) =>
          n.location.mepsDocumentId == datedText.mepsDocumentId
      ).toList();
    }

    // --- 2) CAS : Filtrage par plages (Bible ou publication découpée) ---
    final hasFullBibleRange = keySymbol != null &&
        firstBookNumber != null &&
            lastBookNumber != null &&
            firstChapterNumber != null &&
            lastChapterNumber != null &&
            firstBlockIdentifier != null &&
            lastBlockIdentifier != null;

    if (hasFullBibleRange) {
      return notes.where((n) {
        final symbol = n.location.keySymbol ?? "";
        final langId = n.location.mepsLanguageId ?? -1;
        final book = n.location.bookNumber ?? -1;
        final chapter = n.location.chapterNumber ?? -1;
        final block = n.blockIdentifier ?? -1;

        return symbol == keySymbol &&
            langId == mepsLanguageId &&
            book >= firstBookNumber &&
            book <= lastBookNumber &&
            chapter >= firstChapterNumber &&
            chapter <= lastChapterNumber &&
            block >= firstBlockIdentifier &&
            block <= lastBlockIdentifier;
      }).toList();
    }

    // --- 3) CAS : Filtrage par documentId + block identifier ---
    final hasDocBlockRange = mepsDocumentId != null;

    if (hasDocBlockRange) {
      return notes.where((n) {
        final block = n.blockIdentifier ?? -1;

        if(firstBlockIdentifier == null || lastBlockIdentifier == null) {
          return n.location.mepsDocumentId == mepsDocumentId;
        }
        return n.location.mepsDocumentId == mepsDocumentId && block >= firstBlockIdentifier && block <= lastBlockIdentifier;
      }).toList();
    }

    // Aucun filtre valide → renvoie vide
    return [];
  }

  List<Note> getNotesFromTagId(int tagId) {
    return notes.where((n) => n.tagsId.contains(tagId)).toList();
  }

  List<Note> getNotes({int? limit}) {
    // 1. Créer une copie (pour ne pas modifier l'original)
    final sortedNotes = notes.toList();

    // 2. Trier la copie (sort modifie en place et retourne void)
    sortedNotes.sort((a, b) => b.lastModified!.compareTo(a.lastModified!));

    // 3. Retourner les 'limit' premiers éléments
    return limit == null ? sortedNotes : sortedNotes.take(limit).toList();
  }

  Future<void> addTagIdToNote(String guid, int tagId) async {
    await JwLifeApp.userdata.addTagToNoteWithGuid(guid, tagId);
    final index = notes.indexWhere((n) => n.guid == guid);

    if (index != -1) {
      final n = notes[index];
      notes[index] = n.copyWith(tagsId: [...n.tagsId, tagId], lastModified: formattedTimestamp);
      notifyListeners();
    }
  }

  Future<void> removeTagIdFromNote(String guid, int tagId) async {
    await JwLifeApp.userdata.removeTagFromNoteWithGuid(guid, tagId);
    final index = notes.indexWhere((n) => n.guid == guid);

    if (index != -1) {
      final n = notes[index];
      notes[index] = n.copyWith(tagsId: n.tagsId.where((t) => t != tagId).toList());
      notifyListeners();
    }
  }

  void clearAll() {
    if (notes.isNotEmpty) {
      notes = [];
      notifyListeners();
    }
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) {
      return notes;
    }

    // 1. Enlever les diacritiques et mettre en minuscules pour la requête
    final processedQuery = removeDiacritics(query).toLowerCase();

    return notes.where((note) {
      // 2. Enlever les diacritiques et mettre en minuscules pour la note
      final title = note.title != null
          ? removeDiacritics(note.title!).toLowerCase()
          : '';
      final content = note.content != null
          ? removeDiacritics(note.content!).toLowerCase()
          : '';

      // 3. Effectuer la recherche
      return title.contains(processedQuery) || content.contains(processedQuery);
    }).toList();
  }
}

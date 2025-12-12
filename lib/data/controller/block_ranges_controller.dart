import 'package:flutter/material.dart';
import 'package:jwlife/data/models/userdata/block_range.dart';

import '../../app/jwlife_app.dart';
import '../../features/publication/pages/document/data/models/dated_text.dart';
import '../../features/publication/pages/document/data/models/document.dart';

class BlockRangesController extends ChangeNotifier {
  List<BlockRange> blockRanges = [];

  void loadBlockRanges(List<BlockRange> blockRangesToAddOrUpdate) {
    bool hasContentChanged = false;

    for(var range in blockRangesToAddOrUpdate) {
      if(!blockRanges.contains(range)) {
        blockRanges.add(range);
        hasContentChanged = true;
      }
    }

    if(hasContentChanged) {
      notifyListeners();
    }
  }

  Future<void> addBlockRanges(String userMarkGuid, int styleIndex, int colorIndex, List<dynamic> blockRangesParagraphs, {Document? document, DatedText? datedText}) async {
    List<BlockRange> newBlockRanges = await JwLifeApp.userdata.addBlockRanges(
      userMarkGuid,
      styleIndex,
      colorIndex,
      blockRangesParagraphs,
      document: document,
      datedText: datedText,
    );

    final Set<String> existingGuids = blockRanges.map((b) => b.userMarkGuid).toSet();

    final List<BlockRange> rangesToAdd = [];

    for (final blockRange in newBlockRanges) {
      if (!existingGuids.contains(blockRange.userMarkGuid)) {
        rangesToAdd.add(blockRange);
      }
    }

    if (rangesToAdd.isNotEmpty) {
      blockRanges = [...blockRanges, ...rangesToAdd];
      notifyListeners();
    }
  }

  Future<void> removeBlockRange(String userMarkGuid) async {
    await JwLifeApp.userdata.removeBlockRangeWithGuid(userMarkGuid);

    final before = blockRanges.length;
    blockRanges.removeWhere((b) => b.userMarkGuid == userMarkGuid);

    if (blockRanges.length != before) notifyListeners();
  }

  Future<void> changeBlockRangeStyle(String userMarkGuid, int styleIndex, int colorIndex) async {
    await JwLifeApp.userdata.changeBlockRangeStyleWithGuid(userMarkGuid, styleIndex, colorIndex);

    final index = blockRanges.indexWhere((n) => n.userMarkGuid == userMarkGuid);
    if (index != -1) {
      blockRanges[index] = blockRanges[index].copyWith(colorIndex: colorIndex, styleIndex: styleIndex);
      notifyListeners();
    }
  }

  List<BlockRange> getBlockRangesByDocument({Document? document, DatedText? datedText}) {
    if(document != null) {
      if(document.isBibleChapter()) {
        return blockRanges.where((n) => n.location.keySymbol == document.publication.keySymbol && n.location.mepsLanguageId == document.mepsLanguageId && n.location.bookNumber == document.bookNumber && n.location.chapterNumber == document.chapterNumberBible).toList();
      }
      else {
        return blockRanges.where((n) => n.location.mepsLanguageId == document.mepsLanguageId && n.location.mepsDocumentId == document.mepsDocumentId).toList();
      }
    }
    else if(datedText != null) {
      return blockRanges.where((n) => n.location.mepsLanguageId == datedText.mepsLanguageId && n.location.mepsDocumentId == datedText.mepsDocumentId).toList();
    }
    return [];
  }

  void clearAll() {
    if (blockRanges.isNotEmpty) {
      blockRanges = [];
      notifyListeners();
    }
  }
}

import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/publication/models/menu/local/tab_items.dart';
import 'package:jwlife/features/publication/models/menu/local/words_suggestions_model.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../core/utils/files_helper.dart';
import '../../../../../core/utils/utils_database.dart';
import '../../../../document/data/models/document.dart';
import '../../../../document/local/documents_manager.dart';
import 'menu_list_item.dart';

class PublicationMenuModel {
  final Publication publication;
  final List<TabWithItems> tabsWithItems = [];
  int initialTabIndex = 0;

  List<Map<String, dynamic>> suggestions = [];

  bool _multimediaExists = false;
  bool _documentMultimediaExists = false;
  bool _hasMultimediaColumns = false;
  bool _hasCommentaryColumn = false;

  late final Map<int, Document> _documentMap;
  // Cache pour les noms de livres bibliques pour un accès O(1)
  Map<int, Map<String, dynamic>> _bibleNamesMap = {};

  PublicationMenuModel(this.publication);

  Future<void> init() async {
    publication.documentsManager ??= DocumentsManager(publication: publication, mepsDocumentId: -1);
    await publication.documentsManager!.initializeDatabaseAndData();
    publication.wordsSuggestionsModel ??= WordsSuggestionsModel(publication);

    final db = publication.documentsManager!.database;

    // 1. Check metadata en parallèle une seule fois
    final results = await Future.wait([
      checkIfTableExists(db, 'Multimedia'),
      checkIfTableExists(db, 'DocumentMultimedia'),
      checkIfTableExists(db, 'BibleBook'),
    ]);

    _multimediaExists = results[0];
    _documentMultimediaExists = results[1];

    if (_multimediaExists) {
      final columns = await getColumnsForTable(db, 'Multimedia');
      _hasMultimediaColumns = columns.contains('CategoryType');
    }

    if (results[2]) {
      final bibleColumns = await getColumnsForTable(db, 'BibleBook');
      _hasCommentaryColumn = bibleColumns.contains('HasCommentary');
    }

    // 2. Préparation Map Documents O(1)
    _documentMap = {
      for (var doc in publication.documentsManager!.documents) doc.documentId: doc
    };

    // 3. Si c'est une Bible, on charge les noms MEPS en amont
    if (publication.isBible()) {
      await _preloadBibleNames();
    }

    await _fetchItems();
  }

  Future<void> _preloadBibleNames() async {
    final mepsFile = await getMepsUnitDatabaseFile();
    final mepsDatabase = await openReadOnlyDatabase(mepsFile.path);
    try {
      final List<Map<String, dynamic>> bookNames = await mepsDatabase.rawQuery('''
        SELECT bbn.BookNumber, bbn.StandardBookName, bbn.StandardBookAbbreviation, 
               bbn.OfficialBookAbbreviation, bbg.GroupId
        FROM BibleBookName bbn
        JOIN BibleCluesInfo bci ON bbn.BibleCluesInfoId = bci.BibleCluesInfoId
        JOIN BibleBookGroup bbg ON bbn.BookNumber = bbg.BookNumber
        WHERE bci.LanguageId = ?;
      ''', [publication.mepsLanguage.id]);

      _bibleNamesMap = {for (var b in bookNames) b['BookNumber'] as int: b};
    }
    finally {
      await mepsDatabase.close();
    }
  }

  Future<void> _fetchItems() async {
    try {
      final db = publication.documentsManager!.database;

      // Récupération des onglets
      final List<Map<String, dynamic>> tabs = await db.rawQuery('''
        SELECT pvi.PublicationViewItemId, pvi.Title,
               COALESCE(CASE WHEN pvi.ChildTemplateSchemaType != pvi.SchemaType THEN cvs.DataType END, vs.DataType) AS DataType
        FROM PublicationView pv
        INNER JOIN PublicationViewItem pvi ON pvi.PublicationViewId = pv.PublicationViewId AND pvi.ParentPublicationViewItemId = -1
        LEFT JOIN (SELECT SchemaType, MIN(DataType) AS DataType FROM PublicationViewSchema GROUP BY SchemaType) vs ON pvi.SchemaType = vs.SchemaType
        LEFT JOIN (SELECT SchemaType, MIN(DataType) AS DataType FROM PublicationViewSchema GROUP BY SchemaType) cvs ON pvi.ChildTemplateSchemaType = cvs.SchemaType
        WHERE pv.Symbol = 'jwpub';
      ''');

      // Récupération de TOUS les items de tous les onglets en une seule passe si possible
      final allResults = await Future.wait(
          tabs.map((tab) => _getItemsForParent(tab['PublicationViewItemId'] as int))
      );

      for (int i = 0; i < tabs.length; i++) {
        final items = allResults[i];
        final List<ListItem> itemList = [];

        // Lookup rapide pour les parents
        final itemIds = {for (var item in items) item['PublicationViewItemId'] as int};

        for (final item in items) {
          final parentId = item['ParentPublicationViewItemId'] as int;

          // On ne traite que les racines de l'onglet (ceux dont le parent n'est pas dans la liste courante)
          if (!itemIds.contains(parentId)) {
            if (item['DefaultDocumentId'] == -1) {
              final currentId = item['PublicationViewItemId'] as int;
              final subItemsRaw = items.where((s) => s['ParentPublicationViewItemId'] == currentId);

              bool isBibleBooks = false;
              final List<ListItem> subList = [];

              for (var s in subItemsRaw) {
                if (s['Type'] == 2) isBibleBooks = true;
                subList.add(_mapToListItem(s, false));
              }

              if (isBibleBooks && initialTabIndex == 0) initialTabIndex = i;

              itemList.add(ListItem(
                publicationViewItemId: item['PublicationViewItemId'],
                parentPublicationViewItemId: item['ParentPublicationViewItemId'],
                title: item['DisplayTitle'] as String,
                isTitle: true,
                isBibleBooks: isBibleBooks,
                showImage: false,
                subItems: subList,
              ));
            }
            else {
              final hasImage = items.any((s) => s['FilePath'] != null);
              itemList.add(_mapToListItem(item, hasImage));
            }
          }
        }
        tabsWithItems.add(TabWithItems(tab: tabs[i], items: itemList));
      }
    } catch (e) {
      throw Exception('PublicationMenuModel._fetchItems: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getItemsForParent(int parentId) async {
    final useMultimedia = _documentMultimediaExists && _multimediaExists && _hasMultimediaColumns;
    final isBible = publication.isBible();

    final sql = '''
      SELECT pvi.PublicationViewItemId, pvi.ParentPublicationViewItemId, pvi.Title AS DisplayTitle,
             pvi.DefaultDocumentId, pvs.DataType
             ${isBible ? ', d.Type, bb.BibleBookId' : ''}
             ${isBible && _hasCommentaryColumn ? ', bb.HasCommentary' : ''}
             ${useMultimedia ? ', MAX(CASE WHEN m.CategoryType = 9 THEN m.FilePath END) AS FilePath' : ', NULL AS FilePath'}
      FROM PublicationViewItem pvi
      INNER JOIN PublicationViewSchema pvs ON pvi.SchemaType = pvs.SchemaType
      ${_documentMultimediaExists ? 'LEFT JOIN DocumentMultimedia dm ON dm.DocumentId = pvi.DefaultDocumentId' : ''}
      ${useMultimedia ? 'LEFT JOIN Multimedia m ON dm.MultimediaId = m.MultimediaId' : ''}
      ${isBible ? 'LEFT JOIN Document d ON d.DocumentId = pvi.DefaultDocumentId' : ''}
      ${isBible ? 'LEFT JOIN BibleBook bb ON d.Type = 2 AND bb.BookDocumentId = d.DocumentId' : ''}
      LEFT JOIN PublicationViewItem pvx ON pvx.PublicationViewItemId = pvi.ParentPublicationViewItemId 
                AND pvx.ParentPublicationViewItemId = ? AND pvx.DefaultDocumentId = -1
      WHERE pvi.ParentPublicationViewItemId = ? OR pvx.PublicationViewItemId IS NOT NULL
      GROUP BY pvi.PublicationViewItemId;
    ''';

    return await publication.documentsManager!.database.rawQuery(sql, [parentId, parentId]);
  }

  ListItem _mapToListItem(Map<String, dynamic> item, bool showIMage) {
    final docId = item['DefaultDocumentId'] as int;
    final doc = _documentMap[docId];

    if (doc == null) return ListItem(title: '', isTitle: false);

    String title = item['DisplayTitle']?.trim() ?? '';
    String medTitle = '';
    String largeTitle = '';
    int groupId = -1;
    bool hasCommentary = false;

    if (publication.isBible() && item['Type'] == 2) {
      final bibleData = _bibleNamesMap[item['BibleBookId']];
      if (bibleData != null) {
        title = bibleData['OfficialBookAbbreviation'] ?? '';
        medTitle = bibleData['StandardBookAbbreviation'] ?? '';
        largeTitle = bibleData['StandardBookName'] ?? '';
        groupId = bibleData['GroupId'] ?? -1;
      }
      hasCommentary = (item['HasCommentary'] ?? 0) == 1;
    }

    return ListItem(
      publicationViewItemId: item['PublicationViewItemId'],
      parentPublicationViewItemId: item['ParentPublicationViewItemId'],
      title: title,
      mediumTitle: medTitle,
      largeTitle: largeTitle,
      displayTitle: item['DisplayTitle'] ?? '',
      subTitle: doc.contextTitle ?? doc.featureTitle ?? '',
      imageFilePath: item['FilePath'] ?? '',
      dataType: item['DataType'] ?? '',
      groupId: groupId,
      hasCommentary: hasCommentary,
      bibleBookId: item['BibleBookId'] ?? -1,
      mepsDocumentId: doc.mepsDocumentId,
      isTitle: false,
      showImage: showIMage || item['FilePath'] != null,
    );
  }

  Future<void> initAudio() async => await publication.fetchAudios();
}
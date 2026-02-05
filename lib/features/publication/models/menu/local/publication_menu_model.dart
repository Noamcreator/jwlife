import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/features/publication/models/menu/local/tab_items.dart';
import 'package:jwlife/features/publication/models/menu/local/words_suggestions_model.dart';

import '../../../../../core/utils/files_helper.dart';
import '../../../../../core/utils/utils_database.dart';
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
  bool _hasContextTitleColumn = false;
  bool _hasFeatureTitleColumn = false;
  bool _hasDocumentMetadataTable = false;

  PublicationMenuModel(this.publication);

  Future<void> init() async {
    publication.documentsManager ??= DocumentsManager(publication: publication);

    await publication.documentsManager!.initializeDatabaseAndData(fromMenu: true);

    final db = publication.documentsManager!.database;

    final results = await Future.wait([
      checkIfTableExists(db, 'Multimedia'),
      checkIfTableExists(db, 'DocumentMultimedia'),
      checkIfTableExists(db, 'BibleBook'),
      checkIfTableExists(db, 'DocumentMetadata'),
    ]);

    _multimediaExists = results[0];
    _documentMultimediaExists = results[1];

    if (_multimediaExists) {
      _hasMultimediaColumns = await checkIfColumnsExists(db, 'Multimedia', ['CategoryType']);
    }

    _hasContextTitleColumn = await checkIfColumnsExists(db, 'Document', ['ContextTitle']);
    _hasFeatureTitleColumn = await checkIfColumnsExists(db, 'Document', ['FeatureTitle']);

    if (results[2]) {
      final bibleColumns = await getColumnsForTable(db, 'BibleBook');
      _hasCommentaryColumn = bibleColumns.contains('HasCommentary');
    }
    
    _hasDocumentMetadataTable = results[3];

    await _fetchItems();

    if(publication.isBible()) {
      publication.documentsManager!.initializeBibleDocuments();
    }
  }

  Future<void> _fetchItems() async {
    try {
      final db = publication.documentsManager!.database;

      final List<Map<String, dynamic>> tabs = await db.rawQuery('''
        SELECT pvi.PublicationViewItemId, pvi.Title,
               COALESCE(CASE WHEN pvi.ChildTemplateSchemaType != pvi.SchemaType THEN cvs.DataType END, vs.DataType) AS DataType
        FROM PublicationView pv
        INNER JOIN PublicationViewItem pvi ON pvi.PublicationViewId = pv.PublicationViewId AND pvi.ParentPublicationViewItemId = -1
        LEFT JOIN (SELECT SchemaType, MIN(DataType) AS DataType FROM PublicationViewSchema GROUP BY SchemaType) vs ON pvi.SchemaType = vs.SchemaType
        LEFT JOIN (SELECT SchemaType, MIN(DataType) AS DataType FROM PublicationViewSchema GROUP BY SchemaType) cvs ON pvi.ChildTemplateSchemaType = cvs.SchemaType
        WHERE pv.Symbol = 'jwpub';
      ''');

      for (int i = 0; i < tabs.length; i++) {
        final parentId = tabs[i]['PublicationViewItemId'] as int;
        List<Map<String, dynamic>> rawItems;

        bool isBibleTab = false;
        if (publication.isBible()) {
          final check = await db.rawQuery('''
            SELECT 1 FROM PublicationViewItem pvi 
            INNER JOIN Document d ON d.DocumentId = pvi.DefaultDocumentId
            WHERE d.Type = 2 AND (
              pvi.ParentPublicationViewItemId = ? 
              OR pvi.ParentPublicationViewItemId IN (SELECT PublicationViewItemId FROM PublicationViewItem WHERE ParentPublicationViewItemId = ?)
            ) LIMIT 1
          ''', [parentId, parentId]);
          isBibleTab = check.isNotEmpty;
        }

        if (isBibleTab) {
          rawItems = await _getItemsForBible(parentId);
        } else {
          rawItems = await _getItemsForStandardPublication(parentId);
        }

        final List<ListItem> itemList = [];
        final itemIds = {for (var item in rawItems) item['PublicationViewItemId'] as int?};

        for (final item in rawItems) {
          final pId = item['ParentPublicationViewItemId'] as int?;
          final hasImage = rawItems.any((s) => s['FilePath'] != null);

          // On traite les éléments racines de l'onglet (ceux dont le parent n'est pas dans la liste)
          if (!itemIds.contains(pId)) {
            // Si c'est un titre de section (ex: Hébraïques) ou un conteneur sans document
            if (item['MepsDocumentId'] == null && item['BookNumber'] == null) {
              final currentId = item['PublicationViewItemId'] as int;
              final subItemsRaw = rawItems.where((s) => s['ParentPublicationViewItemId'] == currentId).toList();
              bool containsBibleBooks = false;
              final List<ListItem> subList = [];

              for (var s in subItemsRaw) {
                if (s['BookNumber'] != null) containsBibleBooks = true;
                final showImage = subItemsRaw.any((s) => s['FilePath'] != null);
                subList.add(_mapToListItem(s, showImage));
              }

              if (containsBibleBooks) initialTabIndex = i;

              itemList.add(ListItem(
                title: (item['DisplayTitle'] ?? item['Title'] ?? '') as String,
                isTitle: true,
                isBibleBooks: containsBibleBooks,
                showImage: false,
                subItems: subList,
              ));
            } 
            else {
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

  Future<List<Map<String, dynamic>>> _getItemsForStandardPublication(int parentId) async {
    final useMultimedia = _documentMultimediaExists && _multimediaExists && _hasMultimediaColumns;
    final db = publication.documentsManager!.database;

    return await db.rawQuery('''
      SELECT pvi.PublicationViewItemId, pvi.ParentPublicationViewItemId, pvi.Title, 
             d.Title AS DisplayTitle, d.MepsDocumentId, pvs.DataType,
             ${_hasContextTitleColumn ? 'd.ContextTitle AS ContextTitle,' : ''} 
             ${_hasFeatureTitleColumn ? 'd.FeatureTitle AS FeatureTitle,' : ''}
             pvs.DataType
             ${_hasDocumentMetadataTable ? ', dmd.Value AS Description' : ', NULL AS Description'}
             ${useMultimedia ? ', MAX(CASE WHEN m.CategoryType = 9 THEN m.FilePath END) AS FilePath' : ', NULL AS FilePath'}
      FROM PublicationViewItem pvi
      INNER JOIN PublicationViewSchema pvs ON pvi.SchemaType = pvs.SchemaType
      LEFT JOIN Document d ON d.DocumentId = pvi.DefaultDocumentId
      ${_documentMultimediaExists ? 'LEFT JOIN DocumentMultimedia dm ON dm.DocumentId = pvi.DefaultDocumentId' : ''}
      ${useMultimedia ? 'LEFT JOIN Multimedia m ON dm.MultimediaId = m.MultimediaId' : ''}
      LEFT JOIN PublicationViewItem pvx ON pvx.PublicationViewItemId = pvi.ParentPublicationViewItemId AND pvx.ParentPublicationViewItemId = ? AND pvx.DefaultDocumentId = -1
      ${_hasDocumentMetadataTable ? 'LEFT JOIN DocumentMetadata dmd ON dmd.DocumentId = d.DocumentId AND dmd.MetadataKey = \'WEB:OnSiteAdDescription\'' : ''}
      WHERE pvi.ParentPublicationViewItemId = ? OR pvx.PublicationViewItemId IS NOT NULL
      GROUP BY pvi.PublicationViewItemId;
    ''', [parentId, parentId]);
  }

  Future<List<Map<String, dynamic>>> _getItemsForBible(int parentId) async {
    final db = publication.documentsManager!.database;
    final mepsFile = await getMepsUnitDatabaseFile();
    
    await attachDatabases(db, {'meps': mepsFile.path});

    try {
      return await db.rawQuery('''
        -- 1. On pré-calcule les IDs des sections en utilisant les métadonnées MEPS
        WITH Metadata AS (
            SELECT 
                bi.FirstBookOfGreekScripturesNumber,
                bi.Name AS BibleName
            FROM meps.BibleInfo bi
            INNER JOIN BiblePublication bp ON bp.BibleVersion = bi.Name
            WHERE bp.BiblePublicationId = 1 
            LIMIT 1
        ),
        SectionsInfo AS (
            SELECT 
                item.PublicationViewItemId,
                (SELECT MIN(bb_sub.BibleBookId) 
                FROM BibleBook bb_sub 
                JOIN Document d_sub ON d_sub.DocumentId = bb_sub.BookDocumentId
                JOIN PublicationViewItem pvi_sub ON pvi_sub.DefaultDocumentId = d_sub.DocumentId
                WHERE pvi_sub.ParentPublicationViewItemId = item.PublicationViewItemId) as MinBookId
            FROM PublicationViewItem item
            CROSS JOIN Metadata
            WHERE item.ParentPublicationViewItemId = ?
        ),
        Map AS (
            SELECT
                (SELECT PublicationViewItemId FROM SectionsInfo 
                WHERE MinBookId < (SELECT FirstBookOfGreekScripturesNumber FROM Metadata) LIMIT 1) AS HebSectionId,
                (SELECT PublicationViewItemId FROM SectionsInfo 
                WHERE MinBookId >= (SELECT FirstBookOfGreekScripturesNumber FROM Metadata) LIMIT 1) AS GreSectionId
        )

        -- Requête finale
        SELECT 
            p.PublicationViewItemId, 
            p.ParentPublicationViewItemId, 
            p.Title, 
            NULL AS BookNumber, 
            NULL AS MedTitle, 
            NULL AS LargeTitle, 
            NULL AS GroupId, 
            NULL AS HasCommentary,
            NULL AS isBookExist
        FROM PublicationViewItem p
        WHERE p.ParentPublicationViewItemId = ?

        UNION ALL

        SELECT 
            pvi.PublicationViewItemId, 
            CASE 
                WHEN bbn.BookNumber < (SELECT FirstBookOfGreekScripturesNumber FROM Metadata) THEN Map.HebSectionId
                ELSE Map.GreSectionId
            END AS ParentPublicationViewItemId,
            bbn.OfficialBookAbbreviation AS Title,
            bbn.BookNumber,
            bbn.StandardBookAbbreviation AS MedTitle,
            bbn.StandardBookName AS LargeTitle,
            bbg.GroupId,
            ${_hasCommentaryColumn ? 'bb.HasCommentary' : '0'} AS HasCommentary,
            MAX(CASE WHEN bb.BibleBookId IS NOT NULL THEN 1 ELSE 0 END) AS isBookExist
        FROM meps.BibleBookName bbn
        CROSS JOIN Map
        CROSS JOIN Metadata
        INNER JOIN meps.BibleCluesInfo bci ON bbn.BibleCluesInfoId = bci.BibleCluesInfoId
        INNER JOIN meps.BibleInfo bi ON bci.BibleInfoId = bi.BibleInfoId AND bi.Name = Metadata.BibleName
        INNER JOIN meps.BibleBookGroup bbg ON bbn.BookNumber = bbg.BookNumber
        LEFT JOIN BibleBook bb ON bb.BibleBookId = bbn.BookNumber
        LEFT JOIN Document d ON d.DocumentId = bb.BookDocumentId
        LEFT JOIN PublicationViewItem pvi ON pvi.DefaultDocumentId = d.DocumentId
        WHERE bci.LanguageId = ?
        GROUP BY bbn.BookNumber
        ORDER BY BookNumber ASC;
      ''', [parentId, parentId, publication.mepsLanguage.id]);
    } finally {
      await detachDatabases(db, ['meps']);
    }
  }

  ListItem _mapToListItem(Map<String, dynamic> item, bool showImageContainer) {
    return ListItem(
      title: (item['Title'] ?? '').toString().trim(),
      subTitle: (item['ContextTitle'] ?? item['FeatureTitle'] ?? '').toString().trim(),
      mediumTitle: (item['MedTitle'] ?? '').toString().trim(),
      largeTitle: (item['LargeTitle'] ?? '').toString().trim(),
      displayTitle: item['DisplayTitle'] ?? '',
      imageFilePath: item['FilePath'] ?? '',
      description: item['Description'] ?? '',
      dataType: item['DataType'] ?? 'name',
      groupId: item['GroupId'],
      hasCommentary: (item['HasCommentary'] ?? 0) == 1,
      bibleBookNumber: item['BookNumber'],
      mepsDocumentId: item['MepsDocumentId'] ?? -1,
      isTitle: false,
      showImage: showImageContainer || item['FilePath'] != null,
      isBookExist: item['isBookExist'] == 1,
    );
  }

  Future<void> initAudio() async => await publication.fetchAudios();
}
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/files_helper.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_publication.dart';
import 'package:jwlife/widgets/dialog/language_dialog.dart';
import 'package:jwlife/widgets/image_widget.dart';
import 'package:sqflite/sqflite.dart';

class PublicationsItemsView extends StatefulWidget {
  final Map<String, dynamic> category;
  final String year;

  PublicationsItemsView({Key? key, required this.category, this.year=''}) : super(key: key);

  @override
  _PublicationsItemsViewState createState() => _PublicationsItemsViewState();
}

class _PublicationsItemsViewState extends State<PublicationsItemsView> {
  String categoryName = '';
  String language = '';
  List<Map<String, dynamic>> groupedPublications = [];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  void loadItems() async {
    String langVernacular = JwLifeApp.currentLanguage.vernacular;
    int mepsLanguageId =JwLifeApp.currentLanguage.id;

    File catalogFile = await getCatalogFile();
    File mepsFile = await getMepsFile();
    File pubCollectionsFile = await getPubCollectionsFile();
    File userdataFile = await getUserdataFile();

    if (await catalogFile.exists() && await mepsFile.exists()) {
      Database catalog = await openReadOnlyDatabase(catalogFile.path);
      await catalog.execute("ATTACH DATABASE '${mepsFile.path}' AS meps");
      await catalog.execute("ATTACH DATABASE '${pubCollectionsFile.path}' AS pub_collections");
      await catalog.execute("ATTACH DATABASE '${userdataFile.path}' AS userdata");

      List<Map<String, dynamic>> result = [];
      if (widget.year == '') {
        result = await catalog.rawQuery(''' 
    SELECT DISTINCT
    p.Id AS PublicationId,
    p.MepsLanguageId,
    meps.Language.Symbol AS LanguageSymbol,
    meps.Language.VernacularName AS LanguageVernacularName,
    meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
    p.PublicationTypeId,
    p.IssueTagNumber,
    p.Title,
    p.IssueTitle,
    p.ShortTitle,
    p.CoverTitle,
    p.KeySymbol,
    p.Symbol,
    p.Year,
    pam.PublicationAttributeId,
    pa.CatalogedOn,
    pa.ExpandedSize,
    (SELECT ia.NameFragment
        FROM ImageAsset ia
        JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
        WHERE paim.PublicationAssetId = pa.Id 
        AND (ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600))
        ORDER BY ia.Width DESC
        LIMIT 1) AS ImageSqr,
    (SELECT ia.NameFragment
        FROM ImageAsset ia
        JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
        WHERE paim.PublicationAssetId = pa.Id 
        AND ia.NameFragment LIKE '%_lsr-%'
        ORDER BY ia.Width DESC
        LIMIT 1) AS ImageLsr,
    (SELECT CASE WHEN COUNT(pc.Symbol) > 0 THEN 1 ELSE 0 END
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId) AS isDownload,
    (SELECT pc.Path
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Path,
    (SELECT pc.DatabasePath
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS DatabasePath,
    (SELECT pc.Hash
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Hash,    
    (SELECT CASE WHEN COUNT(tg.TagMapId) > 0 THEN 1 ELSE 0 END
        FROM userdata.TagMap tg
        JOIN userdata.Location ON tg.LocationId = userdata.Location.LocationId
        WHERE userdata.Location.IssueTagNumber = p.IssueTagNumber 
        AND userdata.Location.KeySymbol = p.KeySymbol 
        AND userdata.Location.MepsLanguage = p.MepsLanguageId 
        AND tg.TagId = 1) AS isFavorite
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
      p.MepsLanguageId = ? AND p.PublicationTypeId = ?
    ORDER BY pam.PublicationAttributeId
    ''', [mepsLanguageId, widget.category['id']]);
      }
      else {
        result = await catalog.rawQuery(''' 
    SELECT DISTINCT
    p.Id AS PublicationId,
    p.MepsLanguageId,
    meps.Language.Symbol AS LanguageSymbol,
    meps.Language.VernacularName AS LanguageVernacularName,
    meps.Language.PrimaryIetfCode AS LanguagePrimaryIetfCode,
    p.PublicationTypeId,
    p.IssueTagNumber,
    p.Title,
    p.IssueTitle,
    p.ShortTitle,
    p.CoverTitle,
    p.KeySymbol,
    p.Symbol,
    p.Year,
    pam.PublicationAttributeId,
    pa.CatalogedOn,
    pa.ExpandedSize,
    (SELECT ia.NameFragment
        FROM ImageAsset ia
        JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
        WHERE paim.PublicationAssetId = pa.Id 
        AND (ia.NameFragment LIKE '%_sqr-%' OR (ia.Width = 600 AND ia.Height = 600))
        ORDER BY ia.Width DESC
        LIMIT 1) AS ImageSqr,
    (SELECT ia.NameFragment
        FROM ImageAsset ia
        JOIN PublicationAssetImageMap paim ON ia.Id = paim.ImageAssetId
        WHERE paim.PublicationAssetId = pa.Id 
        AND ia.NameFragment LIKE '%_lsr-%'
        ORDER BY ia.Width DESC
        LIMIT 1) AS ImageLsr,
    (SELECT CASE WHEN COUNT(pc.Symbol) > 0 THEN 1 ELSE 0 END
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId) AS isDownload,
    (SELECT pc.Path
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Path,
    (SELECT pc.DatabasePath
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS DatabasePath,
    (SELECT pc.Hash
        FROM pub_collections.Publication pc
        WHERE p.Symbol = pc.Symbol AND p.IssueTagNumber = pc.IssueTagNumber AND p.MepsLanguageId = pc.MepsLanguageId
        LIMIT 1) AS Hash,    
    (SELECT CASE WHEN COUNT(tg.TagMapId) > 0 THEN 1 ELSE 0 END
        FROM userdata.TagMap tg
        JOIN userdata.Location ON tg.LocationId = userdata.Location.LocationId
        WHERE userdata.Location.IssueTagNumber = p.IssueTagNumber 
        AND userdata.Location.KeySymbol = p.KeySymbol 
        AND userdata.Location.MepsLanguage = p.MepsLanguageId 
        AND tg.TagId = 1) AS isFavorite
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
      p.MepsLanguageId = ? AND p.PublicationTypeId = ? AND p.Year = ?
    ORDER BY p.Title
    ''', [mepsLanguageId, widget.category['id'], widget.year]);
      }

      await catalog.execute("DETACH DATABASE userdata");
      await catalog.execute("DETACH DATABASE pub_collections");
      await catalog.execute("DETACH DATABASE meps");
      await catalog.close();

      // Mettre à jour l'état avec le mappage trié
      setState(() {
        categoryName = widget.category['name'];
        language = langVernacular;
        groupedPublications = result.map((item) => Map<String, dynamic>.from(item)).toList();;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grouper les publications par PublicationAttributeId
    Map<int, List<Map<String, dynamic>>> groupedByCategory = {};
    for (var publication in groupedPublications) {
      int attributeId = publication['PublicationAttributeId'] ?? -1;
      groupedByCategory.putIfAbsent(attributeId, () => []).add(publication);
    }

    // Styles partagés
    final textStyleTitle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final textStyleSubtitle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFc3c3c3)
          : const Color(0xFF626262),
    );

    final boxDecoration = BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF292929)
          : Colors.white,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName, style: textStyleTitle),
            Text(language, style: textStyleSubtitle),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => const LanguageDialog(),
              ).then((_) => loadItems());
            },
          ),
        ],
      ),
      body: ListView.builder(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
        itemCount: groupedByCategory.length,
        itemBuilder: (context, index) {
          var entry = groupedByCategory.entries.elementAt(index);
          int attributeId = entry.key;
          List<Map<String, dynamic>> publications = entry.value;

          // Créez une liste de widgets pour chaque section
          List<Widget> sectionWidgets = [];

          // Si l'attribut existe, ajoutez son titre
          if (attributeId != -1) {
            sectionWidgets.add(
              Text(
                attributes[attributeId]?['name'] ?? '',
                style: textStyleTitle,
              ),
            );
            sectionWidgets.add(const SizedBox(height: 5));
          }

          // Ajoutez les publications sous cette section
          sectionWidgets.addAll(publications.map((publication) {
            return GestureDetector(
              onTap: () {
                showPublicationMenu(context, publication);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 1.0),
                decoration: boxDecoration,
                child: _buildCategoryButton(context, publication),
              ),
            );
          }).toList());

          // Ajout d'un espacement après les publications
          sectionWidgets.add(const SizedBox(height: 30));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sectionWidgets,
          );
        },
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, Map<String, dynamic> publication) {
    var imageSqr = publication['ImageSqr'] ?? '';
    var title = publication['Title'] ?? '';
    var issueTitle = publication['IssueTitle'] ?? '';
    var coverTitle = publication['CoverTitle'] ?? '';
    var year = publication['Year'] ?? '';

    // Construire l'URL de l'image
    String imageUrl = '';
    if (imageSqr.isNotEmpty) {
      imageUrl = 'https://app.jw-cdn.org/catalogs/publications/$imageSqr';
    }

    return SizedBox(
      height: 85,
      child: Stack(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: ImageCachedWidget(
                    imageUrl: imageUrl,
                    pathNoImage: widget.category['image'],
                    height: 85,
                    width: 85
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10.0, right: 20.0, top: 4.0, bottom: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (issueTitle.isNotEmpty)
                        Text(
                          issueTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFc3c3c3)
                                : const Color(0xFF626262),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (coverTitle.isNotEmpty)
                        Text(
                          coverTitle,
                          style: TextStyle(
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (issueTitle.isEmpty && coverTitle.isEmpty)
                        Text(
                          title,
                          style: TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Spacer(),
                      Text(
                        '$year - ${publication['Symbol']}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFc3c3c3)
                            : const Color(0xFF626262),
                        ),
                      ),
                      publication['inProgress'] != null ? const Spacer() : Container(),
                      publication['inProgress'] != null
                          ? publication['inProgress'] == -1 ? LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)):
                      LinearProgressIndicator(
                          value: publication['inProgress'],
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                          color: Theme.of(context).primaryColor) : Container()
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: -5,
            right: -10,
            child: PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Theme.of(context).brightness == Brightness.dark ?
              const Color(0xFFc3c3c3)
                  : const Color(0xFF626262),
              ),
              itemBuilder: (BuildContext context) {
                return [
                  getPubShareMenuItem(publication),
                  getPubLanguagesItem(context, "Autres langues", publication),
                  getPubFavoriteItem(publication),
                  getPubDownloadItem(context, publication, update: () {
                    setState(() {});
                  }),
                ];
              },
            ),
          ),
          publication['isDownload'] == 0 && publication['inProgress'] == null ? Positioned(
            bottom: 5,
            right: -8,
            height: 40,
            child: IconButton(
              padding: const EdgeInsets.all(0),
              onPressed: () {
                downloadPublication(context, publication, update: () {
                  setState(() {});
                });
              },
              icon: Icon(JwIcons.cloud_arrow_down, color: Color(0xFF9d9d9d)),
            ),
          ): Container(),
          publication['isDownload'] == 0 && publication['inProgress'] == null ? Positioned(
              bottom: 0,
              right: -5,
              width: 50,
              child: Text(
                textAlign: TextAlign.center,
                formatFileSize(publication['ExpandedSize']),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFc3c3c3)
                      : const Color(0xFF626262),
                ),
              )
          ) : Container(),
        ],
      ),
    );
  }
}

// La définition de votre map d'attributs reste inchangée.
Map<int, Map<String, dynamic>> attributes = {
  0: {'key': 'null', 'name': ''},
  32: {'key': 'archive', 'name': 'PUBLICATIONS PLUS ANCIENNES'},
  1: {'key': 'assembly_convention', 'name': 'ASSEMBLÉE RÉGIONALE ET DE CIRCONSCRIPTION'},
  29: {'key': 'bethel', 'name': 'BÉTHEL'},
  2: {'key': 'circuit_assembly', 'name': 'ASSEMBLÉE DE CIRCONSCRIPTION'},
  30: {'key': 'circuit_overseer', 'name': 'RESPONSABLE DE CIRCONSCRIPTION'},
  31: {'key': 'congregation', 'name': 'ASSEMBLÉE LOCALE'},
  33: {'key': 'congregation_circuit_overseer', 'name': 'ASSEMBLÉE LOCALE ET RESPONSABLE DE CIRCONSCRIPTION'},
  3: {'key': 'convention', 'name': 'ASSEMBLÉE RÉGIONALE'},
  9: {'key': 'convention_invitation', 'name': 'INVITATIONS À L\'ASSEMBLÉE RÉGIONALE'},
  49: {'key': 'design_construction', 'name': 'DÉVELOPPEMENT-CONSTRUCTION'},
  4: {'key': 'drama', 'name': 'REPRÉSENTATIONS THÉÂTRALES'},
  5: {'key': 'dramatic_bible_reading', 'name': 'LECTURES BIBLIQUES THÉÂTRALES'},
  7: {'key': 'examining_the_scriptures', 'name': 'EXAMINONS LES ÉCRITURES'},
  50: {'key': 'financial', 'name': 'COMPTABILITÉ'},
  41: {'key': 'invitation', 'name': 'INVITATIONS'},
  10: {'key': 'kingdom_news', 'name': 'NOUVELLES DU ROYAUME'},
  51: {'key': 'medical', 'name': 'MÉDICAL'},
  57: {'key': 'meetings', 'name': 'RÉUNIONS'},
  52: {'key': 'ministry', 'name': 'MINISTÈRE'},
  12: {'key': 'music', 'name': 'MUSIQUE'},
  16: {'key': 'public', 'name': 'ÉDITION PUBLIQUE'},
  53: {'key': 'purchasing', 'name': 'ACHATS'},
  54: {'key': 'safety', 'name': 'SÉCURITÉ'},
  55: {'key': 'schools', 'name': 'ÉCOLES'},
  27: {'key': 'simplified', 'name': 'VERSION FACILE'},
  22: {'key': 'study', 'name': 'ÉDITION D’ÉTUDE'},
  28: {'key': 'study_questions', 'name': 'QUESTIONS D\'ÉTUDE'},
  21: {'key': 'study_simplified', 'name': 'ÉDITION D’ÉTUDE (FACILE)'},
  24: {'key': 'vocal_rendition', 'name': 'VERSION CHANTÉE'},
  56: {'key': 'writing_translation', 'name': 'RÉDACTION / TRADUCTION'},
  26: {'key': 'yearbook', 'name': 'ANNUAIRES ET RAPPORTS DES ANNÉES DE SERVICE'}
};

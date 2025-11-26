import 'package:flutter/material.dart';
import 'package:jwlife/data/controller/tags_controller.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import 'package:diacritic/diacritic.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils_document.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/userdata/note.dart';
import '../../../data/models/userdata/tag.dart';
import '../../../data/repositories/PublicationRepository.dart';
import '../../../widgets/image_cached_widget.dart';
import '../pages/note_page.dart';
import '../pages/tag_page.dart';

class NoteItemWidget extends StatefulWidget {
  final Note note;
  final Tag? tag;
  final VoidCallback? onUpdated;
  final bool fullNote;
  final String? highlightQuery;

  const NoteItemWidget({
    super.key,
    required this.note,
    required this.tag,
    this.onUpdated,
    this.fullNote = false,
    this.highlightQuery,
  });

  /// 🔥 Cache global : chaque note résout ses dépendances UNE SEULE FOIS
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Résolution des dépendances + mise en cache
  static Future<Map<String, dynamic>> resolveDependenciesCached(Note note) async {
    if (_cache.containsKey(note.guid)) {
      return _cache[note.guid]!;
    }

    String? keySymbol = note.location.keySymbol;
    int? issueTagNumber = note.location.issueTagNumber;
    int? mepsLanguageId = note.location.mepsLanguageId;

    if (keySymbol == null || issueTagNumber == null || mepsLanguageId == null) {
      _cache[note.guid] = {'pub': null, 'docTitle': ''};
      return _cache[note.guid]!;
    }

    Publication? pub = PublicationRepository()
        .getAllPublications()
        .firstWhereOrNull((p) =>
    p.keySymbol == keySymbol &&
        p.issueTagNumber == issueTagNumber &&
        p.mepsLanguage.id == mepsLanguageId);

    String docTitle = '';

    pub ??= await CatalogDb.instance
        .searchPubNoMepsLanguage(keySymbol, issueTagNumber, mepsLanguageId);

    if (pub != null && pub.isDownloadedNotifier.value) {
      if (pub.isBible() &&
          note.location.bookNumber != null &&
          note.location.chapterNumber != null) {
        docTitle = JwLifeApp.bibleCluesInfo.getVerse(
          note.location.bookNumber!,
          note.location.chapterNumber!,
          note.blockIdentifier ?? 0,
        );
      } else {
        if (pub.documentsManager == null) {
          final db = await openDatabase(pub.databasePath!);
          final rows = await db.rawQuery(
              'SELECT Title FROM Document WHERE MepsDocumentId = ?',
              [note.location.mepsDocumentId]);
          if (rows.isNotEmpty) docTitle = rows.first['Title'] as String;
        } else {
          final doc = pub.documentsManager!.documents.firstWhereOrNull(
                  (d) => d.mepsDocumentId == note.location.mepsDocumentId);
          docTitle = doc?.title ?? '';
        }
      }
    }

    _cache[note.guid] = {'pub': pub, 'docTitle': docTitle};
    return _cache[note.guid]!;
  }

  @override
  State<NoteItemWidget> createState() => _NoteItemWidgetState();

  /// 🔥 Nouvelle version ultra rapide du surlignage
  Widget buildHighlight(
      String text,
      String? query,
      TextStyle base,
      TextStyle hl, {
        int? maxLines,
      }) {
    if (query == null || query.isEmpty) {
      return Text(text, style: base, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final normText = removeDiacritics(text.toLowerCase());
    final normQuery = removeDiacritics(query.toLowerCase());
    final index = normText.indexOf(normQuery);

    if (index == -1) {
      return Text(text, style: base, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(text: text.substring(0, index), style: base),
          TextSpan(text: text.substring(index, index + query.length), style: hl),
          TextSpan(text: text.substring(index + query.length), style: base),
        ],
      ),
    );
  }
}

class _NoteItemWidgetState extends State<NoteItemWidget> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = NoteItemWidget.resolveDependenciesCached(widget.note);
  }

  @override
  void didUpdateWidget(covariant NoteItemWidget old) {
    super.didUpdateWidget(old);
    if (widget.note.guid != old.note.guid) {
      future = NoteItemWidget.resolveDependenciesCached(widget.note);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.note.guid.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black,
    );

    final titleHL = titleStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.4),
      color: Colors.black,
    );

    final contentStyle = TextStyle(
      fontSize: 14,
      color: isDark ? Colors.white : Colors.black,
    );

    final contentHL = contentStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.4),
      color: Colors.black,
    );

    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        final pub = snapshot.data?['pub'];
        final docTitle = snapshot.data?['docTitle'] ?? '';
        final bool hasPub = pub != null;

        return GestureDetector(
          onTap: () async {
            await showPage(
              NotePage(
                note: widget.note,
                searchQuery: widget.highlightQuery,
              ),
            );
            widget.onUpdated?.call();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.note.getColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey[850]! : Colors.grey[300]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.note.getRelativeTime(), style: const TextStyle(fontSize: 10)),
                const SizedBox(height: 6),

                /// TITRE
                widget.buildHighlight(
                  widget.note.title ?? '',
                  widget.highlightQuery,
                  titleStyle,
                  titleHL,
                  maxLines: 1,
                ),

                const SizedBox(height: 8),

                /// CONTENU
                widget.fullNote
                    ? widget.buildHighlight(
                  widget.note.content ?? '',
                  widget.highlightQuery,
                  contentStyle,
                  contentHL,
                )
                    : SizedBox(
                  height: hasPub ? 86 : 140,
                  child: widget.buildHighlight(
                    widget.note.content ?? '',
                    widget.highlightQuery,
                    contentStyle,
                    contentHL,
                    maxLines: hasPub ? 4 : 8,
                  ),
                ),

                const SizedBox(height: 8),

                /// TAGS
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: widget.note.tagsId.map((t) {
                      final tag = context.watch<TagsController>().tags.firstWhereOrNull((tg) => tg.id == t);
                      if (tag == null) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _buildTagButton(context, tag),
                      );
                    }).toList(),
                  ),
                ),

                if (hasPub) ...[
                  const SizedBox(height: 10),
                  Divider(color: Colors.grey[600], height: 1),
                  const SizedBox(height: 10),

                  InkWell(
                    onTap: () {
                      if (widget.note.location.mepsDocumentId != null) {
                        showDocumentView(
                          context,
                          widget.note.location.mepsDocumentId!,
                          widget.note.location.mepsLanguageId!,
                          startParagraphId: widget.note.blockIdentifier,
                          endParagraphId: widget.note.blockIdentifier,
                        );
                      }
                      else if (widget.note.location.bookNumber != null && widget.note.location.chapterNumber != null) {
                        showChapterView(
                            context,
                            widget.note.location.keySymbol!,
                            widget.note.location.mepsLanguageId!,
                            widget.note.location.bookNumber!,
                            widget.note.location.chapterNumber!,
                            firstVerseNumber: widget.note.blockIdentifier,
                            lastVerseNumber: widget.note.blockIdentifier
                        );
                      }
                    },
                    child: Row(
                      children: [
                        ImageCachedWidget(
                          imageUrl: pub.imageSqr,
                          icon: pub.category.icon,
                          height: 30,
                          width: 30,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docTitle.isEmpty ? pub.getShortTitle() : docTitle,
                                style: const TextStyle(fontSize: 14, height: 1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                docTitle.isEmpty ? pub.getSymbolAndIssue() : pub.getShortTitle(),
                                style: TextStyle(fontSize: 11, height: 1, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagButton(BuildContext context, Tag tag) {
    return ElevatedButton(
      onPressed: () async {
        if(widget.tag != null && tag.id == widget.tag!.id) return;
        await showPage(TagPage(tag: tag));
        widget.onUpdated?.call();
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xEE1e1e1e)
            : Color(0xFFe8e8e8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
        visualDensity: VisualDensity.compact,
        elevation: 0,
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF8b9fc1)
              : Color(0xFF4a6da7),
        ),
      ),
    );
  }
}

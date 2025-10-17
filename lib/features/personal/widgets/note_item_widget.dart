import 'package:flutter/material.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';

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

  const NoteItemWidget({
    super.key,
    required this.note,
    required this.tag,
    this.onUpdated,
  });

  static Future<Map<String, dynamic>> resolveNoteDependencies(Note note) async {
    String? keySymbol = note.location.keySymbol;
    int? issueTagNumber = note.location.issueTagNumber;
    int? mepsLanguageId = note.location.mepsLanguageId;

    if (keySymbol == null || issueTagNumber == null || mepsLanguageId == null) {
      return {'pub': null, 'docTitle': ''};
    }

    Publication? pub = PublicationRepository().getAllPublications().firstWhereOrNull((element) => element.keySymbol == note.location.keySymbol && element.issueTagNumber == note.location.issueTagNumber && element.mepsLanguage.id == note.location.mepsLanguageId);

    String docTitle = '';
    pub ??= await PubCatalog.searchPubNoMepsLanguage(note.location.keySymbol!, note.location.issueTagNumber!, note.location.mepsLanguageId!);

    if (pub != null) {
      if (pub.isDownloadedNotifier.value) {
        if(pub.isBible() && note.location.bookNumber != null && note.location.chapterNumber != null) {
          docTitle = JwLifeApp.bibleCluesInfo.getVerse(note.location.bookNumber!, note.location.chapterNumber!, note.blockIdentifier ?? 0);
        }
        else {
          if (pub.documentsManager == null) {
            final db = await openDatabase(pub.databasePath!);
            final rows = await db.rawQuery(
              'SELECT Title FROM Document WHERE MepsDocumentId = ?',
              [note.location.mepsDocumentId],
            );
            if (rows.isNotEmpty) {
              docTitle = rows.first['Title'] as String;
            }
          }
          else {
            final doc = pub.documentsManager!.documents.firstWhereOrNull((d) => d.mepsDocumentId == note.location.mepsDocumentId);
            docTitle = doc?.title ?? '';
          }
        }
      }
    }

    return {'pub': pub, 'docTitle': docTitle};
  }

  @override
  State<NoteItemWidget> createState() => _NoteItemWidgetState();
}

class _NoteItemWidgetState extends State<NoteItemWidget> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = NoteItemWidget.resolveNoteDependencies(widget.note);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.note.noteId == -1) return SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.all(12),
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        final pub = snapshot.data!['pub'] as Publication?;
        final docTitle = snapshot.data!['docTitle'] as String;
        final note = widget.note;

        return GestureDetector(
          onTap: () async {
            await showPage(NotePage(note: note));
            widget.onUpdated?.call();
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]!
                    : Colors.grey[300]!,
              ),
              color: note.getColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.getRelativeTime(), style: TextStyle(fontSize: 10)),
                SizedBox(height: 4),
                Text(
                  note.title ?? '',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  note.content ?? '',
                  style: TextStyle(fontSize: 16),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.tagsId.map((t) {
                    final tag = JwLifeApp.userdata.tags.firstWhereOrNull((tg) => tg.id == t);
                    if (tag == null) return SizedBox.shrink();
                    return ElevatedButton(
                      onPressed: () async {
                        if(widget.tag != null && tag.id == widget.tag!.id) return;
                        await showPage(TagPage(tag: tag));
                        widget.onUpdated?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
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
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF8b9fc1)
                              : Color(0xFF4a6da7),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (pub != null)
                  const SizedBox(height: 4),
                if (pub != null)
                  Divider(thickness: 1, color: Colors.grey),
                if (pub != null)
                  const SizedBox(height: 4),
                if (pub != null)
                  InkWell(
                    onTap: () {
                      if (note.location.mepsDocumentId != null) {
                        showDocumentView(
                          context,
                          note.location.mepsDocumentId!,
                          note.location.mepsLanguageId!,
                          startParagraphId: note.blockIdentifier,
                          endParagraphId: note.blockIdentifier,
                        );
                      }
                      else if (note.location.bookNumber != null && note.location.chapterNumber != null) {
                        showChapterView(
                            context,
                            note.location.keySymbol!,
                            note.location.mepsLanguageId!,
                            note.location.bookNumber!,
                            note.location.chapterNumber!,
                            firstVerseNumber: note.blockIdentifier,
                            lastVerseNumber: note.blockIdentifier
                        );
                      }
                    },
                    child: Row(
                      children: [
                        ImageCachedWidget(
                          imageUrl: pub.imageSqr,
                          icon: pub.category.icon,
                          height: 35,
                          width: 35,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docTitle.isEmpty ? pub.getShortTitle() : docTitle,
                                style: TextStyle(
                                    fontSize: 16,
                                    height: 1
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                docTitle.isEmpty ? pub.getSymbolAndIssue() : pub.getShortTitle(),
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1,
                                    color: Colors.grey
                                ),
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
            ),
          ),
        );
      },
    );
  }
}

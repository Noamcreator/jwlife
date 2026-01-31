import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/core/utils/utils_audio.dart';
import 'package:jwlife/core/utils/utils_video.dart';
import 'package:jwlife/data/controller/tags_controller.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/data/models/audio.dart';
import 'package:jwlife/data/models/media.dart';
import 'package:jwlife/data/models/video.dart';
import 'package:jwlife/data/realm/catalog.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';

import '../../../app/jwlife_app.dart';
import '../../../core/utils/common_ui.dart';
import '../../../core/utils/utils_document.dart';
import '../../../data/controller/notes_controller.dart';
import '../../../data/models/publication.dart';
import '../../../data/models/userdata/note.dart';
import '../../../data/models/userdata/tag.dart';
import '../../../data/repositories/PublicationRepository.dart';
import '../../../i18n/i18n.dart';
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

  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> resolveDependenciesCached(Note note) async {
    if (_cache.containsKey(note.guid)) return _cache[note.guid]!;

    final loc = note.location;


    Publication? pub;
    Media? media;
    String docTitle = '';

    if(loc.type == 1 || loc.type == 0) {
      pub = PublicationRepository().getAllPublications().firstWhereOrNull((p) => p.keySymbol == loc.keySymbol && p.issueTagNumber == loc.issueTagNumber && p.mepsLanguage.id == loc.mepsLanguageId);

      pub ??= await CatalogDb.instance.searchPubNoMepsLanguage(loc.keySymbol!,loc.issueTagNumber!, loc.mepsLanguageId!);

      if (pub != null && pub.isDownloadedNotifier.value) {
        if (pub.isBible() &&
            loc.bookNumber != null &&
            loc.chapterNumber != null) {
          docTitle = JwLifeApp.bibleCluesInfo.getVerse(
            loc.bookNumber!,
            loc.chapterNumber!,
            note.blockIdentifier ?? 0,
          );
        } 
        else {
          if (pub.documentsManager == null) {
            final db = await openReadOnlyDatabase(pub.databasePath!);
            final rows = await db.rawQuery(
              'SELECT Title FROM Document WHERE MepsDocumentId = ?',
              [loc.mepsDocumentId],
            );
            if (rows.isNotEmpty) docTitle = rows.first['Title'] as String;
          } 
          else {
            final doc = pub.documentsManager!.documents.firstWhereOrNull((d) => d.mepsDocumentId == loc.mepsDocumentId);
            docTitle = doc?.title ?? '';
          }
        }
      }
    }
    else if (loc.type == 2 || loc.type == 3) {
      RealmMediaItem? realmMediaItem = getMediaItem(loc.keySymbol, loc.track, loc.mepsDocumentId, loc.issueTagNumber, loc.mepsLanguageId);
      if (realmMediaItem != null) {
        if(realmMediaItem.type == 'AUDIO') {
          media = Audio.fromJson(mediaItem: realmMediaItem);
        }
        else {
          media = Video.fromJson(mediaItem: realmMediaItem);
        }
      }
    }
 
    return _cache[note.guid] = {'pub': pub, 'media': media, 'docTitle': docTitle};
  }

  @override
  State<NoteItemWidget> createState() => _NoteItemWidgetState();

  /// 🔥 Nouvelle version ultra rapide du surlignage
  Widget buildHighlight(
      String text,
      String? query,
      TextStyle style,
      TextStyle hlStyle, {
        int? maxLines,
      }) {

    final overflow = maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis;

    if (query == null || query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final nt = normalize(text);
    final nq = normalize(query);
    final idx = nt.indexOf(nq);

    if (idx == -1) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(text: text.substring(idx, idx + query.length), style: hlStyle),
          TextSpan(text: text.substring(idx + query.length)),
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
  void didUpdateWidget(NoteItemWidget old) {
    super.didUpdateWidget(old);
    if (old.note.guid != widget.note.guid) {
      future = NoteItemWidget.resolveDependenciesCached(widget.note);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.note.guid.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : Colors.black,
    );

    final highlightStyle = titleStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.45),
      color: Colors.black,
    );

    final contentStyle = TextStyle(
      fontSize: 14,
      color: isDark ? Colors.white : Colors.black,
      height: 1.3,
    );

    final contentHL = contentStyle.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.45),
      color: Colors.black,
    );

    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        final pub = snapshot.data?['pub'];
        final media = snapshot.data?['media'];
        final docTitle = snapshot.data?['docTitle'] ?? '';

        return Stack(
          children: [
              Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                color: widget.note.getColor(context),
                child: InkWell(
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
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(0),
                      border: Border.all(color: Color(0xFFA0A0A0).withOpacity(0.5), width: 0.6),
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
                          highlightStyle,
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
                        ) : widget.buildHighlight(
                          widget.note.content ?? '',
                          widget.highlightQuery,
                          contentStyle,
                          contentHL,
                          maxLines: pub != null || media != null ? 7 : 9,
                        ),

                        const SizedBox(height: 10),

                        /// TAGS
                        SizedBox(
                          height: 32,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: context
                                .watch<TagsController>()
                                .tags
                                .where((t) => widget.note.tagsId.contains(t.id))
                                .map((tag) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _buildTagButton(context, tag),
                            )).toList(),
                          ),
                        ),

                        if (pub != null || media != null) ...[
                          const SizedBox(height: 12),
                          Divider(color: Colors.grey.shade600, height: 1),
                          const SizedBox(height: 10),

                          InkWell(
                            onTap: () {
                              final loc = widget.note.location;

                              if (loc.mepsDocumentId != null) {
                                showDocumentView(
                                  context,
                                  loc.mepsDocumentId!,
                                  loc.mepsLanguageId!,
                                  startParagraphId: widget.note.blockIdentifier,
                                  endParagraphId: widget.note.blockIdentifier,
                                );
                              } 
                              else if (loc.bookNumber != null && loc.chapterNumber != null) {
                                showChapterView(
                                  context,
                                  loc.keySymbol!,
                                  loc.mepsLanguageId!,
                                  loc.bookNumber!,
                                  loc.chapterNumber!,
                                  firstVerseNumber: widget.note.blockIdentifier,
                                  lastVerseNumber: widget.note.blockIdentifier,
                                );
                              }
                              else if (loc.type == 2) {
                               RealmMediaItem? mediaItem = getAudioItem(
                                  loc.keySymbol,
                                  loc.track,
                                  loc.mepsDocumentId,
                                  loc.issueTagNumber,
                                  loc.mepsLanguageId,
                                );

                                Audio audio = Audio.fromJson(mediaItem: mediaItem);
                                audio.showPlayer(context);
                              }
                              else if (loc.type == 3) {
                                RealmMediaItem? mediaItem = getMediaItem(
                                  loc.keySymbol,
                                  loc.track,
                                  loc.mepsDocumentId,
                                  loc.issueTagNumber,
                                  loc.mepsLanguageId,
                                );

                                Video video = Video.fromJson(mediaItem: mediaItem);
                                video.showPlayer(context);
                              }
                            },
                            child: Row(
                              children: [
                                ImageCachedWidget(
                                  imageUrl: pub?.imageSqr ?? (media?.networkImageSqr ?? media?.imagePath),
                                  icon: pub != null ? pub.category.icon : media is Audio ? JwIcons.headphones__simple : JwIcons.video,
                                  height: 30,
                                  width: 30,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pub != null ? docTitle.isEmpty ? pub.getShortTitle() : docTitle : media?.title ?? '',
                                        style: const TextStyle(fontSize: 14, height: 1),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        pub != null ? docTitle.isEmpty ? pub.getSymbolAndIssue() : pub.getShortTitle() : media is Audio ? i18n().pub_type_audio_programs : media is Video ? i18n().label_videos : media?.title ?? '',
                                        style: TextStyle(fontSize: 11, height: 1, color: Color(0xFFA0A0A0)),
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
                ),
              ),
            ),
            // Bouton d'options placé en haut à droite
            PositionedDirectional(
              top: 2,
              end: 8,
              child: PopupMenuButton(
                useRootNavigator: true,
                icon: const Icon(Icons.more_horiz, size: 25, color: Color(0xFFA0A0A0)),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'delete', child: Row(children: [
                    Icon(JwIcons.trash, size: 22, color: Theme.of(context).primaryColor),
                    SizedBox(width: 8),
                    Text(i18n().action_delete),
                  ])),
                  PopupMenuItem(value: 'color', child: Row(children: [
                    Icon(Icons.color_lens, size: 24, color: Theme.of(context).primaryColor),
                    SizedBox(width: 8),
                    Text(i18n().action_change_color),
                  ])),
                ],
                onSelected: (value) {
                  if(value == 'delete') {
                    context.read<NotesController>().removeNote(widget.note.guid);
                  }
                }
              ),
            ),
          ]
        );
      },
    );
  }

  Widget _buildTagButton(BuildContext context, Tag tag) {
    return ElevatedButton(
      onPressed: () async {
        if (widget.tag != null && tag.id == widget.tag!.id) return;
        await showPage(TagPage(tag: tag));
        widget.onUpdated?.call();
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xEE1e1e1e)
            : const Color(0xFFe8e8e8),
        elevation: 0,
        minimumSize: Size.zero,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF8b9fc1)
              : const Color(0xFF4a6da7),
        ),
      ),
    );
  }
}

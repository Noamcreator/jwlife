import 'package:flutter/material.dart';

class SearchHtmlWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  const SearchHtmlWidget({
    super.key,
    required this.text,
    this.style = const TextStyle(),
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: style,
        children: _buildTextSpans(),
      ),
    );
  }

  /// Parses the input string for simple HTML-like tags and applies
  /// the corresponding text styles.
  ///
  /// Supports: `<strong>`, `<em>`, `<sup>`, `<span class="altsize">`.
  List<TextSpan> _buildTextSpans() {
    // Replaces HTML non-breaking space with a regular space to avoid issues with text rendering.
    final String cleanText = text.replaceAll('&nbsp;', ' ');
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'(<[^>]+>)(.*?)(<\/[^>]+>)');
    // We now use `cleanText` for all regex and substring operations.
    final Iterable<RegExpMatch> matches = regExp.allMatches(cleanText);

    int lastIndex = 0;
    for (final match in matches) {
      // Add normal text before the current tag
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: cleanText.substring(lastIndex, match.start),
          ),
        );
      }

      final String tag = match.group(1)!;
      final String content = match.group(2)!;
      TextStyle spanStyle = style;

      // Apply style based on the tag
      if (tag.contains('<strong>')) {
        spanStyle = style.copyWith(
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.yellow,
        );
      } else if (tag.contains('<em>')) {
        spanStyle = style.copyWith(
          fontStyle: FontStyle.italic,
        );
      } else if (tag.contains('<sup>')) {
        // Note: For true superscript, you would use a WidgetSpan with a transform.
        // This is a simplified approach by reducing font size.
        spanStyle = style.copyWith(
          fontSize: (style.fontSize ?? 14) * 0.7,
        );
      } else if (tag.contains('span class="altsize"')) {
        spanStyle = style.copyWith(
          fontSize: (style.fontSize ?? 14) * 0.8,
        );
      }

      // Add the styled TextSpan
      spans.add(
        TextSpan(
          text: content,
          style: spanStyle,
        ),
      );

      lastIndex = match.end;
    }

    // Add any remaining normal text after the last tag
    if (lastIndex < cleanText.length) {
      spans.add(
        TextSpan(
          text: cleanText.substring(lastIndex),
        ),
      );
    }

    return spans;
  }
}

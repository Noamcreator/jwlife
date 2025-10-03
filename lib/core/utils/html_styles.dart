import 'package:flutter/material.dart';

class TextHtmlWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool isSearch;

  const TextHtmlWidget({
    super.key,
    required this.text,
    this.style = const TextStyle(),
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.isSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(
        style: style,
        children: _parseHtml(context, text, style),
      ),
    );
  }

  /// Parser récursif pour transformer du pseudo-HTML simple en TextSpan
  List<InlineSpan> _parseHtml(BuildContext context, String input, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];

    input = input.replaceAll('&nbsp;', ' ');

    final tagReg = RegExp(
      r'<(\/?)(strong|em|sup|span|p)(?: class="([^"]+)")?>',
      caseSensitive: false,
    );

    int index = 0;
    while (index < input.length) {
      final match = tagReg.matchAsPrefix(input, index);
      if (match == null) {
        // Texte brut jusqu’au prochain tag
        final nextTag = input.indexOf('<', index);
        final text = nextTag == -1
            ? input.substring(index)
            : input.substring(index, nextTag);

        if (text.isNotEmpty) {
          spans.add(TextSpan(text: text, style: baseStyle));
        }
        index = nextTag == -1 ? input.length : nextTag;
      } else {
        final isClosing = match.group(1) == '/';
        final tag = match.group(2)!.toLowerCase();
        final classAttr = match.group(3);

        if (!isClosing) {
          // balise ouvrante → trouver la fermeture correspondante
          final closeTag = '</$tag>';
          final startContent = match.end;
          final endIndex = _findClosingTag(input, startContent, tag);
          if (endIndex == -1) {
            // Pas de fermeture → traiter comme texte brut
            spans.add(TextSpan(text: match.group(0), style: baseStyle));
            index = match.end;
            continue;
          }

          final inner = input.substring(startContent, endIndex);

          // appliquer le style
          TextStyle newStyle = baseStyle;
          if (tag == 'strong') {
            newStyle = isSearch
                ? newStyle.copyWith(
              fontWeight: FontWeight.bold,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF86761e)
                  : const Color(0xFFfff9bb),
            )
                : newStyle.copyWith(fontWeight: FontWeight.bold);
          } else if (tag == 'em') {
            newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
          } else if (tag == 'span' && classAttr == 'altsize') {
            newStyle = newStyle.copyWith(
              fontSize: (newStyle.fontSize ?? 14) * 0.8,
            );
          }

          if (tag == 'sup') {
            // On parse récursivement le contenu du sup
            final innerSpans = _parseHtml(
              context,
              inner,
              baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) * 0.7),
            );

            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: Transform.translate(
                  offset: const Offset(0, -4), // ajuste la hauteur
                  child: RichText(
                    text: TextSpan(children: innerSpans),
                  ),
                ),
              ),
            );

            index = endIndex + closeTag.length;
            continue; // skip le spans.addAll plus bas
          }

          if (tag == 'p') {
            // contenu du <p>
            spans.addAll(_parseHtml(context, inner, baseStyle));
            spans.add(const TextSpan(text: '\n\n')); // saut de ligne
            index = endIndex + closeTag.length;
            continue;
          }

          // récursion pour parser l’intérieur
          spans.addAll(_parseHtml(context, inner, newStyle));

          index = endIndex + closeTag.length;
        } else {
          // fermeture inattendue → texte brut
          spans.add(TextSpan(text: match.group(0), style: baseStyle));
          index = match.end;
        }
      }
    }

    return spans;
  }

  /// Trouve l’index de la balise fermante correspondante (gestion imbriquée simple)
  int _findClosingTag(String input, int start, String tag) {
    final openTag = RegExp('<$tag(\\s+[^>]*)?>', caseSensitive: false);
    final closeTag = RegExp('</$tag>', caseSensitive: false);

    int depth = 1;
    int index = start;
    while (index < input.length) {
      final openMatch = openTag.matchAsPrefix(input, index);
      final closeMatch = closeTag.matchAsPrefix(input, index);

      if (openMatch != null) {
        depth++;
        index = openMatch.end;
      } else if (closeMatch != null) {
        depth--;
        if (depth == 0) {
          return index;
        }
        index = closeMatch.end;
      } else {
        index++;
      }
    }
    return -1; // pas trouvé
  }
}

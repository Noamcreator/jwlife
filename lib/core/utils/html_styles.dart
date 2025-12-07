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
        style: style.copyWith(
          fontFamily: 'Roboto',
        ),
        children: _parseHtml(context, text, style),
      ),
    );
  }

  /// Parser récursif pour transformer du pseudo-HTML simple en TextSpan.
  /// Gère uniquement les balises autorisées et ignore les autres.
  List<InlineSpan> _parseHtml(BuildContext context, String input, TextStyle baseStyle) {
    // Balises que ce parser sait gérer
    const allowedTags = {'strong', 'em', 'sup', 'span', 'p'};

    // Regex générale pour capturer N'IMPORTE QUELLE balise HTML
    final tagReg = RegExp(
      r'<(\/?)([a-zA-Z0-9]+)(?: class="([^"]+)")?([^>]*)?>',
      caseSensitive: false,
    );

    final List<InlineSpan> spans = [];

    input = input.replaceAll('&nbsp;', ' ');

    int index = 0;
    while (index < input.length) {
      final match = tagReg.matchAsPrefix(input, index);
      if (match == null) {
        // Texte brut jusqu’au prochain tag (ou fin de chaîne)
        final nextTag = input.indexOf('<', index);
        final text = nextTag == -1
            ? input.substring(index)
            : input.substring(index, nextTag);

        if (text.isNotEmpty) {
          spans.add(TextSpan(text: text, style: baseStyle));
        }
        index = nextTag == -1 ? input.length : nextTag;
      } else {
        // Un motif de balise a été trouvé
        final isClosing = match.group(1) == '/';
        final tag = match.group(2)!.toLowerCase();
        final classAttr = match.group(3);

        // --- NOUVEAU : Vérification de la balise ---
        if (!allowedTags.contains(tag)) {
          // Balise inconnue ou non autorisée (e.g., <a>, <div>).
          // On avance l'index pour ignorer toute la balise (la remplacer par '').
          index = match.end;
          continue;
        }
        // --- FIN NOUVEAU ---


        // Le reste de la logique gère UNIQUEMENT les balises connues et autorisées

        if (!isClosing) {
          // Balise ouvrante autorisée → trouver la fermeture correspondante
          final closeTag = '</$tag>';
          final startContent = match.end;
          final endIndex = _findClosingTag(input, startContent, tag);

          if (endIndex == -1) {
            // Balise ouvrante connue mais sans fermeture → Ignorer la balise ouvrante.
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
          }
          else if (tag == 'em') {
            newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
          }
          else if (tag == 'span' && classAttr == 'altsize') {
            newStyle = newStyle.copyWith(
              fontSize: (newStyle.fontSize ?? 14) * 0.8,
            );
          }

          if (tag == 'sup') {
            // Gestion spécifique pour les exposants (WidgetSpan)
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
            continue;
          }

          // Lignes 119-124 :
          if (tag == 'p') {
            // Gestion spécifique pour les paragraphes (saut de ligne)
            spans.addAll(_parseHtml(context, inner, baseStyle));
            index = endIndex + closeTag.length;
            continue;
          }

          // récursion pour parser l’intérieur des balises <strong>, <em>, <span>
          spans.addAll(_parseHtml(context, inner, newStyle));

          index = endIndex + closeTag.length;
        } else {
          // Balise fermante inattendue pour un tag connu (e.g., </strong> au début du texte)
          // On ignore la balise (la remplace par '').
          index = match.end;
        }
      }
    }

    return spans;
  }

  /// Trouve l’index de la balise fermante correspondante (gestion imbriquée simple)
  int _findClosingTag(String input, int start, String tag) {
    // La regex doit être plus générale pour les balises ouvrantes,
    // mais elle ne doit chercher que les tags autorisés (ici, le tag actuel)
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

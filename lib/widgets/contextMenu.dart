import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:jwlife/utils/icons.dart';
import 'package:share_plus/share_plus.dart';

void showParagraphContextMenu(BuildContext context, String languageSymbol, int mepsDocumentId, String paragraphId, String paragraphText, Offset position) {
  final RenderBox renderBox = context.findRenderObject() as RenderBox;
  final localOffset = renderBox.globalToLocal(position);

  ContextMenu menu = ContextMenu(
    padding: const EdgeInsets.all(10.0),
    position: localOffset,
    entries: [
      MenuItem(
        label: 'Écouter',
        icon: JwIcons.play,
        onSelected: () {
          print('Play');
        }
      ),
      MenuItem(
        label: 'Copier',
        icon: JwIcons.document_stack,
        onSelected: () {
          Clipboard.setData(ClipboardData(text: paragraphText));
        }
      ),
      MenuItem(
        label: 'Partager',
        icon: JwIcons.share,
        onSelected: () {
          Share.share(
            'https://www.jw.org/finder?srcid=jwlshare&wtlocale=$languageSymbol&prefer=lang&docid=$mepsDocumentId&par=$paragraphId',
            subject: paragraphId,
          );
        }
      ),
    ],
  );

  showContextMenu(context, contextMenu: menu);
}

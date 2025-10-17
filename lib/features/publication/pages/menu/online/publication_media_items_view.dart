import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/widgets/image_cached_widget.dart';

class PublicationMediaItemsView extends StatefulWidget {
  final String document;

  const PublicationMediaItemsView({super.key, required this.document});

  @override
  _PublicationMediaItemsViewState createState() => _PublicationMediaItemsViewState();
}

class _PublicationMediaItemsViewState extends State<PublicationMediaItemsView> {
  List<Map<String, dynamic>> _mediaItems = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Parse le webview HTML
    html_dom.Document document = html_dom.Document.html(widget.document);

    // Parcourt tous les éléments du webview
    for (var element in document.getElementsByTagName('img')) {
      // Vérifie si l'élément est une image
      if (element.localName == 'img') {
        // Imprime le lien de l'image (valeur de l'attribut 'src')
        _mediaItems.add({
          'ImageUrl': 'https://wol.jw.org' + element.attributes['src']!,
        });
      }
    }

    setState(() {
      // Actualise l'état si nécessaire
      _mediaItems = _mediaItems;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voir les médias'),
      ),
      body: ListView.builder(
        itemCount: _mediaItems.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: ImageCachedWidget(imageUrl: _mediaItems[index]['ImageUrl'], icon: JwIcons.video),
          );
        },
      ),
    );
  }
}

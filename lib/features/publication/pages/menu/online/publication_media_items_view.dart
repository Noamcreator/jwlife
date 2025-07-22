import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:jwlife/widgets/image_cached_widget.dart';

class PublicationMediaItemsView extends StatefulWidget {
  final String document;

  const PublicationMediaItemsView({super.key, required this.document});

  @override
  _PublicationMediaItemsViewState createState() => _PublicationMediaItemsViewState();
}

class _PublicationMediaItemsViewState extends State<PublicationMediaItemsView> {
  List<Map<String, dynamic>> media_items = [];

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
        media_items.add({
          'ImageUrl': 'https://wol.jw.org' + element.attributes['src']!,
        });
      }
    }

    setState(() {
      // Actualise l'état si nécessaire
      media_items = media_items;
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
        itemCount: media_items.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: ImageCachedWidget(imageUrl: media_items[index]['ImageUrl'], pathNoImage: ''),
          );
        },
      ),
    );
  }
}

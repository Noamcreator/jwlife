import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html;
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';

import '../../../core/api.dart';
import 'bible_chapter.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  _BiblePageState createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  late String publicationLink;
  bool _isLoading = true;
  List<Book> hebrewBooks = [];
  List<Book> greekBooks = [];

  @override
  void initState() {
    super.initState();
    publicationLink = 'https://wol.jw.org/fr/wol/binav/r30/lp-f/nwtsty';
    _fetchHtmlContent();
  }

  Future<void> _fetchHtmlContent() async {
    final response = await Api.httpGetWithHeaders(publicationLink);
    if (response.statusCode == 200) {
      _parseHtml(response.body);
    } else {
      // Handle error
    }
  }

  void _parseHtml(String htmlContent) {
    final document = html_parser.parse(htmlContent);

    // Parse Hebrew books
    final hebrewBooksHtml = document.querySelectorAll('.books.hebrew .book');
    hebrewBooks = hebrewBooksHtml.map((element) {
      final link = element.querySelector('.bookLink')?.attributes['href'] ?? '';
      final name = element.querySelector('.name')?.text ?? '';
      final abbreviation = element.querySelector('.abbreviation')?.text ?? '';
      final official = element.querySelector('.official')?.text ?? '';
      final type = _getBookTypeFromClass(element); // Determine le type de livre

      return Book(name: name, abbreviation: abbreviation, official: official, link: link, type: type);
    }).toList();

    // Parse Greek books
    final greekBooksHtml = document.querySelectorAll('.books.greek .book');
    greekBooks = greekBooksHtml.map((element) {
      final link = element.querySelector('.bookLink')?.attributes['href'] ?? '';
      final name = element.querySelector('.name')?.text ?? '';
      final abbreviation = element.querySelector('.abbreviation')?.text ?? '';
      final official = element.querySelector('.official')?.text ?? '';
      final type = _getBookTypeFromClass(element); // Determine le type de livre

      return Book(name: name, abbreviation: abbreviation, official: official, link: link, type: type);
    }).toList();

    setState(() {
      _isLoading = false;
    });
  }

  // Méthode pour obtenir le type de livre à partir de la classe CSS
  String _getBookTypeFromClass(html.Element element) {
    final classAttr = element.attributes['class'] ?? '';
    if (classAttr.contains('pentateuch')) {
      return 'pentateuch';
    } else if (classAttr.contains('historical')) {
      return 'historical';
    } else if (classAttr.contains('poetic')) {
      return 'poetic';
    } else if (classAttr.contains('prophetic')) {
      return 'prophetic';
    } else if (classAttr.contains('gospels')) {
      return 'gospels';
    } else if (classAttr.contains('acts')) {
      return 'acts';
    } else if (classAttr.contains('letters')) {
      return 'letters';
    } else if (classAttr.contains('revelation')) {
      return 'revelation';
    } else {
      return 'other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bible d'Étude", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.magnifying_glass),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryHeader("ÉCRITURES HÉBRAÏQUES ET ARAMÉENNES"),
            _buildBookGrid(hebrewBooks),
            SizedBox(height: 20.0),
            _buildCategoryHeader("ÉCRITURES GRECQUES CHRÉTIENNES"),
            _buildBookGrid(greekBooks),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBookGrid(List<Book> books) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookContainer(book); // Utilisation de _buildBookContainer au lieu de _buildBookCard
      },
    );
  }

  Widget _buildBookContainer(Book book) {
    final Map<String, Color> typeColor = TypeColors.generateTypeColors(context);

    return InkWell(
      onTap: () {
        showPage(context, ChapterBiblePage(book: book));
      },
      child: Container(
        decoration: BoxDecoration(
          color: typeColor[book.type] ?? Colors.grey, // Utilisation de la couleur du type ou couleur par défaut
        ),
        padding: EdgeInsets.all(10.0), // Ajout d'un peu de padding pour espacer le contenu
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                book.official,
                style: TextStyle(
                  fontSize: 15.0,
                  color: Colors.white, // Couleur blanche pour contraster avec les fonds colorés
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Book {
  final String name;
  final String abbreviation;
  final String official;
  final String link;
  final String type;

  Book({
    required this.name,
    required this.abbreviation,
    required this.official,
    required this.link,
    required this.type,
  });
}

class TypeColors {
  static Map<String, Color> generateTypeColors(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // Remplacement des couleurs basées sur `primaryColor`.
    return {
      'pentateuch': primaryColor,
      'historical': primaryColor.withOpacity(0.7), // Variante plus claire
      'poetic': primaryColor.withOpacity(0.8),     // Variante intermédiaire
      'prophetic': primaryColor,
      'gospels': primaryColor,
      'acts': primaryColor.withOpacity(0.7),       // Variante plus claire
      'letters': primaryColor.withOpacity(0.8),    // Variante intermédiaire
      'revelation': primaryColor,
      'other': Color(0xFF808080),
    };
  }
}


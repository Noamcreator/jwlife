import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/api/api.dart';
import '../../../core/utils/utils.dart';
import 'online_bible_view.dart';

class ChapterBiblePage extends StatefulWidget {
  final Book book;
  const ChapterBiblePage({super.key, required this.book});

  @override
  _ChapterBiblePageState createState() => _ChapterBiblePageState();
}

class _ChapterBiblePageState extends State<ChapterBiblePage> {
  late String publicationLink;
  bool _isLoading = true;
  List<Chapter> chapters = [];

  @override
  void initState() {
    super.initState();
    publicationLink = 'https://wol.jw.org/${widget.book.link}';
    _fetchHtmlContent();
  }

  Future<void> _fetchHtmlContent() async {
    try {
      final response = await Api.httpGetWithHeaders(publicationLink);
      if (response.statusCode == 200) {
        _parseHtml(response.data);
      }
    }
    catch (e) {
     printTime('Error fetching HTML content: $e');
    }
  }

  void _parseHtml(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final chapterElements = document.querySelectorAll('.grid.chapters .chapter');

    chapters = chapterElements.map((element) {
      final chapterNumber = element.querySelector('a')?.text ?? '';
      final chapterLink = element.querySelector('a')?.attributes['href'] ?? '';
      return Chapter(number: chapterNumber, link: chapterLink);
    }).toList();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name, style: TextStyle(fontWeight: FontWeight.bold)), // bold font
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChapterGrid(chapters),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterGrid(List<Chapter> chapters) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0, // Adjust according to your UI design
      ),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return _buildChapterContainer(chapter);
      },
    );
  }

  Widget _buildChapterContainer(Chapter chapter) {
    return InkWell(
      onTap: () {
        //showPage(BibleView(book: widget.book, chapter: chapter));
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF757575),
        ),
        child: Center(
          child: Text(
            chapter.number,
            style: const TextStyle(fontSize: 20.0, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class Chapter {
  final String number;
  final String link;

  Chapter({required this.number, required this.link});
}

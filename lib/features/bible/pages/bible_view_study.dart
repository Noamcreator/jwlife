import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html;
import 'package:jwlife/core/icons.dart';

import '../../../core/api.dart';
import '../../../core/utils/utils.dart';

class BibleView extends StatefulWidget {
  final String link;

  const BibleView({super.key, required this.link});

  @override
  _BibleViewState createState() => _BibleViewState();
}

class _BibleViewState extends State<BibleView> {
  bool _isLoading = true;
  String _header = '';
  List<Map<String, dynamic>> _verses = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Api.httpGetWithHeaders('https://wol.jw.org/${widget.link}');
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        // Extract header and title
        final headerElement = document.querySelector('header h1');
        if (headerElement != null) {
          setState(() {
            _header = headerElement.text.trim();
          });
        }

        // Extract verses
        final verses = document.querySelectorAll('span.v');
        setState(() {
          _verses = verses.map((span) {
            final verseNumber = verses.first == span ? span.querySelector('strong')?.text ?? '' : span.querySelector('.vl.vx.vp')?.text ?? ''; // Extract verse number
            final nodes = span.nodes;

            // Process each node in the verse to extract text and special characters
            List<dynamic> verseParts = [];
            nodes.forEach((node) {
              if (node is html.Element) {
                if (node.localName == 'a' && node.classes.contains('b')) {
                  // Handle special characters "*", "+"
                  final symbol = node.text.trim();
                  verseParts.add({
                    'type': 'symbol',
                    'text': symbol,
                    'isClickable': true,
                  });
                } else {
                  // Handle text nodes
                  verseParts.add({
                    'type': 'text',
                    'text': node.text.trim(),
                    'isClickable': false,
                  });
                }
              } else if (node is html.Text) {
                // Handle text nodes
                verseParts.add({
                  'type': 'text',
                  'text': node.text.trim(),
                  'isClickable': false,
                });
              }
            });

            return {'number': verseNumber, 'parts': verseParts};
          }).toList();
        });
      } else {
        throw Exception('Failed to load publication');
      }
    } catch (e) {
      printTime('Error: $e');
      // Handle error and display to the user if needed
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bible View"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _header,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _verses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_verses[index]['number']} ',
                        style: TextStyle(
                          fontSize: index == 0 ? 30 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          children: _verses[index]['parts'].map<Widget>((part) {
                            if (part['type'] == 'symbol') {
                              return GestureDetector(
                                onTap: () {
                                  // Handle click on special character
                                  printTime('Clicked: ${part['text']}');
                                },
                                child: Text(
                                  ' ${part['text']} ',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            } else {
                              return Text(
                                part['text'],
                                style: TextStyle(fontSize: 16),
                              );
                            }
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle floating action button press
        },
        child: Icon(JwIcons.gem, color: Colors.white),
      ),
    );
  }
}

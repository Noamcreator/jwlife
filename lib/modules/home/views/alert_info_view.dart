import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';

import '../../../app/jwlife_app.dart';
import '../../../widgets/dialog/language_dialog.dart';

class AlertInfoPage extends StatefulWidget {
  final List<dynamic> alerts; // Liste d'alertes

  const AlertInfoPage({Key? key, required this.alerts}) : super(key: key);

  @override
  _AlertInfoPageState createState() => _AlertInfoPageState();
}

class _AlertInfoPageState extends State<AlertInfoPage> {
  String language = '';

  @override
  void initState() {
    super.initState();
    setLanguage();
  }

  void setLanguage() async {
    setState(() {
      language = JwLifeApp.currentLanguage.vernacular;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerte Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              language,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(JwIcons.language),
            onPressed: () async {
              LanguageDialog languageDialog = const LanguageDialog();
              showDialog(
                context: context,
                builder: (context) => languageDialog,
              ).then((value) {
                print('Language selected: $value');
              });
            },
          )
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: widget.alerts.length,
        separatorBuilder: (context, index) => const Padding(
            padding: EdgeInsets.only(top: 25, bottom: 25),
            child: Divider(thickness: 1, color: Colors.grey, indent: 0, endIndent: 0),
        ),
        itemBuilder: (context, index) {
          final alert = widget.alerts[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /*
              HtmlWidget(
                alert['title'],
                textStyle: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'NotoSans',
                  height: 1.2,
                ),
              ),

               */
              const SizedBox(height: 10),
              /*
              HtmlWidget(
                alert['body'],
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontFamily: 'NotoSans',
                ),
                customStylesBuilder: (htmlElement) {
                  if (htmlElement.localName == 'a') {
                    return {
                      'text-decoration': 'none',
                      'color': Theme.of(context).brightness == Brightness.dark
                          ? '#9fb9e3'
                          : '#4a6da7',
                    };
                  }
                  return null;
                },
                onTapUrl: (url) async {
                  if (url.startsWith('https://www.jw.org/')) {
                    if (url.contains('lank')) {
                      final uri = Uri.parse(url);
                      showFullScreenVideo(context, uri.queryParameters['lank']!, alert['languageCode']);
                      return true;
                    }
                    else if (url.contains('bible')) {
                      print('Opening Bible page...');
                    }
                    else {
                      launchUrl(Uri.parse(url));
                    }
                  }
                  return true;
                },
              ),

               */
            ],
          );
        },
      ),
    );
  }
}

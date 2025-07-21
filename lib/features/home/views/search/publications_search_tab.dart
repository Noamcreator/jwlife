import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jwlife/core/api.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/views/search/search_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/utils/utils.dart';
import '../../../../widgets/dialog/language_dialog.dart';

class PublicationsSearchTab extends StatefulWidget {
  final SearchModel model;

  const PublicationsSearchTab({super.key, required this.model});

  @override
  _PublicationsSearchTabState createState() => _PublicationsSearchTabState();
}

class _PublicationsSearchTabState extends State<PublicationsSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchPublications(), // Appel de la méthode async du modèle
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune publication trouvée'));
        }

        final results = snapshot.data!;

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];

            return GestureDetector(
              onTap: () async {
                String? jwLink = item['links']['jw.org'] ?? '';
                String? wolLink = item['links']['wol'] ?? '';

                if (wolLink != null && wolLink.isNotEmpty) {
                  String lank = item['lank'];
                  String keySymbol = '';
                  String issueTagNumber = '0';

                  RegExp regExp = RegExp(r'^(pub|pi)-([\w-]+?)(?:_(\d+))?$');
                  Match? match = regExp.firstMatch(lank);

                  if (match != null) {
                    keySymbol = match.group(2) ?? '';
                    if (match.group(3) != null) {
                      String rawNumber = match.group(3)!;
                      issueTagNumber = rawNumber.length == 6 ? '${rawNumber}00' : rawNumber;
                    }
                  }

                  Publication? publication = await PubCatalog.searchPub(
                    keySymbol,
                    int.parse(issueTagNumber),
                    JwLifeSettings().currentLanguage.id,
                  );

                  if (publication != null) {
                    publication.showMenu(context);
                  }
                  else {
                    printTime('Publication not found for lank: $lank');
                  }
                }
                else {
                  launchUrl(Uri.parse(jwLink!), mode: LaunchMode.externalApplication);
                }
              },
              child: Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF292929)
                    : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: SizedBox(
                  height: 150,
                  child: Row(
                    children: [
                      item['imageUrl'] != null && item['imageUrl'] != ''
                          ? Stack(
                        children: [
                          SizedBox(
                            width: 110,
                            height: 150,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(0)),
                              child: Image.network(
                                item['imageUrl'],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ) : Container(
                        width: 110,
                        height: 150,
                        color: Colors.grey,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['context'],
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 15,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: -7,
                                right: -13,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 25),
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    PopupMenuItem(
                                      child: const Text('Envoyer le lien'),
                                      onTap: () {
                                        Share.share(
                                          'https://www.jw.org/finder?srcid=jwlshare&wtlocale=${JwLifeSettings().currentLanguage.symbol}&lank=${item['lank']}',
                                        );
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: const Text('Autres langues'),
                                      onTap: () async {
                                        String link =
                                            'https://b.jw-cdn.org/apis/mediator/v1/media-item-availability/${item['lank']}?clientType=www';
                                        final response = await Api.httpGetWithHeaders(link);
                                        if (response.statusCode == 200) {
                                          final jsonData = json.decode(response.body);
                                          LanguageDialog languageDialog = LanguageDialog(
                                            languagesListJson: jsonData['languages'],
                                          );
                                          showDialog(
                                            context: context,
                                            builder: (context) => languageDialog,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

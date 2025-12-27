import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/data/models/publication.dart';
import 'package:jwlife/data/databases/catalog.dart';
import 'package:jwlife/features/home/pages/search/search_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../core/uri/jworg_uri.dart';
import '../../../../core/utils/utils_language_dialog.dart';
import '../../../../i18n/i18n.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.model.fetchPublications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.blue[300]! : Colors.blue[700]!,
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Une erreur est survenue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune publication trouvée',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Essayez avec d\'autres termes de recherche',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final results = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[850] : Colors.grey[200],
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];

            String? jwLink = item['links']['jw.org'] ?? '';
            String? wolLink = item['links']['wol'] ?? '';

            String lank = item['lank'];
            String keySymbol = '';
            String issueTagNumber = '0';

            if (wolLink != null && wolLink.isNotEmpty) {
              RegExp regExp = RegExp(r'^(pub|pi)-([\w-]+?)(?:_(\d+))?$');
              Match? match = regExp.firstMatch(lank);

              if (match != null) {
                keySymbol = match.group(2) ?? '';
                if (match.group(3) != null) {
                  String rawNumber = match.group(3)!;
                  issueTagNumber = rawNumber.length == 6 ? '${rawNumber}00' : rawNumber;
                }
              }
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  Publication? publication = await CatalogDb.instance.searchPub(
                    keySymbol,
                    int.parse(issueTagNumber),
                    JwLifeSettings.instance.currentLanguage.value.id,
                  );

                  if (publication != null) {
                    publication.showMenu(context);
                  } else {
                    launchUrl(Uri.parse(jwLink!), mode: LaunchMode.externalApplication);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------------------------------------
                      //     IMAGE (à gauche)
                      // ---------------------------------------
                      Container(
                        width: 80,
                        height: 100,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: item['imageUrl'] != null && item['imageUrl'] != ''
                              ? Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                          )
                              : Center(
                            child: Icon(
                              JwIcons.book_stack,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                              size: 36,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // ---------------------------------------
                      //     CONTENU (à droite)
                      // ---------------------------------------
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titre de la publication
                            Text(
                              item['title'].replaceAll('&nbsp;', ' '),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 6),

                            // Contexte (description)
                            Text(
                              item['context'],
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 4),

                      // ---------------------------------------
                      //     MENU ACTIONS (à droite)
                      // ---------------------------------------
                      PopupMenuButton<String>(
                        useRootNavigator: true,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_horiz,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          size: 22,
                        ),
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.share_outlined,
                                  size: 20,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                                const SizedBox(width: 12),
                                Text(i18n().action_open_in_share),
                              ],
                            ),
                            onTap: () {
                              final lank = item['lank'].toString();

                              String? fullSymbol;
                              if (lank.contains('-')) {
                                fullSymbol = lank.split('-')[1];
                              } else {
                                fullSymbol = lank;
                              }

                              String symbol;
                              int? issueTagNumber;
                              if (fullSymbol.contains('_')) {
                                symbol = fullSymbol.split('_')[0];
                                issueTagNumber = int.tryParse(fullSymbol.split('_')[1]);
                              } else {
                                symbol = fullSymbol;
                                issueTagNumber = null;
                              }

                              final uri = JwOrgUri.publication(
                                wtlocale: JwLifeSettings.instance.currentLanguage.value.symbol,
                                pub: symbol,
                                issue: issueTagNumber ?? 0,
                              ).toString();

                              SharePlus.instance.share(
                                ShareParams(title: item['title'], uri: Uri.tryParse(uri)),
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.language_outlined,
                                  size: 20,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                                const SizedBox(width: 12),
                                Text(i18n().label_languages_more),
                              ],
                            ),
                            onTap: () async {
                              Publication? publication = await CatalogDb.instance.searchPub(
                                keySymbol,
                                int.parse(issueTagNumber),
                                JwLifeSettings.instance.currentLanguage.value.id,
                              );

                              if (publication != null) {
                                showLanguagePubDialog(context, publication).then((languagePub) async {
                                  if (languagePub != null) {
                                    languagePub.showMenu(context);
                                  }
                                });
                              }
                            },
                          ),
                        ],
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
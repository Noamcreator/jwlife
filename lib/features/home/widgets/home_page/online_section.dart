import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/services/settings_service.dart';
import '../../../../i18n/i18n.dart';

class OnlineSection extends StatefulWidget {
  const OnlineSection({super.key});

  @override
  State<OnlineSection> createState() => OnlineSectionState();
}

class OnlineSectionState extends State<OnlineSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i18n().navigation_online,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 110, // Augmenté pour tenir compte du texte sur 2 lignes
          child: ListView.builder(
            padding: const EdgeInsets.all(0.0),
            scrollDirection: Axis.horizontal,
            itemCount: _iconLinks(context).length,
            itemBuilder: (context, index) {
              final iconLinkInfo = _iconLinks(context)[index];
              return Padding(
                padding: const EdgeInsets.only(right: 2.0), // Espacement entre chaque icône
                child: getOnlineIconWidget(
                  imagePath: iconLinkInfo.imagePath,
                  url: iconLinkInfo.url,
                  description: iconLinkInfo.description,
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget getOnlineIconWidget({
    required String imagePath,
    required String url,
    required String description,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw 'Could not launch $url';
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2.0),
            child: Image.asset(
              imagePath,
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 2), // Espacement entre l'image et le texte
          SizedBox(
            width: 80, // Alignement avec l'image
            height: 28, // Hauteur fixe (≈ 2 lignes)
            child: Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class IconLinkInfo {
  final String imagePath;
  final String description;
  final String url;

  IconLinkInfo(this.imagePath, this.description, this.url);
}

List<IconLinkInfo> _iconLinks(BuildContext context) {
  return [
    IconLinkInfo('assets/icons/nav_jworg.png', i18n().navigation_official_website, 'https://www.jw.org/${JwLifeSettings().currentLanguage.primaryIetfCode}'),
    IconLinkInfo('assets/icons/nav_jwb.png', i18n().navigation_online_broadcasting, 'https://www.jw.org/open?docid=1011214&wtlocale=${JwLifeSettings().currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_onlinelibrary.png', i18n().navigation_online_library, 'https://wol.jw.org/wol/finder?wtlocale=${JwLifeSettings().currentLanguage.symbol}'),
    IconLinkInfo('assets/icons/nav_donation.png', i18n().navigation_online_donation, 'https://donate.jw.org/ui/${JwLifeSettings().currentLanguage.symbol}/donate-home.html'),
    IconLinkInfo(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/icons/nav_github_light.png'
          : 'assets/icons/nav_github_dark.png',
      i18n().navigation_online_gitub,
      'https://github.com/Noamcreator/jwlife',
    ),
  ];
}

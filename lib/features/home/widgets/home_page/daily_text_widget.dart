import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/app_data/app_data_service.dart';
import '../../../../app/services/settings_service.dart';
import '../../../../core/icons.dart';
import '../../../../core/utils/common_ui.dart';
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/widgets_utils.dart';
import '../../../../data/models/publication.dart';
import '../../../../i18n/i18n.dart';

class DailyTextWidget extends StatelessWidget {
  const DailyTextWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Publication?>(
      valueListenable: AppDataService.instance.dailyText,
      builder: (context, pub, _) {
        if (pub == null) {
          return _buildWelcomeSection(context);
        }

        return ValueListenableBuilder<bool>(
          valueListenable: pub.isDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            return ValueListenableBuilder<String>(
              valueListenable: AppDataService.instance.dailyTextHtml,
              builder: (context, htmlText, _) {
                return _buildDailyTextContent(
                  context: context,
                  pub: pub,
                  isDownloaded: isDownloaded,
                  verseHtml: htmlText,
                );
              },
            );
          },
        );
      },
    );
  }

  // --------------------------
  // UI SECTIONS
  // --------------------------

  Widget _buildWelcomeSection(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF121212)
              : Colors.white,
          height: 128,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                i18n().message_welcome_to_jw_life,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                i18n().message_app_for_jehovah_witnesses,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildDailyTextContent({
    required BuildContext context,
    required Publication pub,
    required bool isDownloaded,
    required String verseHtml,
  }) {
    final now = DateTime.now();
    final locale = JwLifeSettings.instance.currentLanguage.value.getSafeLocale();

    return GestureDetector(
      onTap: () {
        if (isDownloaded) {
          showPageDailyText(pub);
        } else {
          pub.download(context);
        }
      },
      child: Stack(
        children: [
          Container(
            height: 128,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF121212)
                : Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: isDownloaded && verseHtml.isNotEmpty
                      ? [
                    const Icon(JwIcons.calendar, size: 24),
                    const SizedBox(width: 8),
                    Text(capitalize(DateFormat('EEEE d MMMM yyyy', locale.languageCode).format(now)),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(JwIcons.chevron_right, size: 24),
                  ]
                      : [
                    Text(
                      i18n().message_welcome_to_jw_life,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                isDownloaded
                    ? verseHtml.isEmpty
                    ? getLoadingWidget(Theme.of(context).primaryColor)
                    : Text(
                  verseHtml,
                  maxLines: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.2),
                )
                    : Text(
                  i18n().message_download_daily_text(
                      DateFormat('yyyy').format(now)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.2),
                ),
              ],
            ),
          ),

          // BARRE DE PROGRESSION
          ValueListenableBuilder<bool>(
            valueListenable: pub.isDownloadingNotifier,
            builder: (context, downloading, _) {
              if (!downloading) return const SizedBox.shrink();
              return PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: pub.progressNotifier,
                  builder: (context, progress, _) {
                    return LinearProgressIndicator(
                      value: progress == -1 ? null : progress,
                      minHeight: 2,
                      valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor), backgroundColor: Colors.transparent,
                    );
                  },
                ),
              );
            },
          )
        ],
      ),
    );
  }
}

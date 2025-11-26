import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/html_styles.dart';
import 'package:jwlife/i18n/i18n.dart';

import '../../../../core/app_data/app_data_service.dart';
import '../../pages/alerts_list_page.dart';

class AlertsBanner extends StatefulWidget {
  const AlertsBanner({super.key});

  @override
  AlertsBannerState createState() => AlertsBannerState();
}

class AlertsBannerState extends State<AlertsBanner> {
  PageController? _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _startTimer(int alertsLength) {
    _timer?.cancel(); // évite les timers multiples

    if (alertsLength <= 1) return; // inutile de slider

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _pageController == null) return;

      if (_currentPage < alertsLength - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController!.hasClients) {
        _pageController!.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: AppDataService.instance.alerts,
      builder: (context, alerts, _) {
        if (alerts.isEmpty) {
          _timer?.cancel();
          return const SizedBox.shrink();
        }

        // Recrée un nouveau PageController si la longueur change
        _pageController?.dispose();
        _pageController = PageController(initialPage: _currentPage);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTimer(alerts.length);
        });

        return GestureDetector(
          onTap: () {
            showPage(AlertsListPage(alerts: alerts));
          },
          child: Container(
            color: const Color(0xFF143368),
            padding: const EdgeInsets.all(8),
            height: 50,
            child: Center(
              child: PageView.builder(
                controller: _pageController,
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextHtmlWidget(
                          text: alert['title'],
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          isSearch: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (alerts.length > 1)
                        Text(
                          i18n().label_breaking_news_count(
                              index + 1, alerts.length),
                          style: const TextStyle(color: Colors.white),
                        ),
                      const SizedBox(width: 8),
                      const Icon(JwIcons.chevron_right, color: Colors.white),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
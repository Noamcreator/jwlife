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

  /// Gère le défilement automatique des alertes
  void _startTimer(int alertsLength) {
    _timer?.cancel();

    if (alertsLength <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _pageController == null || !_pageController!.hasClients) return;

      if (_currentPage < alertsLength - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController!.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: AppDataService.instance.alerts,
      builder: (context, alerts, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          reverseDuration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            // Animation de position (Glissement vers le bas)
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: const Offset(0.0, 0.0),
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            return ClipRect(
              child: FadeTransition(
                opacity: animation, // Effet de fondu (Fade)
                child: SlideTransition(
                  position: offsetAnimation,
                  child: SizeTransition(
                    sizeFactor: animation, // La bannière pousse le contenu
                    axisAlignment: -1.0,
                    child: child,
                  ),
                ),
              ),
            );
          },
          // Utilise une clé unique pour que l'AnimatedSwitcher détecte le changement
          child: alerts.isEmpty
              ? const SizedBox.shrink(key: ValueKey('empty_banner'))
              : _buildBannerContent(alerts),
        );
      },
    );
  }

  /// Construit le corps de la bannière quand il y a des alertes
  Widget _buildBannerContent(List<dynamic> alerts) {
    // Initialisation ou mise à jour du controller
    if (_pageController == null) {
      _pageController = PageController(initialPage: _currentPage);
    }

    // Relance le timer après le rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startTimer(alerts.length);
    });

    return GestureDetector(
      key: const ValueKey('active_banner'),
      onTap: () {
        showPage(AlertsListPage(alerts: alerts));
      },
      child: Container(
        color: const Color(0xFF143368),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 50,
        child: Row(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: alerts.length,
                onPageChanged: (index) => _currentPage = index,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return Center(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextHtmlWidget(
                            text: alert['title'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            isSearch: false,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            if (alerts.length > 1)
              Text(
                i18n().label_breaking_news_count(_currentPage + 1, alerts.length),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            const SizedBox(width: 8),
            const Icon(JwIcons.chevron_right, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
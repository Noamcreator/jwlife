import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/features/home/pages/alert_info_page.dart';
import 'package:html/dom.dart' as html_dom;

class AlertBanner extends StatefulWidget {
  final List<dynamic> alerts;

  const AlertBanner({super.key, required this.alerts});

  @override
  _AlertBannerState createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);

    // Change d'alerte toutes les 3 secondes
    _timer = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      if (_currentPage < widget.alerts.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alerts.isEmpty) return SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showPage(context, AlertInfoPage(alerts: widget.alerts));
      },
      child: Container(
        color: Theme.of(context).primaryColor,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.centerLeft,
        height: 55, // Ajustez la hauteur selon vos besoins
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.alerts.length,
          itemBuilder: (context, index) {
            final alert = widget.alerts[index];
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    html_dom.Document.html(alert['title']).body!.text,
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.alerts.length > 1)
                  Text(
                    '${index + 1} sur ${widget.alerts.length}',
                    style: TextStyle(color: Colors.white),
                  ),
                const SizedBox(width: 8),
                Icon(JwIcons.chevron_right, color: Colors.white),
              ],
            );
          },
        ),
      ),
    );
  }
}

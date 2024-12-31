import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WebViewData {
  late String theme;
  late String backgroundColor;
  late String cssCode;

  // Méthode privée pour charger le CSS
  Future<void> init(bool isDark) async {
    theme = isDark ? 'cc-theme--dark' : 'cc-theme--light';
    backgroundColor = isDark ? '#121212' : '#ffffff';
    cssCode = await rootBundle.loadString('assets/webapp/collector.css');
  }

  void update(bool isDark) {
    theme = isDark ? 'cc-theme--dark' : 'cc-theme--light';
    backgroundColor = isDark ? '#121212' : '#ffffff';
  }
}

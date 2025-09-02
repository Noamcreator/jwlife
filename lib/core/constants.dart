import 'package:flutter/material.dart';

class Constants {
  static const String appName = 'JW Life';
  static const String appVersion = '1.0.0';
  static const String appOwner = 'Noam';
  static const String appRepo = 'jwlife';
  static const String jwlifeShare = 'jwlshare';

  static const Color defaultLightPrimaryColor = Color(0xFF646496);
  static Color defaultDarkPrimaryColor = Color.lerp(defaultLightPrimaryColor, Colors.white, 0.3)!;
}

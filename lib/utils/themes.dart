import 'package:flutter/material.dart';

Color primaryColorLight = Color(0xFF295568);
Color primaryColorDark = Color.lerp(primaryColorLight, Colors.white, 0.2)!; // Ajustez le facteur entre 0 et 1

final light = ThemeData(
    brightness: Brightness.light,
    cardColor: const Color(0xfff1f1f1),
    primaryColor: primaryColorLight,
    secondaryHeaderColor: Colors.black,
    scaffoldBackgroundColor: Color(0xFFF1F1F1),
    iconTheme: IconThemeData(color: primaryColorLight),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(iconColor: WidgetStateProperty.all(primaryColorLight)),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFd8d8d8), scrolledUnderElevation: 0),
    tabBarTheme: TabBarTheme(
      tabAlignment: TabAlignment.start,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontSize: 15, fontFamily: 'NotoSansBold'),
      unselectedLabelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0),
      labelColor: primaryColorLight,
      unselectedLabelColor: const Color(0xFF4f4f4f),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: primaryColorLight,
          width: 2,
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFFd8d8d8),
      selectedItemColor: primaryColorLight,
      unselectedItemColor: const Color(0xFF4f4f4f),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColorLight,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(primaryColorLight),
      trackColor: WidgetStateProperty.all(const Color(0xFFF1F1F1)),
      trackOutlineColor: WidgetStateProperty.all(primaryColorLight),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xffffffff),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Color(0xFF212121), fontSize: 15)),
      menuPadding: EdgeInsets.only(top: 4, bottom: 4, left: 4, right: 4),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xffffffff),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
      titleTextStyle: const TextStyle(color: Color(0xFF212121), fontSize: 20, fontWeight: FontWeight.bold),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(const Color(0xFFffffff)),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
    ),
    searchViewTheme: SearchViewThemeData(
      backgroundColor: Color(0xFFffffff),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryColorLight,
      inactiveTrackColor: const Color(0xFFd8d8d8),
      thumbColor: primaryColorLight,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(primaryColorLight),
        overlayColor: WidgetStateProperty.all(primaryColorLight.withAlpha(40)),
      ),
    )
);

final dark = ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
    }),
    brightness: Brightness.dark,
    primaryColor: primaryColorDark,
    secondaryHeaderColor: Colors.white,
    scaffoldBackgroundColor: Colors.black,
    iconTheme: IconThemeData(color: primaryColorDark),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(iconColor: WidgetStateProperty.all(primaryColorDark)),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF292929), scrolledUnderElevation: 0),
    tabBarTheme: TabBarTheme(
      tabAlignment: TabAlignment.start,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontSize: 15, fontFamily: 'NotoSansBold'),
      unselectedLabelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0),
      labelColor: primaryColorDark,
      unselectedLabelColor: const Color(0xffffffff),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: primaryColorDark,
          width: 2,
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF292929),
      selectedItemColor: primaryColorDark,
      unselectedItemColor: const Color(0xFFdadada),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColorDark,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(primaryColorDark),
      trackColor: WidgetStateProperty.all(Colors.black),
      trackOutlineColor: WidgetStateProperty.all(primaryColorDark),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xff3c3c3c),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Color(0xFFffffff), fontSize: 15)),
      menuPadding: EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 4),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Color(0xff3c3c3c),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
      titleTextStyle: TextStyle(color: Color(0xFFffffff), fontSize: 20, fontWeight: FontWeight.bold),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(const Color(0xFF292929)),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
    ),
    searchViewTheme: SearchViewThemeData(
      backgroundColor: Color(0xFF292929),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryColorDark,
      inactiveTrackColor: const Color(0xFFd8d8d8),
      thumbColor: primaryColorDark,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(Colors.white),
        overlayColor: WidgetStateProperty.all(Colors.white),
        iconColor: WidgetStateProperty.all(primaryColorDark),
      ),
    )
);
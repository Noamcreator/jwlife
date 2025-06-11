import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';

//Color primaryColorLight = Color(0xFF295568);
//Color primaryColorDark = Color.lerp(primaryColorLight, Colors.white, 0.3)!; // Ajustez le facteur entre 0 et 1

class AppTheme {
  static ThemeData getLightTheme(Color primaryColor) {
    //Color primaryColorLight = await getPrimaryColor(ThemeMode.light);
    //Color primaryColor = color;

    return ThemeData(
      brightness: Brightness.light,
      cardColor: const Color(0xfff1f1f1),
      primaryColor: primaryColor,
      secondaryHeaderColor: Colors.black,
      scaffoldBackgroundColor: Color(0xFFF1F1F1),
      iconTheme: IconThemeData(color: primaryColor),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(iconColor: WidgetStateProperty.all(primaryColor)),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFd8d8d8), scrolledUnderElevation: 0),
      tabBarTheme: TabBarThemeData(
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontSize: 15, fontFamily: 'NotoSansBold'),
        unselectedLabelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0),
        labelColor: primaryColor,
        unselectedLabelColor: const Color(0xFF4f4f4f),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFFd8d8d8),
        selectedItemColor: primaryColor,
        unselectedItemColor: const Color(0xFF4f4f4f),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(primaryColor),
        trackColor: WidgetStateProperty.all(const Color(0xFFF1F1F1)),
        trackOutlineColor: WidgetStateProperty.all(primaryColor),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xffffffff),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Color(0xFF212121), fontSize: 15)),
        menuPadding: EdgeInsets.only(top: 4, bottom: 4, left: 4, right: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xffffffff),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
        titleTextStyle: const TextStyle(color: Color(0xFF212121), fontSize: 20, fontWeight: FontWeight.bold),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(const Color(0xFFffffff)),
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(0.0)),
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
        activeTrackColor: primaryColor,
        inactiveTrackColor: const Color(0xFFd8d8d8),
        thumbColor: primaryColor,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(primaryColor),
          overlayColor: WidgetStateProperty.all(primaryColor.withAlpha(40)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(primaryColor),
          overlayColor: WidgetStateProperty.all(primaryColor.withAlpha(40)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primaryColor),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(primaryColor.withAlpha(40)),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.black),
    );
  }

  static ThemeData getDarkTheme(Color primaryColor) {
    //Color primaryColorDark= await getPrimaryColor(ThemeMode.light);
    //Color primaryColor = color ?? primaryColorDark;

    return ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        }),
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        secondaryHeaderColor: Colors.white,
        scaffoldBackgroundColor: Colors.black,
        iconTheme: IconThemeData(color: primaryColor),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(iconColor: WidgetStateProperty.all(primaryColor)),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF292929), scrolledUnderElevation: 0),
        tabBarTheme: TabBarThemeData(
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: TextStyle(fontSize: 15, fontFamily: 'NotoSansBold'),
          unselectedLabelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0),
          labelColor: primaryColor,
          unselectedLabelColor: const Color(0xffffffff),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: primaryColor,
              width: 2,
            ),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF292929),
          selectedItemColor: primaryColor,
          unselectedItemColor: const Color(0xFFdadada),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(primaryColor),
          trackColor: WidgetStateProperty.all(Colors.black),
          trackOutlineColor: WidgetStateProperty.all(primaryColor),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xff3c3c3c),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Color(0xFFffffff), fontSize: 15)),
          menuPadding: EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 4),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xff3c3c3c),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
          titleTextStyle: TextStyle(color: Color(0xFFffffff), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        searchBarTheme: SearchBarThemeData(
          backgroundColor: WidgetStateProperty.all(const Color(0xFF1f1f1f)),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(0.0)),
            ),
          ),
          elevation: WidgetStateProperty.all(0),
          constraints: const BoxConstraints(maxHeight: 48, minHeight: 48),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10)),
          textStyle: WidgetStateProperty.all(const TextStyle(color: Colors.white, decoration: TextDecoration.none)),
          hintStyle: WidgetStateProperty.all(const TextStyle(color: Color(0xFFB3B3B3), decoration: TextDecoration.none)),
        ),
        searchViewTheme: SearchViewThemeData(
          backgroundColor: Color(0xFF292929),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: primaryColor,
          inactiveTrackColor: const Color(0xFFd8d8d8),
          thumbColor: primaryColor,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(Colors.white),
            overlayColor: WidgetStateProperty.all(Colors.white),
            iconColor: WidgetStateProperty.all(primaryColor),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(primaryColor),
            overlayColor: WidgetStateProperty.all(primaryColor.withAlpha(40)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(primaryColor),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            overlayColor: WidgetStateProperty.all(primaryColor.withAlpha(40)),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white)
    );
  }
}
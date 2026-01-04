import 'package:flutter/material.dart';
import 'package:jwlife/core/ui/text_styles.dart';

class AppTheme {
  static ThemeData getLightTheme(Color primaryColor) {
    Color backgroundColor = const Color(0xFFF1F1F1);
    Color subTitleColor = const Color(0xFF5B5B5B);
    Color containerColor = const Color(0xFFFFFFFF);
    Color otherColor = const Color(0xFF3C3C3C);

    return ThemeData(
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      cardColor: const Color(0xfff1f1f1),
      primaryColor: primaryColor,
      secondaryHeaderColor: Colors.black,
      scaffoldBackgroundColor: backgroundColor,
      extensions: <ThemeExtension<dynamic>>[
        JwLifeThemeStyles(
            appBarTitle: const TextStyle(fontSize: 19.0, fontWeight: FontWeight.bold, color: Colors.black),
            appBarSubTitle: TextStyle(fontSize: 14.0, color: subTitleColor),
            squareTitle: const TextStyle(fontSize: 9, color: Colors.black, height: 1.2),
            rectanglePublicationTitle: const TextStyle(fontSize: 14.0, color: Colors.black, height: 1.1),
            rectanglePublicationContext: TextStyle(fontSize: 11.0, color: subTitleColor, height: 1.2),
            rectanglePublicationSubtitle: TextStyle(fontSize: 11.0, color: subTitleColor, height: 1.2),
            rectangleMediaItemTitle: const TextStyle(fontSize: 10.0, color: Colors.black, height: 1.1),
            rectangleMediaItemSubTitle: TextStyle(fontSize: 10.0, color: subTitleColor, height: 1.1),
            rectangleMediaItemLargeTitle: const TextStyle(fontSize: 11.5, color: Colors.black, height: 1),
            categoryTitle: const TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Colors.grey),
            labelTitle: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black),
            containerColor: containerColor,
            otherColor: otherColor
        ),
      ],
      iconTheme: IconThemeData(color: primaryColor),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
            iconColor: WidgetStateProperty.all(primaryColor),
            visualDensity: VisualDensity.compact
        ),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Color(0xFFd8d8d8),
        scrolledUnderElevation: 0
      ),
      tabBarTheme: TabBarThemeData(
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        //labelStyle: TextStyle(fontSize: 15, fontFamily: 'NotoSansBold'),
        labelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0, fontWeight: FontWeight.bold),
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
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        hoverElevation: 0,
        disabledElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        padding: EdgeInsets.zero,
        trackOutlineWidth: WidgetStateProperty.all(0),
        thumbColor: WidgetStateProperty.all(Colors.white),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        trackColor: WidgetStateProperty.all(primaryColor),
        trackOutlineColor: WidgetStateProperty.all(primaryColor),
      ),
      popupMenuTheme: PopupMenuThemeData(
        iconColor: primaryColor,
        color: const Color(0xffffffff),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(color: Color(0xFF212121), fontSize: 15)),
        menuPadding: const EdgeInsets.all(2),
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
          foregroundColor: WidgetStateProperty.all(primaryColor), // Couleur du texte
          side: WidgetStateProperty.all(
            BorderSide(
              color: primaryColor,
              width: 1.0,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0.0),
            ),
          ),
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
    Color subTitleColor = const Color(0xFFC0C0C0);
    Color containerColor = const Color(0xFF292929);
    Color searchBarColor = const Color(0xFF1F1F1F);
    Color otherColor = const Color(0xFF3C3C3C);

    return ThemeData(
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        secondaryHeaderColor: Colors.white,
        scaffoldBackgroundColor: Colors.black,
        extensions: <ThemeExtension<dynamic>>[
          JwLifeThemeStyles(
            appBarTitle: const TextStyle(fontSize: 19.0, fontWeight: FontWeight.bold, color: Colors.white),
            appBarSubTitle: TextStyle(fontSize: 14.0, color: subTitleColor),
            squareTitle: const TextStyle(fontSize: 9, color: Colors.white, height: 1.2, fontWeight: FontWeight.w400),
            rectanglePublicationTitle: const TextStyle(fontSize: 14.0, color: Colors.white, height: 1.1),
            rectanglePublicationContext: TextStyle(fontSize: 11.0, color: subTitleColor, height: 1.2),
            rectanglePublicationSubtitle: TextStyle(fontSize: 11.0, color: subTitleColor, height: 1.2),
            rectangleMediaItemTitle: const TextStyle(fontSize: 10.0, color: Colors.white, height: 1.1),
            rectangleMediaItemSubTitle: TextStyle(fontSize: 10.0, color: subTitleColor, height: 1.1),
            rectangleMediaItemLargeTitle: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1),
            categoryTitle: const TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Colors.grey),
            labelTitle: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
            containerColor: containerColor,
            otherColor: otherColor
          ),
        ],
        cardColor: containerColor,
        iconTheme: IconThemeData(color: primaryColor),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
              iconColor: WidgetStateProperty.all(primaryColor),
              visualDensity: VisualDensity.compact
          ),
        ),
        appBarTheme: AppBarThemeData(
          backgroundColor: containerColor,
          scrolledUnderElevation: 0,
          actionsPadding: const EdgeInsets.all(0),
        ),
        tabBarTheme: TabBarThemeData(
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.tab,
          //labelStyle: TextStyle(fontSize: 15, fontFamily: 'NotoSansBold'),
          labelStyle: TextStyle(fontSize: 15, letterSpacing: 1.0, fontWeight: FontWeight.bold),
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
          backgroundColor: containerColor,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Color(0xFF333333),
          shape: const CircleBorder(),
          elevation: 0,
          hoverElevation: 0,
          disabledElevation: 0,
        ),
        switchTheme: SwitchThemeData(
          padding: EdgeInsets.zero,
          trackOutlineWidth: WidgetStateProperty.all(0),
          thumbColor: WidgetStateProperty.all(Colors.white),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          trackColor: WidgetStateProperty.all(primaryColor),
          trackOutlineColor: WidgetStateProperty.all(primaryColor),
        ),
        popupMenuTheme: PopupMenuThemeData(
          position: PopupMenuPosition.under,
          iconColor: primaryColor,
          elevation: 0,
          color: otherColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
          labelTextStyle: const WidgetStatePropertyAll(TextStyle(color: Colors.white, fontSize: 15)),
          menuPadding: const EdgeInsets.all(2),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: otherColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0.0))),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        searchBarTheme: SearchBarThemeData(
          backgroundColor: WidgetStateProperty.all(searchBarColor),
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
          backgroundColor: containerColor,
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
            foregroundColor: WidgetStateProperty.all(primaryColor), // Couleur du texte
            side: WidgetStateProperty.all(
              BorderSide(
                color: primaryColor,
                width: 1.0,
              ),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0.0),
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.all(primaryColor),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(primaryColor),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            overlayColor: WidgetStateProperty.all(primaryColor.withAlpha(40)),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white),
        useMaterial3: true
    );
  }
}
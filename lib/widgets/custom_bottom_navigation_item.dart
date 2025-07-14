
import 'package:flutter/material.dart';

class CustomBottomNavigationItem {
  final String label;
  final Widget icon;

  const CustomBottomNavigationItem({
    required this.label,
    required this.icon,
  });
}

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final List<CustomBottomNavigationItem> items;
  final Function(int) onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double selectedFontSize;
  final double unselectedFontSize;
  final TextStyle? selectedLabelStyle;
  final IconThemeData? selectedIconTheme;

  const CustomBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedFontSize = 14.0,
    this.unselectedFontSize = 12.0,
    this.selectedLabelStyle,
    this.selectedIconTheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.grey.withOpacity(0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          color: isSelected
                              ? (selectedItemColor ?? Theme.of(context).bottomNavigationBarTheme.selectedItemColor)
                              : (unselectedItemColor ?? Theme.of(context).bottomNavigationBarTheme.unselectedItemColor),
                          fill: isSelected ? (selectedIconTheme?.fill ?? 0.0) : 0.0,
                        ),
                        child: item.icon,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: isSelected ? selectedFontSize : unselectedFontSize,
                          fontWeight: isSelected ? (selectedLabelStyle?.fontWeight ?? FontWeight.bold) : FontWeight.normal,
                          color: isSelected
                              ? (selectedItemColor ?? Theme.of(context).bottomNavigationBarTheme.selectedItemColor)
                              : (unselectedItemColor ?? Theme.of(context).bottomNavigationBarTheme.unselectedItemColor),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
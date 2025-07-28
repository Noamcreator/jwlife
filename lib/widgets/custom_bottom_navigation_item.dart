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
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedFontSize = 12.0,
    this.unselectedFontSize = 12.0,
    this.selectedLabelStyle,
    this.selectedIconTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomNavTheme = theme.bottomNavigationBarTheme;

    final effectiveSelectedColor =
        selectedItemColor ?? bottomNavTheme.selectedItemColor ?? theme.primaryColor;
    final effectiveUnselectedColor =
        unselectedItemColor ?? bottomNavTheme.unselectedItemColor ?? theme.unselectedWidgetColor;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? bottomNavTheme.backgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 1,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        maintainBottomViewPadding: true,
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 1.0, bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: isSelected ? effectiveSelectedColor.withOpacity(0.15) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: IconTheme(
                          data: IconThemeData(
                            color: isSelected ? effectiveSelectedColor : effectiveUnselectedColor,
                            size: selectedIconTheme?.size ?? 26.0,  // taille fixe toujours 26
                          ),
                          child: item.icon,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: selectedFontSize * 1.3, // hauteur fixe pour texte (ajuster selon besoin)
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: selectedFontSize, // même taille toujours
                            fontWeight: isSelected
                                ? (selectedLabelStyle?.fontWeight ?? FontWeight.bold)
                                : FontWeight.normal,
                            color: isSelected ? effectiveSelectedColor : effectiveUnselectedColor,
                            height: 0.9,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

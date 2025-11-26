import 'package:flutter/material.dart';

class LongPressBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Function(int)? onLongPress;
  final List<BottomNavigationBarItem> items;
  final BottomNavigationBarType type;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;
  final bool showSelectedLabels;
  final bool showUnselectedLabels;
  final double? elevation;
  final Color? fixedColor;
  final MouseCursor? mouseCursor;

  const LongPressBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onLongPress,
    required this.items,
    this.type = BottomNavigationBarType.fixed,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
    this.showSelectedLabels = true,
    this.showUnselectedLabels = true,
    this.elevation,
    this.fixedColor,
    this.mouseCursor,
  });

  @override
  State<LongPressBottomNavBar> createState() => _LongPressBottomNavBarState();
}

class _LongPressBottomNavBarState extends State<LongPressBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    final Color glowColor = (widget.selectedItemColor ?? Theme.of(context).primaryColor);

    final List<Shadow> textShadows = [
      Shadow(
        color: glowColor.withOpacity(0.8),
        blurRadius: 5.0,
        offset: Offset.zero,
      ),
    ];

    // 2. Définir le style de texte sélectionné avec la lueur
    final TextStyle finalSelectedLabelStyle = (widget.selectedLabelStyle ?? const TextStyle(fontSize: 12.0))
        .copyWith(
      color: widget.selectedItemColor, // S'assurer que le texte a la bonne couleur
      shadows: textShadows,
    );

    // 2. Définir les paramètres du BoxShadow pour créer la lueur
    final List<BoxShadow> glowShadow = [
      BoxShadow(
        color: glowColor.withOpacity(0.8), // Couleur de la lueur (très visible)
        spreadRadius: -4,                     // Pas d'étalement
        blurRadius: 15,                      // Flou important pour un grand halo doux
        offset: Offset.zero,                 // Pas de décalage (lueur centrée)
      ),
    ];

    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      type: widget.type,
      backgroundColor: widget.backgroundColor,
      selectedItemColor: widget.selectedItemColor,
      unselectedItemColor: widget.unselectedItemColor,
      selectedLabelStyle: finalSelectedLabelStyle,
      unselectedLabelStyle: widget.unselectedLabelStyle,
      showSelectedLabels: widget.showSelectedLabels,
      showUnselectedLabels: widget.showUnselectedLabels,
      elevation: widget.elevation ?? 0.0,
      fixedColor: widget.fixedColor,
      mouseCursor: widget.mouseCursor,

      items: List.generate(
        widget.items.length, (index) {
          return BottomNavigationBarItem(
            icon: GestureDetector(
              onTap: () => widget.onTap(index),
              onLongPress: widget.onLongPress != null
                  ? () => widget.onLongPress!(index)
                  : null,
              child: widget.items[index].icon,
            ),
            activeIcon: GestureDetector(
                onTap: () => widget.onTap(index),
                onLongPress: widget.onLongPress != null
                    ? () => widget.onLongPress!(index)
                    : null,
                child: Container(
                    decoration: BoxDecoration(boxShadow: glowShadow),
                    child: widget.items[index].activeIcon
                )
            ),
            label: widget.items[index].label,
            tooltip: widget.items[index].tooltip,
            backgroundColor: widget.items[index].backgroundColor,
          );
        },
      ),

      onTap: (index) {
        widget.onTap(index);
      },

      landscapeLayout: BottomNavigationBarLandscapeLayout.linear,
    );
  }
}
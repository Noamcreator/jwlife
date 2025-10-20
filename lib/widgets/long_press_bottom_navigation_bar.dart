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
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      type: widget.type,
      backgroundColor: widget.backgroundColor,
      selectedItemColor: widget.selectedItemColor,
      unselectedItemColor: widget.unselectedItemColor,
      selectedLabelStyle: widget.selectedLabelStyle,
      unselectedLabelStyle: widget.unselectedLabelStyle,
      showSelectedLabels: widget.showSelectedLabels,
      showUnselectedLabels: widget.showUnselectedLabels,
      elevation: widget.elevation ?? 8.0,
      fixedColor: widget.fixedColor,
      mouseCursor: widget.mouseCursor,
      items: List.generate(
        widget.items.length,
            (index) {
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
              child: widget.items[index].activeIcon,
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
    );
  }
}
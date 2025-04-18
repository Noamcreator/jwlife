import 'package:flutter/material.dart';

class ResponsiveAppBarActions extends StatelessWidget {
  final List<IconTextButton> allActions;
  final int visibleCount;

  const ResponsiveAppBarActions({
    Key? key,
    required this.allActions,
    this.visibleCount = 2, // Nombre d'icônes visibles avant le menu
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    if (isWideScreen || allActions.length <= visibleCount) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: allActions.map((action) => IconButton(
            onPressed: action.onPressed,
            icon: action.icon
        )).toList(),
      );
    }

    // Séparer les actions visibles et celles dans le menu
    final visibleIcons = allActions.take(visibleCount).toList();
    final menuItems = allActions.skip(visibleCount).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleIcons.map((action) => IconButton(
            onPressed: action.onPressed,
            icon: action.icon
        )),
        PopupMenuButton<IconTextButton>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => menuItems.map((action) =>
              PopupMenuItem(
                value: action,
                child: ListTile(
                  iconColor: Theme.of(context).primaryColor,
                  leading: action.icon,
                  title: Text(action.text),
                  onTap: () {
                    Navigator.pop(context); // Ferme le menu
                    action.onPressed?.call(); // Exécute l'action
                  },
                ),
              ),
          ).toList(),
        ),
      ],
    );
  }
}

class IconTextButton {
  final String text;
  final Icon icon;
  final VoidCallback? onPressed;

  const IconTextButton({
    required this.text,
    required this.icon,
    this.onPressed,
  });
}

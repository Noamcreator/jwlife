import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';

class ResponsiveAppBarActions extends StatelessWidget {
  final List<IconTextButton> allActions;
  final Color? colorIcon;

  const ResponsiveAppBarActions({
    super.key,
    required this.allActions,
    this.colorIcon
  });

  // Fonction utilitaire pour cloner l'icône et appliquer la couleur
  Icon _cloneIconWithColor(Icon icon, Color? color) {
    return Icon(
      icon.icon,
      size: icon.size,
      color: color, // ⬅️ On injecte la couleur ici
      semanticLabel: icon.semanticLabel,
      textDirection: icon.textDirection,
      key: icon.key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // 1. Déterminer le nombre d'icônes visibles basé sur la largeur de l'écran (avec un plafond)
    int baseVisibleCount = 2; // Par défaut: 2 icônes (Compact <= 600)

    if (screenWidth > 900) {
      baseVisibleCount = 5;
    } else if (screenWidth > 750) {
      baseVisibleCount = 4;
    } else if (screenWidth > 600) {
      baseVisibleCount = 3;
    }

    // Assurer que le nombre calculé ne dépasse pas le nombre réel d'actions disponibles
    final finalVisibleCount = baseVisibleCount.clamp(0, allActions.length);

    // 2. CAS SIMPLE: Si le nombre total d'actions ne dépasse pas le nombre que l'on a calculé pour l'écran actuel, on les affiche toutes SANS menu.
    if (finalVisibleCount >= allActions.length) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: allActions.map((action) => IconButton(
          onPressed: action.onPressed,
          // ⬅️ CORRECTION : Cloner l'icône avec la nouvelle couleur
          icon: _cloneIconWithColor(action.icon, colorIcon),
          // La couleur de l'IconButton lui-même n'est plus nécessaire pour la couleur de l'icône.
        )).toList(),
      );
    }

    // 3. CAS COMPLEXE: Division des actions en visibles et menu, et affichage du bouton "plus"

    final visibleIcons = allActions.take(finalVisibleCount).toList();
    final menuItems = allActions.skip(finalVisibleCount).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icônes visibles
        ...visibleIcons.map((action) => IconButton(
          onPressed: action.onPressed,
          // ⬅️ CORRECTION : Cloner l'icône avec la nouvelle couleur
          icon: _cloneIconWithColor(action.icon, colorIcon),
        )),

        // Bouton "Plus" (trois points) et menu
        RepaintBoundary(
          child: PopupMenuButton<IconTextButton>(
            popUpAnimationStyle: AnimationStyle(curve: Curves.easeInExpo, duration: const Duration(milliseconds: 200)),

            // Bouton 'plus' affiché (sa couleur est définie ici)
            icon: Icon(Icons.more_vert, color: colorIcon),

            itemBuilder: (context) => menuItems.map((action) =>
                PopupMenuItem(
                  value: action,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    // Couleur des icônes dans le menu (blanche si spécifiée, sinon thème)
                    iconColor: colorIcon ?? Theme.of(context).primaryColor,
                    // ⬅️ CORRECTION : Cloner l'icône du menu avec la couleur pour les éléments du menu
                    leading: _cloneIconWithColor(action.icon, colorIcon ?? Theme.of(context).primaryColor),
                    title: Text(action.text),

                    onTap: () {
                      Navigator.pop(context);
                      action.onPressed?.call();
                    },
                  ),
                ),
            ).toList(),
            // Gestion de l'état du menu via GlobalKeyService
            onOpened: () => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(true),
            onSelected: (value) => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false),
            onCanceled: () => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false),
          ),
        )
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
import 'package:flutter/material.dart';
import 'package:jwlife/app/services/global_key_service.dart';
import 'package:jwlife/core/icons.dart';

class ResponsiveAppBarActions extends StatelessWidget {
  final List<IconTextButton> allActions;
  final bool canPop;
  final Color? iconsColor;

  const ResponsiveAppBarActions({
    super.key,
    required this.allActions,
    this.canPop = true,
    this.iconsColor
  });

  // Fonction utilitaire pour cloner l'icône et appliquer la couleur
  Icon _cloneIconWithColor(Icon icon, Color? color) {
    return Icon(
      icon.icon,
      size: icon.size,
      color: color,
      semanticLabel: icon.semanticLabel,
      textDirection: icon.textDirection,
      key: icon.key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // 1. Déterminer le nombre d'icônes visibles basé sur la largeur de l'écran (avec un plafond)
    int baseVisibleCount = canPop ? 2 : 3; // Par défaut: 2 icônes (Compact <= 600)

    if (screenWidth > 900) {
      baseVisibleCount = canPop ? 5 : 6;
    } else if (screenWidth > 750) {
      baseVisibleCount = canPop ? 4 : 5;
    } else if (screenWidth > 600) {
      baseVisibleCount = canPop ? 3 : 4;
    }

    // Assurer que le nombre calculé ne dépasse pas le nombre réel d'actions disponibles
    final finalVisibleCount = baseVisibleCount.clamp(0, allActions.length);

    // 2. CAS SIMPLE: Si le nombre total d'actions ne dépasse pas le nombre que l'on a calculé pour l'écran actuel, on les affiche toutes SANS menu.
    if (finalVisibleCount >= allActions.length) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: allActions.map((action) => Builder(
            builder: (anchorContext) { // Crée le context spécifique de l'IconButton
              return IconButton(
                // L'onPressed appelle la fonction stockée en lui passant l'anchorContext
                onPressed: () => action.onPressed?.call(anchorContext),
                icon: _cloneIconWithColor(action.icon, iconsColor),
                visualDensity: VisualDensity.compact,
              );
            }
        )).toList(),
      );
    }

    // 3. CAS COMPLEXE: Division des actions en visibles et menu, et affichage du bouton "plus"

    final visibleIcons = finalVisibleCount == allActions.length - 1 ? allActions.toList() : allActions.take(finalVisibleCount).toList();
    final menuItems = finalVisibleCount == allActions.length - 1 ? allActions.skip(finalVisibleCount+1).toList() : allActions.skip(finalVisibleCount).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icônes visibles
        // --- MODIFICATION ICI : Envelopper l'IconButton dans un Builder ---
        ...visibleIcons.map((action) => Builder(
            builder: (anchorContext) { // Crée le context spécifique de l'IconButton
              return IconButton(
                // L'onPressed appelle la fonction stockée en lui passant l'anchorContext
                onPressed: () => action.onPressed?.call(anchorContext),
                visualDensity: VisualDensity.compact,
                icon: _cloneIconWithColor(action.icon, iconsColor),
              );
            }
        )),

        // Bouton "Plus" (trois points) et menu
        menuItems.isEmpty ? const SizedBox.shrink() : RepaintBoundary(
          child: RepaintBoundary(
            child: PopupMenuButton<IconTextButton>(
              style: ButtonStyle(visualDensity: VisualDensity.compact),
              popUpAnimationStyle: AnimationStyle(curve: Curves.easeInExpo, duration: const Duration(milliseconds: 200)),
            
              // Bouton 'plus' affiché (sa couleur est définie ici)
              icon: Icon(JwIcons.three_dots_horizontal, color: iconsColor),
            
              itemBuilder: (context) => menuItems.map((action) =>
                  PopupMenuItem(
                    value: action,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      // Couleur des icônes dans le menu (blanche si spécifiée, sinon thème)
                      iconColor: iconsColor ?? Theme.of(context).primaryColor,
                      // ⬅️ CORRECTION : Cloner l'icône du menu avec la couleur pour les éléments du menu
                      leading: _cloneIconWithColor(action.icon, Theme.of(context).primaryColor),
                      title: Text(action.text ?? 'No text'),
            
                      trailing: action.onSwitchChange != null && action.isSwitch != null ? Switch(
                          value: action.isSwitch!,
                          onChanged: (value) {
                            action.onSwitchChange?.call(value);
                            Navigator.pop(context);
                          }) : null,
            
                      onTap: () {
                        Navigator.pop(context);
                        // Ici on peut utiliser le 'context' de l'item du menu (qui est suffisant pour le onPressed)
                        action.onPressed?.call(context);
                      },
                    ),
                  ),
              ).toList(),
              // Gestion de l'état du menu via GlobalKeyService
              onOpened: () => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(true),
              onSelected: (value) => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false),
              onCanceled: () => GlobalKeyService.jwLifePageKey.currentState!.togglePopMenuOpen(false),
            ),
          ),
        )
      ],
    );
  }
}

class IconTextButton {
  final String? text;
  final Icon icon;
  // Définition correcte de la fonction qui accepte un BuildContext
  final void Function(BuildContext context)? onPressed;
  final bool? isSwitch;
  final ValueChanged<bool>? onSwitchChange;

  const IconTextButton({
    this.text,
    required this.icon,
    this.onPressed,
    this.isSwitch,
    this.onSwitchChange,
  });
}
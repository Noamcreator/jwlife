import 'package:flutter/material.dart';

Widget getLoadingWidget(Color color) {
  return FastLoadingWidget(color: color);
}

class FastLoadingWidget extends StatefulWidget {
  final Color color;
  // 800ms = Rapide mais fluide.
  // Si c'est encore trop lent pour toi, descends à 500ms.
  final Duration duration;

  const FastLoadingWidget({
    super.key,
    required this.color,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<FastLoadingWidget> createState() => _FastLoadingWidgetState();
}

class _FastLoadingWidgetState extends State<FastLoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(); // Le repeat() sur un controller sans courbe spécifique est déjà linéaire
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 45,
        height: 45,
        child: RotationTransition(
          // On utilise directement le controller pour garder la vitesse constante
          turns: _controller,
          child: CircularProgressIndicator(
            color: widget.color,
            strokeWidth: 5,
            // IMPORTANT : Fixer la valeur à 0.7 (ou autre) crée un cercle partiel
            // fixe qui tourne. C'est ça qui donne l'effet de vitesse constante.
            value: 0.7,
          ),
        ),
      ),
    );
  }
}
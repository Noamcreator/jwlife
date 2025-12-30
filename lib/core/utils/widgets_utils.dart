import 'package:flutter/material.dart';

Widget getLoadingWidget(Color color) {
  return FastLoadingWidget(color: color);
}

class FastLoadingWidget extends StatefulWidget {
  final Color color;
  final Duration duration; // vitesse

  const FastLoadingWidget({
    super.key,
    required this.color,
    this.duration = const Duration(milliseconds: 800), // plus petit = plus rapide
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
    )..repeat(); // rotation continue
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
          turns: _controller,
          child: CircularProgressIndicator(
            color: widget.color,
            strokeWidth: 5,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class MultiValueListenableBuilder extends StatelessWidget {
  final List<ValueNotifier<bool>> listenables;
  final Widget Function(BuildContext context) builder;

  const MultiValueListenableBuilder({
    super.key,
    required this.listenables,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) => builder(context),
    );
  }
}
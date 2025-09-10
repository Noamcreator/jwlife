import 'package:flutter/material.dart';

class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> builders;

  /// Liste des index à charger immédiatement dès le démarrage
  final List<int> initialIndexes;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
    this.initialIndexes = const [],
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<bool> _isBuilt;
  late List<Widget?> _pages;

  @override
  void initState() {
    super.initState();

    _isBuilt = List.generate(
      widget.builders.length,
          (i) => i == widget.index || widget.initialIndexes.contains(i),
    );

    _pages = List.generate(
      widget.builders.length,
          (i) => _isBuilt[i] ? widget.builders[i](context) : null,
    );
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si le nombre de builders change, on réinitialise
    if (widget.builders.length != oldWidget.builders.length) {
      _isBuilt = List.generate(
        widget.builders.length,
            (i) => i == widget.index || widget.initialIndexes.contains(i),
      );

      _pages = List.generate(
        widget.builders.length,
            (i) => _isBuilt[i] ? widget.builders[i](context) : null,
      );
    } else {
      // Sinon on ne construit que l’index demandé si pas encore construit
      if (!_isBuilt[widget.index]) {
        _isBuilt[widget.index] = true;
        _pages[widget.index] = widget.builders[widget.index](context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(
        widget.builders.length,
            (i) => _isBuilt[i] ? _pages[i]! : const SizedBox.shrink(),
      ),
    );
  }
}

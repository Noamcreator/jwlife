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
    this.initialIndexes = const [], // Par défaut rien de plus
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

    // Initialise les pages construites selon index et initialIndexes
    _isBuilt = List.generate(
      widget.builders.length,
          (i) => i == widget.index || widget.initialIndexes.contains(i),
    );

    _pages = List.filled(widget.builders.length, null);

    for (int i = 0; i < _isBuilt.length; i++) {
      if (_isBuilt[i]) {
        _pages[i] = widget.builders[i](context);
      }
    }
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isBuilt[widget.index]) {
      _isBuilt[widget.index] = true;
      _pages[widget.index] = widget.builders[widget.index](context);
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

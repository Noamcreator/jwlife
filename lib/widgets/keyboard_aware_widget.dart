import 'package:flutter/material.dart';

class KeyboardSensitiveWidget extends StatefulWidget {
  final double keyboardHeight;
  const KeyboardSensitiveWidget({super.key, required this.keyboardHeight});

  @override
  State<KeyboardSensitiveWidget> createState() => _KeyboardSensitiveWidgetState();
}

class _KeyboardSensitiveWidgetState extends State<KeyboardSensitiveWidget> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.keyboardHeight,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.blue,
        height: 50,
        child: Text("Barre visible au-dessus du clavier"),
      ),
    );
  }
}
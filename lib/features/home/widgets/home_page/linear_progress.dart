import 'package:flutter/material.dart';

class LinearProgress extends StatefulWidget {
  const LinearProgress({super.key});

  @override
  State<LinearProgress> createState() => LinearProgressState();
}

class LinearProgressState extends State<LinearProgress> {
  bool _isRefreshing = false;

  bool get isRefreshing => _isRefreshing;

  void startRefreshing() {
    setState(() {
      _isRefreshing = true;
    });
  }

  void stopRefreshing() {
    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isRefreshing ? SizedBox(
      height: 2.5,
      child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor), backgroundColor: Colors.grey[300])
    )
    : const SizedBox(height: 2.5);
  }
}

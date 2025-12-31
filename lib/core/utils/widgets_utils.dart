import 'package:flutter/material.dart';

Widget getLoadingWidget(Color color) {
  return Center(
    child: SizedBox(
      width: 45,
      height: 45,
      // Le RepaintBoundary crée une couche (layer) séparée sur le GPU
      child: RepaintBoundary(
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 5,
        ),
      ),
    ),
  );
}
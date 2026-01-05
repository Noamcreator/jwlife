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

Widget emptyStateWidget(String title, IconData icon) {
  return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 100,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
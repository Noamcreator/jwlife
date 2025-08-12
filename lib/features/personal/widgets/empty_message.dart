import 'package:flutter/material.dart';

Widget buildEmptyMessage(IconData icon, String message) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 50),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 55,
          color: Color(0xFF8e8e8e),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF8e8e8e),
            ),
          ),
        ),
      ],
    ),
  );
}
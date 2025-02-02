import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> showPage(BuildContext context, Widget page) {
  return Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
        return page;
      },
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

void showBottomMessageWithAction(BuildContext context, String message, SnackBarAction? action) {
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      action: action,
      content: Text(message, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? Color(0xFFf1f1f1) : Color(0xFF3c3c3c),
    ),
  );
}

void showBottomMessage(BuildContext context, String message) {
  if(FirebaseAuth.instance.currentUser != null) { // si l'utilisateur n'est pas connecté, ne pas afficher le message
    showBottomMessageWithAction(context, message, null);
  }
}

Future<void> showErrorDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
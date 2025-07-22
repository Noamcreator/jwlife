import 'package:flutter/material.dart';

Future<void> showPage(BuildContext context, Widget page) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Animation d'entrée : fade + slide up
        final enterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        );
        final enterOffset = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return FadeTransition(
              opacity: enterOpacity,
              child: SlideTransition(
                position: enterOffset,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

void showBottomMessageWithActionState(ScaffoldMessengerState messenger, bool isDark, String message, SnackBarAction? action) {
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 2),
      content: Text(message, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      //margin: const EdgeInsets.only(bottom: 60),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? Color(0xFFf1f1f1) : Color(0xFF3c3c3c),
    ),
  );
}

void showBottomMessageWithAction(BuildContext context, String message, SnackBarAction? action) {
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      action: action,
      duration: const Duration(seconds: 2),
      content: Text(message, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      //margin: const EdgeInsets.only(bottom: 60),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? Color(0xFFf1f1f1) : Color(0xFF3c3c3c),
    ),
  );
}

/*
void showBottomMessage(BuildContext context, String message) {
  if(FirebaseAuth.instance.currentUser != null) { // si l'utilisateur n'est pas connecté, ne pas afficher le message
    showBottomMessageWithAction(context, message, null);
  }
}

 */

void showBottomMessage(BuildContext context, String message) {
  showBottomMessageWithAction(context, message, null);
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
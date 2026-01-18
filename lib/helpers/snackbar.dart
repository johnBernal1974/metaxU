import 'package:flutter/material.dart';

class Snackbar {
  static void showSnackbar(BuildContext context, String text) {
    // si ya no está montado o está en transición, puede fallar
    if (!context.mounted) return;

    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

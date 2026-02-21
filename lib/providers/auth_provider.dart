import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'client_provider.dart';
import 'package:apptaxis/models/client.dart';

class MyAuthProvider {
  late final FirebaseAuth _firebaseAuth;
  StreamSubscription<User?>? _authSub;
  bool _navigating = false;

  MyAuthProvider() {
    _firebaseAuth = FirebaseAuth.instance;
  }

  User? getUser() => _firebaseAuth.currentUser;

  // =========================
  // ✅ OTP: enviar y verificar
  // =========================

  /// Envía OTP. (Para Colombia: pásale +57XXXXXXXXXX desde la UI)
  Future<void> sendOtp({
    required String phoneNumberE164, // Ej: +573001234567
    Duration timeout = const Duration(seconds: 60),
    required void Function(String verificationId) onCodeSent,
    void Function()? onAutoVerified,
    void Function(String message)? onError,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumberE164,
        timeout: timeout,

        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android a veces auto-verifica
          try {
            final cred = await _firebaseAuth.signInWithCredential(credential);
            if (cred.user != null) {
              onAutoVerified?.call();
            }
          } catch (_) {
            // silencio: si falla auto, el usuario mete el código manual
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          onError?.call(e.message ?? _getErrorMessage(e.code));
        },

        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          // Puedes guardar este verificationId si quieres
        },
      );
    } catch (e) {
      onError?.call('No se pudo enviar el código. Intenta de nuevo.');
    }
  }

  /// Verifica OTP e inicia sesión (crea/usa el user de Firebase Auth).
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // =========================
  // ✅ Navegación según estado
  // =========================

  void checkIfUserIsLogged(BuildContext? context) {
    if (context == null) return;

    _authSub?.cancel();
    _navigating = false;

    _authSub = _firebaseAuth.authStateChanges().listen((User? user) async {
      if (!context.mounted) return;
      if (_navigating) return;

      // 1) No logueado -> login
      if (user == null) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
        return;
      }

      final clientProvider = ClientProvider();
      final userId = user.uid;

      // 2) Traer el Client (fuente de la verdad)
      final Client? client = await clientProvider.getById(userId);

      if (!context.mounted) return;
      if (_navigating) return;

      if (client == null) {
        // Si no hay documento cliente, manda a login
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
        return;
      }

      // 3) Status bloqueado
      final status = (client.status ?? '').trim();
      if (status == 'bloqueado') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'bloqueo_page', (route) => false);
        return;
      }

      // 4) Foto obligatoria
      final foto = (client.the15FotoPerfilUsuario ?? '').trim();
      final fotoTomada = client.fotoPerfilTomada ?? false;

      if (!fotoTomada || foto.isEmpty || foto == 'rechazada') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'take_foto_perfil', (route) => false);
        return;
      }

      // 5) Pregunta y respuesta obligatorias
      final pregunta = (client.preguntaPalabraClave ?? '').trim();
      final respuesta = (client.palabraClave ?? '').trim();

      if (pregunta.isEmpty || respuesta.isEmpty) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'complete_security', (route) => false);
        return;
      }

      // 6) Viaje o mapa normal
      final isTraveling = client.the00isTraveling;

      _navigating = true;
      if (isTraveling) {
        Navigator.pushNamedAndRemoveUntil(context, 'travel_map_page', (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false);
      }
    });
  }

  // =========================
  // ✅ Sign out
  // =========================

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<bool> isUserLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }

  // =========================
  // Helpers
  // =========================

  String _getErrorMessage(String errorCode) {
    final Map<String, String> errorMessages = {
      'user-not-found': 'Usuario no encontrado.',
      'wrong-password': 'Contraseña incorrecta.',
      'invalid-email': 'Formato de correo inválido.',
      'user-disabled': 'La cuenta ha sido deshabilitada.',
      'invalid-credential': 'Las credenciales no son válidas.',
      'network-request-failed': 'Sin señal. Revisa tu conexión de INTERNET.',
      'email-already-in-use': 'El correo ya está siendo usado.',
      'invalid-verification-code': 'Código OTP incorrecto.',
      'too-many-requests': 'Demasiados intentos. Espera un momento e intenta de nuevo.',
    };

    return errorMessages[errorCode] ?? 'Error desconocido';
  }

  void showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 16)),
      backgroundColor: Colors.black,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void dispose() {
    _authSub?.cancel();
  }
}
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

      /// 1️⃣ NO LOGUEADO
      if (user == null) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
        return;
      }

      final userId = user.uid;

      /// ==============================
      /// 2️⃣ PORTERÍA
      /// ==============================

      final porteriaDoc = await FirebaseFirestore.instance
          .collection("UsuariosPorteria")
          .doc(userId)
          .get();

      if (!context.mounted) return;
      if (_navigating) return;

      if (porteriaDoc.exists) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'home_porteria',
              (route) => false,
        );
        return;
      }

      /// ==============================
      /// 3️⃣ CLIENTE
      /// ==============================

      final clientProvider = ClientProvider();
      final Client? client = await clientProvider.getById(userId);

      if (!context.mounted) return;
      if (_navigating) return;

      if (client == null) {
        await _firebaseAuth.signOut();

        if (!context.mounted) return;
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(context, 'register', (_) => false);
        return;
      }

      final nombreEstado = (client.nombreEstado ?? '').toLowerCase();

      if (nombreEstado == 'rechazado') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'corregir_nombre',
              (route) => false,
          arguments: {
            'mensaje': 'Tu nombre no es válido. Por favor ingresa tu nombre real.',
          },
        );
        return;
      }

      /// ==============================
      /// 🔥 1. VALIDAR SI FALTAN FOTOS (PRIMERO)
      /// ==============================

      final fotoEstado = (client.fotoPerfilEstado ?? '').toLowerCase();
      final fotoUrl = (client.fotoPerfilUrl ?? '').trim();

      if (fotoEstado.isEmpty || fotoUrl.isEmpty) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'take_foto_perfil',
              (route) => false,
        );
        return;
      }

      /// ==============================
      /// 🔥 2. VALIDAR RECHAZOS
      /// ==============================

      final cedulaFront = (client.cedulaFrontalEstado ?? '').toLowerCase();
      final cedulaBack = (client.cedulaReversoEstado ?? '').toLowerCase();

      if (fotoEstado == 'rechazada') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'take_foto_perfil',
              (route) => false,
          arguments: {
            'mensaje': 'Tu foto de perfil fue rechazada. Por favor tómala nuevamente.',
          },
        );
        return;
      }

      if (cedulaFront == 'rechazada') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'upload_cedula',
              (route) => false,
          arguments: {
            'tipo': 'frontal',
            'mensaje':
            'La foto delantera de tu cédula fue rechazada. Verifica que no esté borrosa ni recortada.',
          },
        );
        return;
      }

      if (cedulaBack == 'rechazada') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'upload_cedula',
              (route) => false,
          arguments: {
            'tipo': 'reverso',
            'mensaje':
            'La foto trasera de tu cédula fue rechazada. Verifica que no esté borrosa ni recortada.',
          },
        );
        return;
      }

      /// ==============================
      /// 🔒 3. STATUS (DESPUÉS DE VALIDAR TODO)
      /// ==============================

      final status = (client.status ?? '').trim().toLowerCase();

      if (status == 'registrado' || status == 'procesando') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'verificacion_pendiente',
              (route) => false,
        );
        return;
      }

      if (status == 'bloqueado') {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'bloqueo_page',
              (route) => false,
        );
        return;
      }

      /// ==============================
      /// 🔐 SEGURIDAD
      /// ==============================

      final pregunta = (client.preguntaPalabraClave ?? '').trim();
      final respuesta = (client.palabraClave ?? '').trim();

      if (pregunta.isEmpty || respuesta.isEmpty) {
        _navigating = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          'complete_security',
              (route) => false,
        );
        return;
      }

      /// ==============================
      /// 🚗 MAPA
      /// ==============================

      final isTraveling = client.isTraveling;

      _navigating = true;

      if (isTraveling) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          'travel_map_page',
              (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          'map_client',
              (route) => false,
        );
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
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../helpers/snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';

class LoginController {
  late BuildContext context;
  late Function refresh;

  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;

  // Controllers
  final TextEditingController celularController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  // Focus (opcional si lo quieres)
  final FocusNode celularFocusNode = FocusNode();
  final FocusNode otpFocusNode = FocusNode();

  // OTP
  String? _verificationId;
  bool otpEnviado = false;
  bool otpVerificado = false;

  // UI states
  bool sendingOtp = false;
  bool verifyingOtp = false;

  // Errores
  String? celularError;
  String? otpError;

  // Cooldowns
  Timer? _resendTimer;
  int resendSeconds = 0;
  static const int resendCooldown = 30;

  Timer? _deviceBlockTimer;
  int deviceBlockSeconds = 0;
  static const int deviceBlockCooldown = 120;

  bool get canResend => !sendingOtp && resendSeconds == 0;
  bool get deviceBlocked => deviceBlockSeconds > 0;
  bool get isOtpComplete => otpController.text.trim().length == 6;

  Future<void> init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
  }

  void dispose() {
    celularController.dispose();
    otpController.dispose();
    celularFocusNode.dispose();
    otpFocusNode.dispose();
    _resendTimer?.cancel();
    _deviceBlockTimer?.cancel();
  }

  // =========================
  // Helpers
  // =========================
  String _normalizeCel10(String raw) => raw.replaceAll(RegExp(r'\D'), '');
  String _toE164Colombia(String cel10) => '+57$cel10';

  String _maskNumber(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return number;
    return digits.replaceRange(3, digits.length - 3, '****');
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    resendSeconds = resendCooldown;
    refresh();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendSeconds <= 1) {
        t.cancel();
        resendSeconds = 0;
      } else {
        resendSeconds--;
      }
      refresh();
    });
  }

  void _startDeviceBlockCooldown() {
    _deviceBlockTimer?.cancel();
    deviceBlockSeconds = deviceBlockCooldown;
    refresh();

    _deviceBlockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (deviceBlockSeconds <= 1) {
        t.cancel();
        deviceBlockSeconds = 0;
      } else {
        deviceBlockSeconds--;
      }
      refresh();
    });
  }

  // =========================
  // SEND OTP
  // =========================
  Future<void> enviarOtp() async {
    if (sendingOtp || deviceBlocked) return;

    celularError = null;
    otpError = null;
    otpVerificado = false;
    refresh();

    final cel10 = _normalizeCel10(celularController.text);
    if (cel10.isEmpty) {
      celularError = "Por favor ingresa tu número de celular.";
      refresh();
      return;
    }
    if (cel10.length != 10) {
      celularError = "Este número de celular NO es válido.";
      refresh();
      return;
    }

    sendingOtp = true;
    refresh();

    Timer? failSafe;
    void stopLoading() {
      failSafe?.cancel();
      sendingOtp = false;
      refresh();
    }

    // failsafe
    failSafe = Timer(const Duration(seconds: 25), () {
      otpError = "No pudimos enviar el código. Intenta de nuevo.";
      sendingOtp = false;
      refresh();
    });

    try {
      final phone = _toE164Colombia(cel10);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) async {
          // A veces Android auto-verifica
          try {
            final cred = await FirebaseAuth.instance.signInWithCredential(credential);
            final user = cred.user;
            if (user == null) {
              stopLoading();
              return;
            }

            stopLoading();
            otpEnviado = true;
            otpVerificado = true;
            otpError = null;
            refresh();

            await _entrarSiExiste(user);
          } catch (_) {
            stopLoading();
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          stopLoading();

          String msg;
          if (e.code == 'too-many-requests') {
            msg =
            "Por seguridad, se bloqueó temporalmente el envío de códigos en este dispositivo.\nIntenta de nuevo más tarde.";
            _startDeviceBlockCooldown();
          } else {
            msg = e.message ?? "No se pudo enviar el código. Intenta de nuevo.";
          }

          otpError = msg;
          refresh();

          if (kDebugMode) {
            print("❌ verificationFailed: ${e.code} | ${e.message}");
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          stopLoading();

          _verificationId = verificationId;
          otpEnviado = true;
          otpError = null;

          // Limpia OTP anterior por si era reintento
          otpController.clear();
          otpVerificado = false;

          _startResendCooldown();
          refresh();

          // fuerza enfoque OTP (opcional)
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!context.mounted) return;
            FocusScope.of(context).requestFocus(otpFocusNode);
          });
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          stopLoading();
          _verificationId = verificationId;
          if (kDebugMode) {
            print("⏳ codeAutoRetrievalTimeout: $verificationId");
          }
        },
      );
    } catch (e) {
      stopLoading();
      otpError = "Error enviando OTP. Intenta nuevamente.";
      refresh();

      if (kDebugMode) {
        print("❌ Exception verifyPhoneNumber: $e");
      }
    }
  }

  // =========================
  // VERIFY OTP + LOGIN
  // =========================
  Future<void> verificarOtpYEntrar() async {
    if (verifyingOtp) return;

    otpError = null;
    refresh();

    final code = otpController.text.trim();

    if (code.length != 6) {
      otpError = "Ingresa el código de 6 dígitos.";
      refresh();
      return;
    }

    if (_verificationId == null) {
      otpError = "Primero solicita el código OTP.";
      refresh();
      return;
    }

    verifyingOtp = true;
    refresh();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;

      if (user == null) {
        otpError = "No se pudo verificar el código.";
        otpVerificado = false;
        return;
      }

      otpVerificado = true;
      otpError = null;
      refresh();

      await _entrarSiExiste(user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        otpError = "Código incorrecto. Intenta de nuevo.";
      } else if (e.code == 'session-expired') {
        otpError = "El código expiró. Solicita uno nuevo.";
      } else if (e.code == 'too-many-requests') {
        otpError = "Demasiados intentos. Espera un momento e intenta de nuevo.";
      } else {
        otpError = e.message ?? "No se pudo verificar el código.";
      }
      otpVerificado = false;
      refresh();
    } catch (_) {
      otpError = "No se pudo verificar el código. Intenta de nuevo.";
      otpVerificado = false;
      refresh();
    } finally {
      verifyingOtp = false;
      refresh();
    }
  }

  // =========================
  // Entrar si existe en Firestore
  // =========================
  Future<void> _entrarSiExiste(User user) async {
    final existing = await _clientProvider.getById(user.uid);

    if (!context.mounted) return;

    if (existing == null) {
      // 🔴 No existe en tu Firestore: NO lo dejes entrar por login
      Snackbar.showSnackbar(
        key.currentContext!,
        "Este número no está registrado. Regístrate primero.",
      );
      return;
    }

    // ✅ Existe: entra al flujo normal (foto/mapa/etc)
    Snackbar.showSnackbarNegro(
      key.currentContext!,
      "Ingresando...",
    );

    _authProvider.checkIfUserIsLogged(context);
  }

  // =========================
  // UI helpers
  // =========================
  void resetOtpFlow() {
    _verificationId = null;
    otpEnviado = false;
    otpVerificado = false;
    otpError = null;
    otpController.clear();
    refresh();
  }
}
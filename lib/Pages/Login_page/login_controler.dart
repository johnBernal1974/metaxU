import 'package:flutter/material.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import 'package:apptaxis/models/client.dart';

import '../../helpers/session_manager.dart';
import '../../helpers/snackbar.dart';

class LoginController {
  late BuildContext context;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  // ✅ Solo OTP
  final TextEditingController celularController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;

  String? _verificationId;
  bool otpEnviado = false;
  bool isSendingOtp = false;
  bool isVerifyingOtp = false;

  late VoidCallback refresh;

  Future? init(BuildContext context, VoidCallback refresh) {
    this.context = context;
    this.refresh = refresh;
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
    return null;
  }

  void goToRegisterPage() {
    Navigator.pushNamed(context, 'signup');
  }

  // Helpers
  String _normalizeCel10(String raw) => raw.replaceAll(RegExp(r'\D'), '');
  String _toE164Colombia(String cel10) => '+57$cel10';

  Future<void> enviarOtp() async {
    if (isSendingOtp) return;

    final cel10 = _normalizeCel10(celularController.text);

    if (cel10.isEmpty) {
      Snackbar.showSnackbar(context, 'Ingresa tu número de celular');
      return;
    }
    if (cel10.length != 10) {
      Snackbar.showSnackbar(context, 'Este número de celular NO es válido');
      return;
    }

    isSendingOtp = true;

    await _authProvider.sendOtp(
      phoneNumberE164: _toE164Colombia(cel10),
      onCodeSent: (verificationId) {
        _verificationId = verificationId;
        otpEnviado = true;
        isSendingOtp = false;
        refresh();
        Snackbar.showSnackbar(context, 'Te enviamos un código OTP');
      },
      onAutoVerified: () async {
        // Si Android lo verifica solo, intentamos continuar flujo
        isSendingOtp = false;
        otpEnviado = true;
        await _postAuthChecksAndEnter();
      },
      onError: (msg) {
        isSendingOtp = false;
        Snackbar.showSnackbar(context, msg);
      },
    );
  }

  Future<void> verificarOtpYEntrar() async {
    if (isVerifyingOtp) return;

    final code = otpController.text.trim();
    if (!otpEnviado || _verificationId == null) {
      Snackbar.showSnackbar(context, 'Primero solicita el código OTP');
      return;
    }
    if (code.length != 6) {
      Snackbar.showSnackbar(context, 'Ingresa el código de 6 dígitos');
      return;
    }

    isVerifyingOtp = true;

    try {
      final cred = await _authProvider.verifyOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );

      if (cred?.user == null) {
        Snackbar.showSnackbar(context, 'No se pudo verificar el código');
        return;
      }

      await _postAuthChecksAndEnter();
    } catch (e) {
      Snackbar.showSnackbar(context, 'Código incorrecto o expirado.');
    } finally {
      isVerifyingOtp = false;
    }
  }

  /// ✅ Mantiene tu flujo actual: validar client, SessionManager, then checkIfUserIsLogged
  Future<void> _postAuthChecksAndEnter() async {
    final user = _authProvider.getUser();
    if (user == null) {
      Snackbar.showSnackbar(context, 'Sesión inválida. Intenta de nuevo.');
      return;
    }

    final uid = user.uid;
    Client? client = await _clientProvider.getById(uid);

    // Si no existe doc Client -> NO pertenece
    if (client == null) {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Acceso denegado'),
          content: const Text(
            'Este usuario no pertenece a la aplicación. '
                'Si crees que es un error, contacta al soporte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      await _authProvider.signOut();
      return;
    }

    // Session Guard (igual que antes)
    try {
      await SessionManager.loginGuard(collection: 'Clients');
    } catch (e) {
      if (context.mounted) {
        Snackbar.showSnackbar(
          context,
          'Este usuario ya está logueado en otro dispositivo. '
              'Por favor, cierre sesión allá o espere unos minutos.',
        );
      }
      await _authProvider.signOut();
      return;
    }

    SessionManager.startHeartbeat(collection: 'Clients');

    if (context.mounted) {
      _authProvider.checkIfUserIsLogged(context);
    }
  }

  Future<void> cerrarSesion() async {
    await _authProvider.signOut();
  }

  void dispose() {
    celularController.dispose();
    otpController.dispose();
  }
}
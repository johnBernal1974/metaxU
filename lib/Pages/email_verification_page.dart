import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../src/colors/colors.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  EmailVerificationPageState createState() => EmailVerificationPageState();
}

class EmailVerificationPageState extends State<EmailVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  bool _isEmailVerified = false;

  bool _isSendingVerification = false;

  // ✅ cooldown PRO
  static const int _cooldownSeconds = 45;
  int _cooldownLeft = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;

    // ✅ si por alguna razón no hay usuario, manda a login
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
      });
      return;
    }

    _checkEmailVerification().then((isVerified) {
      if (!isVerified) {
        _sendVerificationEmail(); // auto-envío
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _cooldownSeconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownLeft <= 1) {
        t.cancel();
        setState(() => _cooldownLeft = 0);
      } else {
        setState(() => _cooldownLeft--);
      }
    });
  }

  // ✅ Verificar si el correo ya ha sido verificado
  Future<bool> _checkEmailVerification() async {
    try {
      await _currentUser?.reload();
      _currentUser = _auth.currentUser;

      final isVerified = _currentUser?.emailVerified ?? false;

      if (!mounted) return isVerified;

      setState(() {
        _isEmailVerified = isVerified;
      });

      if (isVerified && mounted) {
        Navigator.pushReplacementNamed(context, 'splash');
      }

      return isVerified;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pude verificar el correo. Revisa tu conexión e intenta de nuevo.')),
      );
      return false;
    }
  }

  // ✅ Enviar correo de verificación (con cooldown y manejo de errores)
  Future<void> _sendVerificationEmail() async {
    if (_isSendingVerification) return;
    if (_cooldownLeft > 0) return;

    setState(() {
      _isSendingVerification = true;
    });

    try {
      await _currentUser?.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo de verificación enviado. Revisa tu bandeja de entrada.')),
      );

      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final msg = (e.code == 'too-many-requests')
          ? 'Has solicitado demasiados correos. Espera un momento e intenta de nuevo.'
          : 'No se pudo enviar el correo. Intenta nuevamente.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el correo. Intenta nuevamente.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingVerification = false);
      }
    }
  }

  // ✅ Botón PRO: "Ya verifiqué mi correo"
  Future<void> _onIAlreadyVerifiedPressed() async {
    final ok = await _checkEmailVerification();

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no aparece verificado. Abre tu correo y toca el enlace, luego intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Confirmación de Correo",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: _isEmailVerified
            ? const CircularProgressIndicator()
            : Container(
          margin: const EdgeInsets.only(left: 30, right: 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  'assets/email_enviado.png',
                  height: 70,
                  width: 70,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Hemos enviado el link de confirmación al correo:',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                const Text(
                  'Es indispensable que verifiques tu email para poder ingresar a la aplicación',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: grisMedio),
                const SizedBox(height: 20),
                const Text(
                  '¿No recibiste el correo?',
                  style: TextStyle(fontSize: 16, color: negro, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ✅ Reenviar PRO
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isSendingVerification || _cooldownLeft > 0)
                        ? null
                        : _sendVerificationEmail,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(primary),
                      foregroundColor: MaterialStateProperty.all(Colors.black),
                    ),
                    child: _isSendingVerification
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                        : Text(
                      _cooldownLeft > 0
                          ? 'Reenviar en $_cooldownLeft s'
                          : 'Reenviar correo de verificación',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ Ya verifiqué PRO
                TextButton(
                  onPressed: _onIAlreadyVerifiedPressed,
                  child: const Text(
                    'Ya verifiqué mi correo',
                    style: TextStyle(color: gris, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

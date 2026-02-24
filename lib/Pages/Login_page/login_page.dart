import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../helpers/conectivity_service.dart';
import '../../src/colors/colors.dart';
import 'login_controler.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late LoginController _controller;
  final ConnectionService connectionService = ConnectionService();

  bool _showLoginForm = false;

  final GlobalKey _otpSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context, () {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otpEnviado = _controller.otpEnviado;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: blancoCards,
      key: _controller.key,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text(
          "Ingreso",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: const <Widget>[
          Image(
            height: 40.0,
            width: 100.0,
            image: AssetImage('assets/metax_logo.png'),
          )
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: 24 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),

                  // ===========================
                  // Bloque Bienvenido + Registro
                  // ===========================
                  if (!_showLoginForm) ...[
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            "¡Cordial bienvenida!",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              height: 1.1
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          Text(
                            "Crea tu cuenta y conecta con los servicios que necesitas de forma fácil y confiable.",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ BOTÓN REGISTRO
                    SizedBox(
                      width: 300,
                      child: ElevatedButton(
                        onPressed: () async {
                          FocusScope.of(context).unfocus();

                          final hasConnection =
                          await connectionService.hasInternetConnection();

                          if (!hasConnection) {
                            await alertSinInternet();
                            return;
                          }

                          if (!mounted) return;

                          Navigator.pushNamed(context, 'register');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Crear cuenta",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // ===========================
                  // Toggle login form
                  // ===========================
                  GestureDetector(
                    onTap: () {
                      setState(() => _showLoginForm = !_showLoginForm);

                      // ✅ si ocultas el formulario, limpia el flujo OTP
                      if (!_showLoginForm) {
                        _controller.resetOtpFlow();
                      }
                    },
                    child: Column(
                      children: [
                        Text(
                          _showLoginForm
                              ? "Regresar al registro"
                              : "¿Ya tienes cuenta?\nIniciar sesión",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.black54, height: 1),

                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ===========================
                  // FORMULARIO OTP LOGIN
                  // ===========================
                  if (_showLoginForm) ...[
                    const Text(
                      "Iniciar sesión",
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Digita el número de celular con el que creaste tu cuenta",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _controller.celularController,
                        focusNode: _controller.celularFocusNode,
                        enabled: !_controller.sendingOtp,
                        decoration: InputDecoration(
                          labelText: "Número de celular",
                          hintText: "ingresa tu número",
                          errorText: _controller.celularError,
                          prefixIcon: const Icon(Icons.phone, color: primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ✅ BOTÓN ENVIAR OTP (loader dentro + bloqueo por deviceBlocked)
                    SizedBox(
                      width: 300,
                      child: OutlinedButton(
                        onPressed: (_controller.sendingOtp || _controller.deviceBlocked)
                            ? null
                            : () async {
                          FocusScope.of(context).unfocus();

                          final hasConnection =
                          await connectionService.hasInternetConnection();
                          if (!hasConnection) {
                            await alertSinInternet();
                            return;
                          }

                          await _controller.enviarOtp();

                          if (!mounted) return;

                          if (_controller.otpEnviado) {
                            _scrollToOtp();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),

                        // 🔥 UX más pulido
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _controller.sendingOtp
                              ? Row(
                            key: const ValueKey('sending'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _controller.deviceBlocked
                                    ? "Espera ${_controller.deviceBlockSeconds}s"
                                    : "Enviando...",
                                style: const TextStyle(
                                  color: primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                              : Text(
                            key: const ValueKey('idle'),
                            _controller.deviceBlocked
                                ? "Espera ${_controller.deviceBlockSeconds}s"
                                : (otpEnviado
                                ? (_controller.canResend
                                ? "Reenviar código"
                                : "Reenviar en ${_controller.resendSeconds}s")
                                : "Solicitar código"),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ✅ Error OTP (debajo del botón)
                    if (_controller.otpError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _controller.otpError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // ✅ OTP (solo si ya se envió)
                    if (otpEnviado) ...[
                      const SizedBox(height: 6),
                      Align(
                        key: _otpSectionKey,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 320,
                          child: SizedBox(
                            width: 320,
                            child: PinCodeTextField(
                              appContext: context,
                              controller: _controller.otpController,
                              focusNode: _controller.otpFocusNode,
                              autoFocus: false,
                              length: 6,
                              keyboardType: TextInputType.number,
                              autoDisposeControllers: false,
                              enableActiveFill: true,
                              animationType: AnimationType.scale, // 👈 más fluido
                              animationDuration: const Duration(milliseconds: 200),
                              cursorColor: primary,

                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _controller.verifyingOtp ? Colors.black38 : Colors.black87, // 👈 efecto
                              ),

                              onChanged: (_) {
                                if (_controller.otpError != null) {
                                  _controller.otpError = null;
                                  if (mounted) setState(() {});
                                }
                              },

                              onCompleted: (_) async {
                                FocusScope.of(context).unfocus(); // 👈 oculta teclado
                                await Future.delayed(const Duration(milliseconds: 150)); // 👈 suaviza UX

                                final hasConnection =
                                await connectionService.hasInternetConnection();
                                if (!hasConnection) {
                                  await alertSinInternet();
                                  return;
                                }

                                await _controller.verificarOtpYEntrar();
                              },

                              pinTheme: PinTheme(
                                shape: PinCodeFieldShape.box,
                                borderRadius: BorderRadius.circular(12),
                                fieldHeight: 54,
                                fieldWidth: 46,

                                activeColor: primary,
                                selectedColor: primary,
                                inactiveColor: Colors.black12,

                                activeFillColor:
                                _controller.verifyingOtp ? Colors.grey.shade100 : Colors.white, // 👈 efecto
                                selectedFillColor: Colors.white,
                                inactiveFillColor: Colors.white,

                                borderWidth: 1.2,
                              ),

                              enabled: !_controller.verifyingOtp, // 👈 bloquea mientras verifica
                            )
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (_controller.verifyingOtp)
                        const Text(
                          "Verificando código...",
                          style: TextStyle(
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // ✅ BOTÓN INGRESAR (por si no quiere autoverificar)
                      SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: (_controller.verifyingOtp || !_controller.isOtpComplete)
                              ? null
                              : () async {
                            FocusScope.of(context).unfocus();

                            final hasConnection =
                            await connectionService.hasInternetConnection();
                            if (!hasConnection) {
                              await alertSinInternet();
                              return;
                            }

                            await _controller.verificarOtpYEntrar();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                          ),

                          // 🔥 AQUÍ ESTÁ LA MEJORA
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _controller.verifyingOtp
                                ? const SizedBox(
                              key: ValueKey('loading'),
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                                : const Text(
                              key: ValueKey('text'),
                              "Iniciar Sesión",
                              style: TextStyle(fontSize: 18, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToOtp() {
    final ctx = _otpSectionKey.currentContext;
    if (ctx == null) return;

    final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
    final alignment = keyboardHeight > 0 ? 0.3 : 0.5;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: alignment,
    );
  }

  Future alertSinInternet() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Sin Internet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          content:
          const Text('Por favor, verifica tu conexión e inténtalo nuevamente.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  bool _isLoading = false;
  bool _showLoginForm = false;

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
          AbsorbPointer(
            absorbing: _isLoading,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),

                    if (!_showLoginForm) ...[
                      const Center(
                        child: Text(
                          "Bienvenido",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ✅ BOTÓN REGISTRO
                      SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                            FocusScope.of(context).unfocus();
                            setState(() => _isLoading = true);
                            try {
                              final hasConnection =
                              await connectionService.hasInternetConnection();
                              if (!hasConnection) {
                                await alertSinInternet();
                                return;
                              }
                              if (context.mounted) {
                                Navigator.pushNamed(context, 'register');
                              }
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                          child: const Text(
                            "Registrate aquí",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
                    ],

                    const SizedBox(height: 18),

                    // ✅ TEXTO: "¿Ya tienes cuenta?"
                    GestureDetector(
                      onTap: () {
                        setState(() => _showLoginForm = !_showLoginForm);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showLoginForm
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showLoginForm
                                ? "Ocultar inicio de sesión"
                                : "¿Ya tienes cuenta? Inicia sesión",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ✅ FORMULARIO OTP
                    if (_showLoginForm) ...[
                      // ✅ CELULAR
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _controller.celularController,
                          decoration: InputDecoration(
                            labelText: "Número de celular",
                            hintText: "Ej: 3001234567",
                            prefixIcon: const Icon(Icons.phone, color: primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ✅ BOTÓN ENVIAR OTP
                      SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                            FocusScope.of(context).unfocus();
                            setState(() => _isLoading = true);
                            try {
                              final hasConnection =
                              await connectionService.hasInternetConnection();
                              if (!hasConnection) {
                                await alertSinInternet();
                                return;
                              }
                              await _controller.enviarOtp();
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
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
                          child: Text(
                            otpEnviado ? "Reenviar código" : "Enviar código OTP",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ✅ OTP (solo si ya se envió)
                      if (otpEnviado) ...[
                        SizedBox(
                          width: 300,
                          child: TextField(
                            controller: _controller.otpController,
                            decoration: InputDecoration(
                              labelText: "Código OTP (6 dígitos)",
                              prefixIcon: const Icon(Icons.verified, color: primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ✅ BOTÓN INGRESAR
                        SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                              FocusScope.of(context).unfocus();
                              setState(() => _isLoading = true);
                              try {
                                final hasConnection =
                                await connectionService.hasInternetConnection();
                                if (!hasConnection) {
                                  await alertSinInternet();
                                  return;
                                }
                                await _controller.verificarOtpYEntrar();
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                            ),
                            child: const Text(
                              "Iniciar Sesión",
                              style: TextStyle(fontSize: 18, color: Colors.black),
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
          ),

          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
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
          content: const Text('Por favor, verifica tu conexión e inténtalo nuevamente.'),
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
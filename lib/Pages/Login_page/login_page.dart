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
  bool _isPasswordVisible = false;

  bool _showLoginForm = false; //

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blancoCards,
      key: _controller.key,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Registro", style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 20
        ),),
        actions: const <Widget>[
          Image(
              height: 40.0,
              width: 100.0,
              image: AssetImage('assets/metax_logo.png'))
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
                  crossAxisAlignment: CrossAxisAlignment.center, // Alinea al centro horizontalmente
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
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

// ✅ PRIMERO: REGISTRO (siempre visible)
                    SizedBox(
                      width: 300,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                          FocusScope.of(context).unfocus();
                          setState(() => _isLoading = true);
                          try {
                            final hasConnection = await connectionService.hasInternetConnection();
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
                          "Registrarse Ahora",
                          style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),

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
                            _showLoginForm ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showLoginForm ? "Ocultar inicio de sesión" : "¿Ya tienes cuenta? Inicia sesión",
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

// ✅ FORMULARIO DE LOGIN (solo si _showLoginForm == true)
                    if (_showLoginForm) ...[
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _controller.emailController,
                          decoration: InputDecoration(
                            labelText: "Correo electrónico",
                            prefixIcon: const Icon(Icons.email, color: primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _controller.passwordController,
                          decoration: InputDecoration(
                            labelText: "Contraseña",
                            prefixIcon: const Icon(Icons.lock, color: primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                color: Colors.black38,
                              ),
                              onPressed: () {
                                setState(() => _isPasswordVisible = !_isPasswordVisible);
                              },
                            ),
                          ),
                          obscureText: !_isPasswordVisible,
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                            FocusScope.of(context).unfocus();
                            setState(() => _isLoading = true);
                            try {
                              final hasConnection = await connectionService.hasInternetConnection();
                              if (!hasConnection) {
                                await alertSinInternet();
                                return;
                              }
                              await _controller.login();
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

                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: () async {
                          final hasConnection = await connectionService.hasInternetConnection();
                          if (hasConnection) {
                            _controller.goToForgotPassword();
                          } else {
                            alertSinInternet();
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.double_arrow_rounded, color: Colors.black38),
                            SizedBox(width: 8),
                            Text(
                              "Olvidé mi contraseña",
                              style: TextStyle(
                                color: Colors.black38,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future alertSinInternet (){
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sin Internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),),
          content: const Text('Por favor, verifica tu conexión e inténtalo nuevamente.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }
}

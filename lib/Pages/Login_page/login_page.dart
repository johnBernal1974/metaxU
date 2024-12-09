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
        title: const Text("Iniciar sesión", style: TextStyle(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Alinea al centro horizontalmente
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 30), // Espaciado inicial
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
                  const SizedBox(height: 30), // Espaciado después del texto de bienvenida
                  // Campo de correo electrónico.
                  SizedBox(
                    width: 300, // Establece un ancho consistente
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
                  // Campo de contraseña.
                  SizedBox(
                    width: 300, // Establece un ancho consistente
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
                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility ,
                            color: Colors.black38,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible; // Cambiar el estado
                            });
                          },
                        ),
                      ),
                      obscureText: !_isPasswordVisible, // Muestra/oculta la contraseña
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Botón de inicio de sesión.
                  SizedBox(
                    width: 300, // Establece un ancho consistente
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true; // Iniciar el estado de carga
                        });

                        // Verificar la conexión a Internet antes de ejecutar la acción
                        bool hasConnection = await connectionService.hasInternetConnection();

                        setState(() {
                          _isLoading = false; // Terminar el estado de carga
                        });

                        if (hasConnection) {
                          // Si hay conexión, ejecuta la acción de login
                          _controller.login();
                        } else {
                          // Si no hay conexión, muestra un AlertDialog
                          alertSinInternet();
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
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Texto para "Olvidé mi contraseña".
                  GestureDetector(
                    onTap: () async {
                      // Verificar conexión a Internet antes de ejecutar la acción
                      bool hasConnection = await connectionService.hasInternetConnection();

                      if (hasConnection) {
                        // Si hay conexión, ejecuta la acción de ir a "Olvidaste tu contraseña"
                        _controller.goToForgotPassword();
                      } else {
                        // Si no hay conexión, muestra un AlertDialog
                        alertSinInternet();
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Centra horizontalmente
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
                  const SizedBox(height: 40),
                  const Text(
                    "¿No tienes cuenta?",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    textAlign: TextAlign.center, // Centra el texto
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, 'register');
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Centra horizontalmente
                      children: [
                        Icon(Icons.double_arrow, size: 16),
                        Text(
                          "REGISTRATE AQUÍ",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

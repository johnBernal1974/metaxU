import 'package:flutter/material.dart';

import '../../helpers/conectivity_service.dart';
import '../../providers/auth_provider.dart';
import '../../src/colors/colors.dart';
import '../Login_page/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late MyAuthProvider _authProvider;
  final ConnectionService connectionService = ConnectionService();

  @override
  void initState() {
    super.initState();
    _authProvider = MyAuthProvider();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );


    _controller.forward();

    _checkConnectionAndAuthenticate();
  }

  void _checkConnectionAndAuthenticate() async {
    // Verifica la conexión y muestra el Snackbar si no hay conexión
    await connectionService.checkConnectionAndShowCard(context, () async {
      // Esta función se ejecutará solo si hay conexión y el servicio está disponible

      // Verifica si el usuario está logueado
      bool isLoggedIn = await _authProvider.isUserLoggedIn();

      if (isLoggedIn) {
        if(context.mounted){
          _authProvider.checkIfUserIsLogged(context);
        }

      } else {
        // Si no está logueado, navega a la pantalla de login (LoginPage)
        _navigateToLoginPage();
      }
    });
  }
  void _navigateToLoginPage() {
    // Redirige a la página de login
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primary,
      body: Stack(
        children: [
          // Elementos principales al centro de la pantalla.
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/imagen_taxi.png', // Ruta de la imagen.
                    width: 200, // Ancho de la imagen.
                    height: 150, // Altura de la imagen.
                    fit: BoxFit.contain, // Ajuste de la imagen.
                  ),
                ),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/metax_logo.png', // Ruta de la imagen.
                        width: 180, // Ancho de la imagen.
                        height: 180, // Altura de la imagen.
                        fit: BoxFit.contain, // Ajuste de la imagen.
                      ),
                      const SizedBox(height: 5), // Ajusta la separación (5px).
                      const Text(
                        "Un taxi confiable, siempre cerca.",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

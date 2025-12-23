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
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/imagen_splash.png',
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    "¡Porque cada viaje\nes importante!",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),


          // 👇 Texto en la esquina inferior derecha
          const Positioned(
            bottom: 26,
            right: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'En alianza con',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  'ASPRO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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

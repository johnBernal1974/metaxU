import 'package:flutter/material.dart';

import '../../helpers/conectivity_service.dart';
import '../../helpers/session_manager.dart';
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
    await connectionService.checkConnectionAndShowCard(context, () async {
      final isLoggedIn = await _authProvider.isUserLoggedIn();

      if (!isLoggedIn) {
        _navigateToLoginPage();
        return;
      }

      // ✅ Hay sesión en FirebaseAuth, ahora validamos “sesión única” en Firestore
      try {
        await SessionManager.loginGuard(collection: 'Clients');
        //SessionManager.startHeartbeat(collection: 'Clients');

        if (!mounted) return;

        // Aquí envías al flujo normal de tu app (map_client o lo que uses)
        // Si tu método checkIfUserIsLogged decide a dónde ir (cliente/driver), déjalo.
        _authProvider.checkIfUserIsLogged(context);

      } catch (e) {
        SessionManager.stopHeartbeat();
        await _authProvider.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Ya hay una sesión activa')
                  ? 'Tu cuenta ya está abierta en otro dispositivo. Cierra sesión allá o espera 1 minuto e intenta de nuevo.'
                  : 'No se pudo validar tu sesión. Intenta nuevamente.',
            ),
          ),
        );
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
            bottom: 28, // ⬆️ sube 2 px (antes 26)
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'En alianza con',
                    style: TextStyle(
                      fontSize: 13, // ⬆️ +2 px
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ASPROVESPULMETA',
                    style: TextStyle(
                      fontSize: 15, // ⬆️ +2 px
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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

}

import 'package:flutter/material.dart';
import '../../helpers/session_manager.dart';
import '../../providers/auth_provider.dart';
import '../../src/colors/colors.dart';
import '../Login_page/login_page.dart';
import '../../helpers/connection_service_instance.dart';




class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late MyAuthProvider _authProvider;
  //final ConnectionService connectionService = ConnectionService();
  // para mostrar sin internet
  bool _esperandoInternet = false;
  String _msgEstado = '';

  bool _navigated = false;



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

    final isLoggedIn = await _authProvider.isUserLoggedIn();

    if (!isLoggedIn) {
      _navigateToLoginPage();
      return;
    }

    setState(() {
      _esperandoInternet = true;
      _msgEstado = 'Verificando conexión...';
    });

    if (!context.mounted) return;

    final okInternet = await connectionService.hasInternetConnection();

    if (!okInternet) {

      if (context.mounted) {
        connectionService.showPersistentConnectionCard(
          context,
              () {
            if (mounted) _checkConnectionAndAuthenticate();
          },
        );
      }

      if (!mounted) return;

      setState(() {
        _esperandoInternet = true;
        _msgEstado = 'Sin internet. Esperando conexión...';
      });

      return;
    }

    connectionService.hide();

    if (!mounted) return;

    setState(() {
      _esperandoInternet = true;
      _msgEstado = 'Validando sesión...';
    });

    try {

      /// ===================================
      /// 1️⃣ Intentar validar como CLIENTE
      /// ===================================
      try {
        await SessionManager.loginGuard(collection: 'Clients');
      } catch (e) {
        final err = e.toString();

        /// ===================================
        /// 2️⃣ Si no existe en Clients → PORTERIA
        /// ===================================
        if (err.contains('PROFILE_NOT_FOUND')) {
          await SessionManager.loginGuard(collection: 'UsuariosPorteria');
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      setState(() {
        _esperandoInternet = false;
        _msgEstado = '';
      });

      _navigated = true;

      /// Decide navegación final
      _authProvider.checkIfUserIsLogged(context);

    } catch (e) {

      if (!mounted) return;

      final err = e.toString().toLowerCase();

      /// 🔥 1. ERRORES DE RED → NO LOGOUT
      if (err.contains('network') ||
          err.contains('timeout') ||
          err.contains('socket') ||
          err.contains('failed') ||
          err.contains('unavailable') ||
          err.contains('connection')) {

        if (context.mounted) {
          connectionService.showPersistentConnectionCard(
            context,
                () {
              if (mounted) _checkConnectionAndAuthenticate();
            },
          );
        }

        setState(() {
          _esperandoInternet = true;
          _msgEstado =
          'Conexión inestable. Reintentando validar tu sesión...';
        });

        return;
      }

      /// 🔥 2. USUARIO SIN PERFIL
      if (err.contains('profile_not_found')) {

        if (!mounted) return;

        setState(() {
          _esperandoInternet = false;
          _msgEstado = '';
        });

        _navigated = true;

        Navigator.pushNamedAndRemoveUntil(
          context,
          'register',
              (_) => false,
        );

        return;
      }

      /// 🔴 3. ERROR REAL → LOGIN
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err.contains('ya hay una sesión activa')
                ? 'Tu cuenta ya está abierta en otro dispositivo. Cierra sesión allá o espera 1 minuto e intenta de nuevo.'
                : 'No se pudo validar tu sesión. Intenta nuevamente.',
          ),
        ),
      );

      _navigateToLoginPage();
    }
  }

  void _navigateToLoginPage() {
    if (_navigated) return;
    _navigated = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }


  @override
  void dispose() {
    _controller.dispose();
    connectionService.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primary.withOpacity(0.7),
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
                  if (_esperandoInternet) ...[
                    const SizedBox(height: 10),
                    Text(
                      _msgEstado,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ]

                ],
              ),
            ),
          ),


          // 👇 Texto en la esquina inferior derecha
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: true,
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'En alianza con',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ASPROVESPULMETA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

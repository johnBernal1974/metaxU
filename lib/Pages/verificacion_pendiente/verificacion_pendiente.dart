import 'package:flutter/material.dart';
import '../../src/colors/colors.dart';

class VerificacionPendientePage extends StatelessWidget {
  const VerificacionPendientePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // 👈 dejamos que el header llegue arriba
        bottom: true, // 👈 protegemos abajo (gestos)
        child: Column(
          children: [

            /// 🔥 HEADER CON SAFEAREA ARRIBA
            SafeArea(
              top: true,
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: const BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/metax_logo2.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            /// 🔽 CONTENIDO
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    _DotsLoader(),

                    SizedBox(height: 30),

                    Text(
                      "Estamos verificando tu cuenta",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 15),

                    Text(
                      "Nuestro equipo está revisando tu información.\n"
                          "Este proceso puede tardar unos minutos.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 30),

                    Text(
                      "Te notificaremos cuando tu cuenta esté lista.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            /// 🔽 BOTONES ABAJO (YA PROTEGIDOS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, 'splash');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Revisar estado"),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        'login',
                            (route) => false,
                      );
                    },
                    child: const Text(
                      "Cerrar sesión",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final value = (_controller.value + delay) % 1.0;
        final scale = 0.5 + (value * 0.5);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDot(0.0),
        const SizedBox(width: 8),
        _buildDot(0.2),
        const SizedBox(width: 8),
        _buildDot(0.4),
      ],
    );
  }
}
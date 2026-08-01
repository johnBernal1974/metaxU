import 'package:flutter/material.dart';
import '../../src/colors/colors.dart';

class VerificacionPendientePage extends StatelessWidget {
  const VerificacionPendientePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            /// 🚀 HEADER SUPERIOR CON CONTENEDOR OSCURO SOLO PARA EL LOGO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/logo_metax_combinado.png',
                height: 40,
                fit: BoxFit.contain,
              ),
            ),

            /// 🔽 CONTENIDO PRINCIPAL EN TARJETA BLANCA
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// 🖼️ ILUSTRACIÓN MÁS GRANDE Y SIN CÍRCULO
                      SizedBox(
                        height: 160,
                        width: 200,
                        child: Image.asset(
                          'assets/verify_identity.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const Text(
                        "Verificando tu identidad",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        "Hemos recibido tus documentos con éxito. Nuestro equipo se encuentra validando tu información para garantizar una comunidad totalmente segura.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      /// 🔒 INSIGNIA DE SEGURIDAD (PERMITE MÚLTIPLES LÍNEAS)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 18, color: primary),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "Tus datos están protegidos y cifrados",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// 🔽 ACCIONES INFERIORES
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, 'splash');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.black87,
                      minimumSize: const Size(double.infinity, 52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Revisar estado de cuenta",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

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
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
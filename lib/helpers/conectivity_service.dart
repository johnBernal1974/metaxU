// import 'dart:async';
// import 'dart:io'; // Para verificar la conexión a Internet
// import 'package:flutter/material.dart'; // Para el SnackBar
// import 'package:http/http.dart' as http;
//
// class ConnectionService {
//   OverlayEntry? _overlayEntry;
//   bool _isOverlayVisible = false; // Estado para manejar la visibilidad del Card
//
//   // Verificar si hay conexión a Internet
//   Future<bool> hasInternetConnection() async {
//     try {
//       final result = await InternetAddress.lookup('google.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException catch (_) {
//       return false;
//     }
//   }
//
//   // Verificar si el servicio está disponible
//   Future<bool> isServiceAvailable() async {
//     try {
//       final response = await http.get(Uri.parse('https://www.google.com'));
//       return response.statusCode == 200;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   // Mostrar un Card persistente en la parte superior hasta que se recupere la conexión
//   void showPersistentConnectionCard(BuildContext context, VoidCallback onConnectionRestored) {
//     if (_isOverlayVisible) return; // Evitar mostrar el Card si ya está visible
//
//     // Crear el OverlayEntry para el Card
//     _overlayEntry = OverlayEntry(
//       builder: (context) => Positioned(
//         top: MediaQuery.of(context).padding.top + 10,
//         left: MediaQuery.of(context).size.width * 0.15, // Ajuste para centrar el Card
//         width: MediaQuery.of(context).size.width * 0.7, // Cambia el ancho a 70% del ancho de pantalla
//         child: Material(
//           color: Colors.transparent,
//           child: Card(
//             color: Colors.redAccent.shade200,
//             elevation: 5,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//             child: const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), // Reduce el padding
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.wifi_off, color: Colors.white, size: 20), // Tamaño del icono más pequeño
//                   SizedBox(width: 6), // Reduce el espacio entre icono y texto
//                   Text(
//                     'Sin Internet.',
//                     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), // Reduce el tamaño del texto
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//
//     // Insertar el OverlayEntry
//     Overlay.of(context).insert(_overlayEntry!);
//     _isOverlayVisible = true;
//
//     // Comenzar a verificar la conexión periódicamente
//     Timer.periodic(const Duration(seconds: 2), (timer) async {
//       if (await hasInternetConnection()) {
//         // Cerrar el Card si la conexión se restableció
//         _overlayEntry?.remove();
//         _overlayEntry = null;
//         _isOverlayVisible = false;
//         onConnectionRestored(); // Llama al callback
//         timer.cancel(); // Detener el temporizador
//       }
//     });
//   }
//
//
//   // Método principal para verificar conexión y mostrar el Card si no hay internet
//   Future<void> checkConnectionAndShowCard(BuildContext context, VoidCallback onConnectionRestored) async {
//     if (await hasInternetConnection()) {
//       // Verificar si el servicio está disponible solo si hay conexión
//       if (await isServiceAvailable()) {
//         onConnectionRestored(); // Llama al callback
//       } else {
//         if(context.mounted){
//           showPersistentConnectionCard(context, onConnectionRestored);
//         }
//       }
//     } else {
//       if(context.mounted){
//         showPersistentConnectionCard(context, onConnectionRestored);
//       }
//     }
//   }
// }

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectionService {
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;

  StreamSubscription<ConnectivityResult>? _sub;

  /// ✅ “Internet real”: intenta un request liviano con timeout.
  /// (Esto funciona en mobile y web)
  Future<bool> hasInternetConnection() async {
    try {
      final uri = Uri.parse('https://www.google.com/generate_204');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void showPersistentConnectionCard(
      BuildContext context,
      VoidCallback onConnectionRestored,
      ) {
    if (_isOverlayVisible) return;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 0,
        right: 0,
        child: const _MiniNoInternetBanner(),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isOverlayVisible = true;

    _sub?.cancel();

    _sub = Connectivity().onConnectivityChanged.listen((_) async {
      final ok = await hasInternetConnection();
      if (!ok) return;

      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOverlayVisible = false;

      onConnectionRestored();
      await _sub?.cancel();
      _sub = null;
    });
  }


  /// ✅ Método principal (lo llamas desde cualquier pantalla)
  Future<void> checkConnectionAndShowCard(
      BuildContext context,
      VoidCallback onConnectionRestored,
      ) async {
    final ok = await hasInternetConnection();
    if (ok) {
      onConnectionRestored();
      return;
    }

    if (context.mounted) {
      showPersistentConnectionCard(context, onConnectionRestored);
    }
  }

  /// ✅ Limpieza (para evitar listeners colgados)
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOverlayVisible = false;
  }
}

class _MiniNoInternetBanner extends StatefulWidget {
  const _MiniNoInternetBanner();

  @override
  State<_MiniNoInternetBanner> createState() => _MiniNoInternetBannerState();
}

class _MiniNoInternetBannerState extends State<_MiniNoInternetBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  late final Animation<double> _fade =
  CurvedAnimation(parent: _c, curve: Curves.easeOut);

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sin Internet',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(width: 8),
                  const _DotsLoaderMini(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsLoaderMini extends StatefulWidget {
  const _DotsLoaderMini();

  @override
  State<_DotsLoaderMini> createState() => _DotsLoaderMiniState();
}

class _DotsLoaderMiniState extends State<_DotsLoaderMini>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t + i * 0.2) % 1;
            final scale = 0.6 + (0.6 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0));

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}


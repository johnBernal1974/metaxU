
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectionService {
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;

  StreamSubscription<ConnectivityResult>? _sub;
  Timer? _pollTimer;

  /// ✅ “Internet real”: intenta un request liviano con timeout.

  Future<bool> hasInternetConnection() async {
    // Endpoints livianos y confiables (204/200)
    final urls = <String>[
      'https://www.google.com/generate_204',
      'https://www.cloudflare.com/cdn-cgi/trace', // suele responder 200
      'https://www.apple.com/library/test/success.html', // 200
    ];

    for (final u in urls) {
      try {
        final uri = Uri.parse(u);
        final res = await http.get(uri).timeout(const Duration(seconds: 3));

        if (res.statusCode == 204 || res.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // intenta el siguiente
      }
    }

    return false;
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

    // ✅ Cancela anteriores
    _sub?.cancel();
    _pollTimer?.cancel();

    // ✅ 1) Listener por cambios de conectividad
    _sub = Connectivity().onConnectivityChanged.listen((_) async {
      final ok = await hasInternetConnection();
      if (!ok) return;

      hide();               // ✅ limpia todo
      onConnectionRestored();
    });

    // ✅ 2) Poll mientras el banner esté visible (para casos sin eventos)
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_isOverlayVisible) return;
      final ok = await hasInternetConnection();
      if (!ok) return;

      hide();               // ✅ limpia todo
      onConnectionRestored();
    });
  }


  /// ✅ Método principal (lo llamas desde cualquier pantalla)
  Future<void> checkConnectionAndShowCard(
      BuildContext context,
      VoidCallback onConnectionRestored,
      ) async {
    final ok = await hasInternetConnection();
    if (ok) {
      hide();
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
    hide();
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    _pollTimer?.cancel();
    _pollTimer = null;

    _sub?.cancel();
    _sub = null;

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


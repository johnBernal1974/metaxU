import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../src/colors/colors.dart';

class EliminarCuentaPage extends StatelessWidget {
  const EliminarCuentaPage({super.key});

  static final Uri _url = Uri.parse('https://metax.com.co/baja.html');

  Future<void> _abrirLink() async {
    final ok = await launchUrl(
      _url,
      mode: LaunchMode.externalApplication, // ✅ navegador real, cero crash
    );
    if (!ok) {
      throw 'No se pudo abrir el enlace';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text(
          "Eliminar cuenta",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: const <Widget>[
          Image(
            height: 40.0,
            width: 100.0,
            image: AssetImage('assets/metax_logo.png'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Al dar click en el siguiente botón tendras toda la información necesaria para la eliminación de tu cuenta.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            const Text(
              "Se abrirá en tu navegador.",
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  try {
                    await _abrirLink();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No se pudo abrir el enlace.")),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_browser, color: Colors.black),
                label: const Text(
                  "Ver información",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
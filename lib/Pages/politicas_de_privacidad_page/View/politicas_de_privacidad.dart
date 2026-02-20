import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../src/colors/colors.dart';

class PoliticasDePrivacidadPage extends StatelessWidget {
  const PoliticasDePrivacidadPage({super.key});

  static final Uri _url = Uri.parse('https://metax.com.co/privacidad.html');

  Future<void> _abrirLink() async {
    final ok = await launchUrl(
      _url,
      mode: LaunchMode.externalApplication, // ✅ estable (sin WebView)
    );
    if (!ok) throw 'No se pudo abrir el enlace';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blancoCards,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text(
          "Políticas de Privacidad",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
              "Puedes consultar nuestras Políticas de Privacidad en el siguiente enlace.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
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
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No se pudo abrir el enlace.")),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_browser, color: Colors.black),
                label: const Text(
                  "Abrir Políticas de Privacidad",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../helpers/header_text.dart';
import '../../../src/colors/colors.dart';

class PoliticasDePrivacidadPage extends StatefulWidget {
  const PoliticasDePrivacidadPage({super.key});

  @override
  State<PoliticasDePrivacidadPage> createState() => _PoliticasDePrivacidadPageState();
}

class _PoliticasDePrivacidadPageState extends State<PoliticasDePrivacidadPage> {
  double _progress = 0;
  late InAppWebViewController inAppWebViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blancoCards,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Políticas de Privacidad", style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16
        ),),
        actions: const <Widget>[
          Image(
              height: 40.0,
              width: 100.0,
              image: AssetImage('assets/metax_logo.png'))
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: Uri.parse('https...'),
            ),
            onWebViewCreated: (InAppWebViewController controller){
              inAppWebViewController = controller;
            },
            onProgressChanged:(InAppWebViewController controller, int progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
          ),
          _progress < 1 ? LinearProgressIndicator(
            backgroundColor: primary,
            minHeight: 8,
            value: _progress,
          ): const SizedBox()
        ],
      ),
    );
  }
}

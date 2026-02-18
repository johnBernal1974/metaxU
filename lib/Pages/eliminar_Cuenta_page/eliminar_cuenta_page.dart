
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../helpers/header_text.dart';
import '../../src/colors/colors.dart';

class EliminarCuentaPage extends StatefulWidget {
  const EliminarCuentaPage({super.key});

  @override
  State<EliminarCuentaPage> createState() => _EliminarCuentaPageState();
}

class _EliminarCuentaPageState extends State<EliminarCuentaPage> {
  double _progress = 0;
  late InAppWebViewController inAppWebViewController;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Eliminar cuenta", style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20
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
             url: WebUri('https://metax.com.co/baja.html'),
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
           backgroundColor: grisMedio,
           minHeight: 8,
           value: _progress,
         ): const SizedBox()
       ],
     ),
    );
  }
}



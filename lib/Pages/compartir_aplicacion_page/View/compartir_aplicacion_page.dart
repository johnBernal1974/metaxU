import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../helpers/header_text.dart';
import '../../../src/colors/colors.dart';

class CompartirAplicacionpage extends StatefulWidget {
  const CompartirAplicacionpage({super.key});

  @override
  State<CompartirAplicacionpage> createState() => _CompartirAplicacionpageState();
}

class _CompartirAplicacionpageState extends State<CompartirAplicacionpage> {
  Future<String?> _getLinkFromFirestore(String field) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('Prices')
          .doc('info')
          .get();
      return snapshot[field] as String?;
    } catch (e) {
      if (kDebugMode) {
        print("Error obteniendo el enlace de Firestore: $e");
      }
      return null;
    }
  }

  void _shareAppLinkViaWhatsAppDriver(BuildContext context) async {
    const String playStoreUrl =
        "https://play.google.com/store/apps/details?id=com.apptaxxic.apptaxisc";

    String message =
        "Descarga Metax Conductor y empieza a manejar con nosotros 🚕🧭📲\n$playStoreUrl";

    final Uri uri =
    Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        _showNoWhatsAppInstalledDialog(context);
      }
    }
  }

  void _shareAppLinkViaWhatsAppClient(BuildContext context) async {
    const String playStoreUrl =
        "https://play.google.com/store/apps/details?id=com.app_taxis.apptaxis&pcampaignid=web_share";

    String message =
        "¡Ingresando a este enlace podrás descargar Metax Cliente! 🚖📲\n$playStoreUrl";

    final Uri uri =
    Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        _showNoWhatsAppInstalledDialog(context);
      }
    }
  }



  void _showNoWhatsAppInstalledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'WhatsApp no instalado',
            style: TextStyle(fontSize: 18.r, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'No tienes WhatsApp en tu dispositivo. Instálalo e intenta de nuevo',
            style: TextStyle(fontSize: 14.r),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Aceptar',
                style: TextStyle(color: negro, fontWeight: FontWeight.w900, fontSize: 14.r),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    return Scaffold(
      backgroundColor: blancoCards,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Compartir App", style: TextStyle(
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Opción 1',
              style: TextStyle(fontSize: 18.r, fontWeight: FontWeight.w800),
            ),
            headerText(
              text: 'Comparte Metax con tus amigos, familiares y personas queridas mediante WhatsApp dando click en alguno de los sigientes iconos:',
              fontSize: 14.r,
              fontWeight: FontWeight.w500,
              color: negro,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () async {
                    String? linkClient = await _getLinkFromFirestore('link_descarga_client');
                    if (linkClient != null) {
                      if (context.mounted) {
                        _shareAppLinkViaWhatsAppClient(context);
                      }
                    }
                  },
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.only(left: 25.r, top: 25.r, right: 15.r),
                            child: Image(
                              height: 50.r,
                              width: 50.r,
                              image: const AssetImage('assets/icono_app_client.png'),
                            ),
                          ),
                          const Image(
                            height: 35.0,
                            width: 35.0,
                            image: AssetImage('assets/icono_compartir_circular.png'),
                          ),
                        ],
                      ),
                      headerText(
                        text: 'Cliente',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: negroLetras,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    String? linkDriver = await _getLinkFromFirestore('link_descarga_driver');
                    if (linkDriver != null) {
                      if (context.mounted) {
                        _shareAppLinkViaWhatsAppDriver(context);
                      }
                    }
                  },
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.only(left: 25.r, top: 25.r, right: 15.r),
                            child: Image(
                              height: 50.r,
                              width: 50.r,
                              image: const AssetImage('assets/icono_app_driver.png'),
                            ),
                          ),
                          Image(
                            height: 35.r,
                            width: 35.r,
                            image: const AssetImage('assets/icono_compartir_circular.png'),
                          ),
                        ],
                      ),
                      headerText(
                        text: 'Conductor',
                        fontSize: 12.r,
                        fontWeight: FontWeight.w700,
                        color: negroLetras,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(color: grisMedio),
            const SizedBox(height: 30),
            Text(
              'Opción 2',
              style: TextStyle(fontSize: 18.r, fontWeight: FontWeight.w800),
            ),
            Text(
              'Dile que escanee el código QR de la app que quiere instalar',
              style: TextStyle(fontSize: 14.r, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  qrDriver(),
                  const SizedBox(width: 30), // Espacio entre las imágenes
                  qrCliente(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 5.r),
                  width: 8.r,
                  height: 8.r,
                  decoration: BoxDecoration(
                    color: index == 0 ? negroLetras : grisMedio, // Punto activo y pasivo
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),

          ],
        ),
      ),
    );
  }

  Widget qrDriver() {
    return GestureDetector(
      onTap: () => _showZoomImage('assets/qrConductor.png'),
      child: Image(
        height: 250.r,
        width: 250.r,
        image: const AssetImage('assets/qrConductor.png'),
      ),
    );
  }

  Widget qrCliente() {
    return GestureDetector(
      onTap: () => _showZoomImage('assets/qr_metax_cliente.png'),
      child: Image(
        height: 250.r,
        width: 250.r,
        image: const AssetImage('assets/qr_metax_cliente.png'),
      ),
    );
  }

  void _showZoomImage(String assetPath) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "zoom",
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (_, __, ___) {
        return Center(
          child: _ZoomableAssetImage(
            assetPath: assetPath,
            size: 320.r, // tamaño del zoom (ajústalo)
          ),
        );
      },
    );
  }

}

class _ZoomableAssetImage extends StatefulWidget {
  final String assetPath;
  final double size;

  const _ZoomableAssetImage({
    required this.assetPath,
    required this.size,
  });

  @override
  State<_ZoomableAssetImage> createState() => _ZoomableAssetImageState();
}

class _ZoomableAssetImageState extends State<_ZoomableAssetImage> {
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    // Arranca con animación al abrir el dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _zoomed = true);
    });
  }

  void _close() {
    setState(() => _zoomed = false);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close, // 👈 segundo click: vuelve al estado original (cierra)
      child: AnimatedScale(
        scale: _zoomed ? 1.0 : 0.85,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Image.asset(
            widget.assetPath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}


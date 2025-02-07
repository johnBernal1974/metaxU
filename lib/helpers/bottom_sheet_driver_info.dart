import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/driver_provider.dart';
import '../models/driver.dart';
import '../models/client.dart';
import '../src/colors/colors.dart';

class BottomSheetDriverInfo extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String apellido;
  late String calificacion;
  final String numeroViajes;
  final String celular;
  final String placa;
  final String color;
  final String servicio;
  final String marca;
  final String idDriver;
  final String clase;

  BottomSheetDriverInfo({super.key,
    required this.imageUrl,
    required this.name,
    required this.apellido,
    required this.calificacion,
    required this.numeroViajes,
    required this.celular,
    required this.placa,
    required this.color,
    required this.servicio,
    required this.marca,
    required this.idDriver,
    required this.clase,
  });

  @override
  State<BottomSheetDriverInfo> createState() => _BottomSheetDriverInfoState();
}

class _BottomSheetDriverInfoState extends State<BottomSheetDriverInfo> {
  Client? client;
  Driver? driver;
  late DriverProvider _driverProvider;
  late MyAuthProvider _authProvider;
  String tipoServicio = '';

  @override
  void initState() {
    super.initState();
    _driverProvider = DriverProvider();
    _authProvider = MyAuthProvider();
    getDriverInfo();
    getClientRatings();
  }

  @override
  Widget build(BuildContext context) {
    String placaCompleta = widget.placa;
    String placaFormateada = '';
    if (placaCompleta.length == 6) {
      String letras = placaCompleta.substring(0, 3);
      String numeros = placaCompleta.substring(3);
      placaFormateada = '$letras-$numeros';
    } else {
      placaFormateada = placaCompleta;
    }
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
          topLeft: Radius.circular(12)
        )
      ),

      padding: const EdgeInsets.all(16),
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: widget.imageUrl.isNotEmpty
                              ? NetworkImage(widget.imageUrl)
                              : const AssetImage('assets/images/default_image.png') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                                onPressed: () {
                                  makePhoneCall(widget.celular);
                                },
                                icon: const Icon(Icons.phone),
                                iconSize: 24),
                            const SizedBox(width: 25),
                            IconButton(
                              onPressed: () {
                                _openWhatsApp(context);
                              },
                              icon: Image.asset('assets/icono_whatsapp.png',
                                  width: 24,
                                  height: 24),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: negro
                            ),
                          ),
                          Text(
                            widget.apellido,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    color: negro,
                                    size: 16,
                                  ),
                                ],
                              ),
                              Text(
                                widget.numeroViajes,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 30),
                          Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: negro,
                                    size: 16,
                                  ),
                                ],
                              ),
                              Text(
                                widget.calificacion,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 10),
              Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  child: const Divider(height: 2, color: primary)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const Text('Placa', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                      Container(
                        padding: const EdgeInsets.all(5),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset("assets/placa_blanca.png",
                              width: 120,
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                            Text(
                              placaFormateada,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Marca: '),
                          Text(widget.marca, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),)
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Color: '),
                          Text(widget.color, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),)
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Servicio: '),
                          Text(widget.servicio, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),)
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Clase: '),
                          Text(widget.clase, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),)
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void getDriverInfo() async {
    driver = await _driverProvider.getById(_authProvider.getUser()!.uid);
    if (driver != null) {
      setState(() {
        tipoServicio = driver!.the19TipoServicio;
      });
    }
  }


  void _openWhatsApp(BuildContext context) async {
    final phoneNumber = '+57${widget.celular}';
    String? name = driver?.the01Nombres;
    String? nameUser = widget.name;
    String message = 'Hola $nameUser, mi nombre es $name y soy el conductor que aceptó tu solicitud.';

    final whatsappLink = Uri.parse('whatsapp://send?phone=$phoneNumber&text=${Uri.encodeQueryComponent(message)}');

    try {
      await launchUrl(whatsappLink);
    } catch (e) {
      showNoWhatsAppInstalledDialog(context);
    }
  }

  void showNoWhatsAppInstalledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('WhatsApp no instalado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          content: const Text('No tienes WhatsApp en tu dispositivo. Instálalo e intenta de nuevo'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Aceptar', style: TextStyle(color: negro, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  void makePhoneCall(String phoneNumber) async {
    final phoneCallUrl = 'tel:$phoneNumber';

    try {
      await launch(phoneCallUrl);
    } catch (e) {
      if (kDebugMode) {
        print('No se pudo realizar la llamada: $e');
      }
    }
  }

  void getClientRatings() async {
    final drivertId = widget.idDriver;
    final ratingsSnapshot = await FirebaseFirestore.instance
        .collection('Drivers')
        .doc(drivertId)
        .collection('ratings')
        .get();

    if (ratingsSnapshot.docs.isNotEmpty) {
      double totalRating = 0;
      int ratingCount = ratingsSnapshot.docs.length;

      for (var doc in ratingsSnapshot.docs) {
        totalRating += doc['calificacion'];
      }

      double averageRating = totalRating / ratingCount;

      setState(() {
        widget.calificacion = averageRating.toStringAsFixed(1);
      });
    } else {
      setState(() {
        widget.calificacion = 'N/A';
      });
    }
  }
}

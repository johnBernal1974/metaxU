import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import '../../providers/travel_info_provider.dart';
import '../../src/colors/colors.dart';
import '../travel_map_page/View/travel_map_page.dart';

class TaxiHaLLegado extends StatefulWidget {
  const TaxiHaLLegado({super.key});

  @override
  State<TaxiHaLLegado> createState() => _TaxiHaLLegadoState();
}

class _TaxiHaLLegadoState extends State<TaxiHaLLegado> {
  late TravelInfoProvider _travelInfoProvider;
  late MyAuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _travelInfoProvider = TravelInfoProvider();
    _authProvider = MyAuthProvider();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tarjeta
            Container(
              width: 300,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset("assets/metax_logo.png", width: 200),
                  // Imagen
                  Image.asset("assets/imagen_taxi.png", width: 200),
                  // Título
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      'Tu taxi ha llegado',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text("Da click en el boton para cerrar la ventana y ver los detalles del viaje",
                  textAlign: TextAlign.center),
                  // Botón Cerrar
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: primary,
                        minimumSize: const Size(200, 50), // Tamaño mínimo del botón
                      ),
                      onPressed: () {
                        Map<String, dynamic> data = {'status': 'client_notificado'};
                        _travelInfoProvider.update(data, _authProvider.getUser()!.uid);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const TravelMapPage()),
                              (route) => false,
                        );
                      },
                      child: const Text('Cerrar ventana', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900
                      ),),
                    ),
                  ),
                  SizedBox(height: 30)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
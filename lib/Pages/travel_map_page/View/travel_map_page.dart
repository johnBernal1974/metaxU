
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../models/driver.dart';
import '../../../src/colors/colors.dart';
import '../travel_map_controller/travel_map_controller.dart';

class TravelMapPage extends StatefulWidget {
  const TravelMapPage({super.key});

  @override
  State<TravelMapPage> createState() => _TravelMapPageState();
}

class _TravelMapPageState extends State<TravelMapPage> {

  late TravelMapController _controller;
  Driver? driver;



  @override
  void initState() {
    super.initState();
    _controller = TravelMapController();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context, refresh);
    });
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    ScreenUtil.init(context, designSize: const Size(375, 812));
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: grisMapa,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _googleMapsWidget(),
                  SafeArea(
                    child: Stack(
                      children: [

                        /// BOTÓN CENTRAR MAPA
                        Positioned(
                          top: 10,
                          child: _buttonCenterPosition(),
                        ),

                        /// AVATAR USUARIO (ARRIBA DERECHA)
                        Positioned(
                          right: 0,
                          top: 20,
                          child: _clickUsuarioServicio(),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
            _cajonInformativo(screenWidth),
          ],
        ),
      ),
    );
  }

  IconData _iconoPorEstado(String status) {
    switch (status) {
      case 'Viaje aceptado':
        return Icons.check_circle_outline;

      case 'Conductor en camino':
        return Icons.arrow_forward;

      case 'El Conductor ha llegado':
        return Icons.location_on_outlined;

      case 'El Viaje ha iniciado':
        return Icons.route_outlined;

      case 'Viaje finalizado':
        return Icons.flag_outlined;

      default:
        return Icons.info_outline;
    }
  }




  Widget _cancelarViaje() {
    final s = _controller.travelInfo?.status ?? '';

    return Visibility(
      visible: s == 'accepted' ||
          s == 'driver_on_the_way' ||
          s == 'driver_is_waiting' ||
          s == 'client_notificado',
      child: GestureDetector(
        onTap: () async {
          await _controller.connectionService.checkConnectionAndShowCard(
            context,
                () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      'Cancelar Viaje',
                      style: TextStyle(
                        fontSize: 16.r,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      '¿En verdad deseas cancelar el viaje?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('NO'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _controller.cancelTravelByClient();
                        },
                        child: const Text('SI'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.cancel,
            color: Colors.white,
            size: 20.r,
          ),
        ),
      ),
    );
  }

  Future alertSinInternet (){
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sin Internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),),
          content: const Text('Por favor, verifica tu conexión e inténtalo nuevamente.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Widget _googleMapsWidget() {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: _controller.initialPosition,
      onMapCreated: _controller.onMapCreated,
      rotateGesturesEnabled: false,
      zoomControlsEnabled: false,
      tiltGesturesEnabled: false,
      markers: Set<Marker>.of(_controller.markers.values),
      polylines: _controller.polylines,
    );
  }

  void refresh() {
    if (context.mounted) {
      setState(() {});
    }
  }

  Widget _clickUsuarioServicio() {
    String placaCompleta = _controller.travelInfo?.placa ?? '';
    String placaFormateada = '';

    if (placaCompleta.length == 6) {
      String letras = placaCompleta.substring(0, 3);
      String numeros = placaCompleta.substring(3);
      placaFormateada = '$letras-$numeros';
    } else {
      placaFormateada = placaCompleta;
    }

    return GestureDetector(
      onTap: () {
        if ([
          'accepted',
          'driver_on_the_way',
          'driver_is_waiting',
          "client_notificado"
        ].contains(_controller.travelInfo?.status)) {
          _controller.openBottomSheetDiverInfo();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(48.r),
            bottomLeft: Radius.circular(48.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.6),
              offset: const Offset(1, 1),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: primary,
              backgroundImage: _controller.driver?.image != null
                  ? NetworkImage(_controller.driver!.image)
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _controller.driver?.the01Nombres ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  placaFormateada,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttonCenterPosition(){
    return GestureDetector(
      onTap: _controller.centerPosition,
      child: Container(
        alignment: Alignment.bottomRight,
        margin: EdgeInsets.only(right: 10.r, top: 15.r, left: 15.r),
        child: Card(
          shape: const CircleBorder(),
          color: blanco,
          surfaceTintColor: blanco,
          elevation: 2,
          child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                boxShadow: const [
                  BoxShadow(
                    offset: Offset(0.0, 15.0),
                    blurRadius: 25,
                    color: gris,
                  )
                ],
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(Icons.location_searching, color: negro, size:30.r,)),
        ),
      ),
    );
  }

  Widget _cajonInformativo(double screenWidth) {

    final formatCurrency = NumberFormat("#,##0", "es_CO");
    final caracteristica =
    _controller.travelInfo?.caracteristicaVehiculo?.trim();

    final mostrarCaracteristica =
        caracteristica != null &&
            caracteristica.isNotEmpty &&
            caracteristica.toLowerCase() != 'no';

    return SafeArea(
      top: false,
      child: Container(
        width: screenWidth,
        margin: EdgeInsets.fromLTRB(12.r, 6.r, 12.r, 10.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            /// 🔹 ESTADO DEL VIAJE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [

                  Icon(
                    _iconoPorEstado(_controller.currentStatus),
                    color: Colors.black,
                    size: 26,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      _controller.currentStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  _cancelarViaje(),
                ],
              ),
            ),

            /// 🔹 DESTINO
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/marker_destino.png',
                        width: 14,
                        height: 14,
                      ),

                      const SizedBox(width: 6),

                      const Text(
                        "Destino",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: grisMedio),

                  const SizedBox(height: 6),

                  Text(
                    _controller.travelInfo?.to ?? 'Destino no disponible',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.1
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: grisMedio),
                ],
              ),
            ),

            /// 🔹 CARACTERÍSTICA ESPECIAL
            if (mostrarCaracteristica)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: "Requiere: ",
                              style: TextStyle(fontSize: 13),
                            ),
                            TextSpan(
                              text: caracteristica,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            /// 🔹 TARIFA Y PAGO
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        "\$ ${formatCurrency.format(_controller.travelInfo?.tarifa ?? 0)}",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined),
                      const SizedBox(width: 6),
                      Text(
                        _controller.travelInfo?.metodoPago ?? "Efectivo",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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


import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../helpers/conectivity_service.dart';
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
  final ConnectionService connectionService = ConnectionService();

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
        backgroundColor: blanco,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _googleMapsWidget(),
                  SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buttonCenterPosition(),
                          ],
                        ),
                        Expanded(child: Container()),
                        _clickUsuarioServicio(),
                        SizedBox(height: 5.r),
                        _cancelarViaje(),
                        SizedBox(height: 15.r),
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

  Color _colorPorEstado(String status) {
    switch (status) {
      case 'Viaje aceptado':
        return Colors.lightGreen;

      case 'Conductor en camino':
        return Colors.orangeAccent;

      case 'El Conductor ha llegado':
        return Colors.green;

      case 'El Viaje ha iniciado':
        return Colors.deepPurple;

      case 'Viaje finalizado':
        return Colors.black87;

      default:
        return Colors.grey;
    }
  }

  Widget _cajonEstadoViaje(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: blanco,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [

          /// 🟢 CAJÓN DEL ESTADO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _colorPorEstado(status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _colorPorEstado(status),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconoPorEstado(status),
                  color: _colorPorEstado(status),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13.r,
                    fontWeight: FontWeight.w900,
                    color: _colorPorEstado(status),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          const Text("Destino", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 6),
          /// 📍 DESTINO
          Text(
            _controller.travelInfo?.to ?? 'Destino no disponible',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  Widget _cancelarViaje() {
    return Visibility(
      visible: _controller.status == 'accepted' ||
          _controller.status == 'driver_on_the_way' ||
          _controller.status == 'driver_is_waiting' ||
          _controller.status == 'client_notificado',
      child: Padding(
        padding: EdgeInsets.only(top: 5.r),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              // Verificar conexión a Internet antes de ejecutar la acción
              connectionService.hasInternetConnection().then((hasConnection) {
                if (hasConnection) {
                  // Llama a _mostrarCajonDeBusqueda inmediatamente
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Cancelar Viaje', style: TextStyle(fontSize: 16.r, fontWeight: FontWeight.bold)),
                        content: const Text('¿En verdad deseas cancelar el viaje?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              // Cerrar el AlertDialog sin realizar ninguna acción
                              Navigator.of(context).pop();
                            },
                            child: const Text('NO'),
                          ),
                          TextButton(
                            onPressed: () {
                              _controller.cancelTravelByClient();
                            },
                            child: const Text('SI'),
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  // Llama a alertSinInternet inmediatamente si no hay conexión
                  alertSinInternet();
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40.r),
                      topLeft: Radius.circular(40.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.white, size: 30.r),
                        const SizedBox(width: 5),
                        Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 12.r,
                            color: blanco,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    String placaCompleta = _controller.driver?.the18Placa ?? '';
    String placaFormateada = '';
    if (placaCompleta.length == 6) {
      String letras = placaCompleta.substring(0, 3);
      String numeros = placaCompleta.substring(3);
      placaFormateada = '$letras-$numeros';
    } else {
      // Manejar el caso en el que la placa no tenga 6 caracteres
      placaFormateada = placaCompleta; // O asignar un valor por defecto
    }

    return GestureDetector(
      onTap: () {
        if (['accepted', 'driver_on_the_way', 'driver_is_waiting', "client_notificado"].contains(_controller.travelInfo?.status)) {
          _controller.openBottomSheetDiverInfo();
        }
      },
      child: Align(
        alignment: Alignment.centerRight,
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.all(8),
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
                        fontWeight: FontWeight.bold, // Color del texto
                      ),
                    ),
                    Text(
                      placaFormateada,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w900, // Color del texto
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

    return Container(
      width: screenWidth,
      child: Column(
        children: [
          _cajonEstadoViaje(_controller.currentStatus),
          SizedBox(height: 6.r),

          /// 💰 CAJÓN TARIFA PRO
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.r),
            padding: EdgeInsets.symmetric(horizontal: 18.r, vertical: 12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 18.r,
                  color: Colors.green.shade700,
                ),
                SizedBox(width: 6.r),

                /// LABEL
                Text(
                  'Tarifa:',
                  style: TextStyle(
                    fontSize: 13.r,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.4,
                  ),
                ),

                SizedBox(width: 8.r),

                /// VALOR
                Text(
                  '\$ ${formatCurrency.format(_controller.travelInfo?.tarifa ?? 0)}',
                  style: TextStyle(
                    fontSize: 22.r,
                    fontWeight: FontWeight.w900,
                    color: negro,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10.r),
        ],
      ),
    );
  }


}

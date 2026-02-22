import 'package:apptaxis/Pages/travel_info_page/travel_info_Controller/travel_info_Controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../helpers/FormValidators.dart';
import '../../helpers/conectivity_service.dart';
import '../../helpers/header_text.dart';
import '../../src/colors/colors.dart';


class ClientTravelInfoPage extends StatefulWidget {
  const ClientTravelInfoPage({super.key});

  @override
  State<ClientTravelInfoPage> createState() => _ClientTravelInfoPageState();
}

class _ClientTravelInfoPageState extends State<ClientTravelInfoPage> {

  final TravelInfoController _controller = Get.put(TravelInfoController());
  late bool isVisibleCheckCarro = true;
  late bool isVisibleCheckMoto = false;
  late bool isVisibleCheckEncomienda = false;
  late bool isVisibleTarjetaEncomiendas = false;
  late bool isVisibleTarjetaSolicitandoConductor = false;
  late String formattedTarifa;
  int? tarifa;
  bool _isSearching = false;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  String? tipoServicio ;
  late bool isVisibleCajonApuntesAlConductor = false;
  final TextEditingController _con = TextEditingController();
  String? apuntesAlConductor;
  String? tipoServicioSeleccionado;
  final ConnectionService connectionService = ConnectionService();
  bool _loadingRoute = true;





  @override
  void initState() {
    super.initState();
    _loadingRoute = true;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await connectionService.checkConnectionAndShowCard(context, () async {
        if (mounted) setState(() => _loadingRoute = true);
        await _controller.init(context, refresh);
        if (mounted) setState(() => _loadingRoute = false);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    tarifa = _controller.total?.toInt() ?? 0;
    formattedTarifa= FormatUtils.formatCurrency(tarifa!);
    String from = _controller.from;
    String to = _controller.to;
    return WillPopScope(
      onWillPop: () async {
        await _controller.deleteTravelInfo();
        return true;
      },
      child: Scaffold(
        backgroundColor: grisMapa,
        key: _controller.key,
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _googleMapsWidget(),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child:  _cardInfoViaje(from, to),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: _buttonVolverAtras(),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: _tarjetaSolicitandoConductor(),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child:  _apuntesAlConductor(),
            ),

          ],

        ),

      ),
    );
  }

  void refresh(){
    if(mounted){
      setState(() {
      });
    }

  }

  Widget _googleMapsWidget() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.50,
      child: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _controller.initialPosition,
        onMapCreated: _controller.onMapCreated,
        rotateGesturesEnabled: false,
        zoomControlsEnabled: false,
        tiltGesturesEnabled: false,
        markers: Set<Marker>.of(_controller.markers.values),
        polylines: _loadingRoute ? {} : _controller.polylines,
      ),
    );
  }


  Widget _buttonVolverAtras(){
    return SafeArea(
      child: GestureDetector(
        onTap: (){
          Navigator.of(context).pop(); // Agrega esta línea para manejar el evento de retroceso
        },
        child: Container(
          margin: EdgeInsets.only(right: 10.r,  left: 10.r),
          child: Card(
            shape: const CircleBorder(),
            surfaceTintColor: Colors.white,
            color: Colors.white,
            elevation: 2,
            child: Container(
                padding: EdgeInsets.all(5.r),
                child: Icon(Icons.arrow_back, color: negroLetras, size:25.r,)),

          ),
        ),
      ),
    );
  }

  Widget _cardInfoViaje(String from, String to){
    return Container(
      height: MediaQuery.of(context).size.height * 0.50,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          topRight: Radius.circular(30.r),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary,
            blancoCards,
          ],
          stops: [0.0, 0.5], // 👈 mitad y mitad
        ),
        boxShadow: [
          BoxShadow(
            color: negro.withOpacity(0.4),
            offset: Offset(0, 8.r),
            blurRadius: 9.r,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 15.r, left: 25.r, right: 25.r),
            child: Row(
              children: [
                Image.asset('assets/ubicacion_client.png', height: 15.r, width: 15.r),
                SizedBox(width: 5.r),
                Expanded(child: Text(from, style: TextStyle(fontSize: 12.r, color: negro), maxLines: 1))
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.only(left: 25.r, right: 25.r),
            child: Row(
              children: [
                Image.asset('assets/marker_destino.png', height: 15.r, width: 15.r),
                SizedBox(width: 5.r),
                Expanded(child: Text(to, style: TextStyle( fontWeight: FontWeight.w900, fontSize: 12.r, color: negro), maxLines: 1))
              ],
            ),
          ),

          const Divider(height: 2, color: Colors.black87, indent: 15, endIndent: 15),

          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: EdgeInsets.symmetric(horizontal: 8.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                /// 📏 DISTANCIA
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      headerText(
                        text: 'Distancia',
                        fontSize: 9.r,
                        color: negro,
                        fontWeight: FontWeight.w500,
                      ),
                      headerText(
                        text: _controller.km ?? '',
                        fontSize: 12.r,
                        color: negro,
                        fontWeight: FontWeight.w900,
                      ),
                    ],
                  ),
                ),

                /// ⏱ DURACIÓN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      headerText(
                        text: 'Duración',
                        fontSize: 9.r,
                        color: negro,
                        fontWeight: FontWeight.w500,
                      ),
                      headerText(
                        text: _controller.min ?? '',
                        fontSize: 12.r,
                        color: negro,
                        fontWeight: FontWeight.w900,
                      ),
                    ],
                  ),
                ),

                /// 💰 TARIFA
                Flexible(
                  flex: 2,
                  child: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 6.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 6.r,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),

                        // 🔥 borde primary
                        border: Border.all(
                          color: primary,
                          width: 3,
                        ),

                        // 🔥 sombra más fina (elevación suave)
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            offset: const Offset(0, 2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: headerText(
                          text: formattedTarifa,
                          fontSize: 16.r,
                          color: Colors.black87,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 2, color: Colors.black87, indent: 15, endIndent: 15),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Image.asset("assets/imagen_taxi.png", height: 60),
              _textApuntes (),
            ],
          ),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(5.r),
            margin: EdgeInsets.only(top: 15.r, left: 10.r, right: 10.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: grisClaro, // Cambia el color de fondo del contenedor a blanco
            ),
            child: Text(_con.text.isNotEmpty ? _con.text : 'Sin apuntes', style: TextStyle(
                fontSize: 14.r, color: negroLetras, fontWeight: FontWeight.w600
            ),
                maxLines: 2),
          ),

          Expanded(
            child: Container(
            ),
          ),
          Container(
            width: double.infinity,
            height: 40.r,
            margin: EdgeInsets.only(left: 25.r, right: 25.r, bottom: 30.r),
            child: OutlinedButton(
              onPressed: (_controller.isCalculatingTrip || !_controller.canConfirmTrip)
                  ? null
                  : () async {
                FocusScope.of(context).unfocus();

                await connectionService.checkConnectionAndShowCard(
                  context,
                      () {
                    verificarCedulaInicial();
                  },
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primary, width: 1.5), // 👈 igual al OTP
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(vertical: 10.r),
              ),

              // 🔥 MISMO patrón visual que OTP
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _controller.isCalculatingTrip
                    ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14.r,
                      height: 14.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    ),
                    SizedBox(width: 8.r),
                    Text(
                      'Calculando ruta...',
                      style: TextStyle(
                        color: primary,
                        fontSize: 14.r,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                    : Row(
                  key: const ValueKey('idle'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 24.r,
                      color: primary,
                    ),
                    SizedBox(width: 8.r),
                    Text(
                      'Confirmar Viaje',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14.r,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  Widget _textApuntes() {
    return Container(
      margin: EdgeInsets.only(right: 10.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 40.r,
            child: OutlinedButton(
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  isVisibleCajonApuntesAlConductor = true;
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
              ),

              // 🔥 mismo patrón visual
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 22.r,
                    color: primary,
                  ),
                  SizedBox(width: 8.r),
                  Text(
                    'Apunte al conductor',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.r,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _apuntesAlConductor() {
    return Visibility(
      visible: isVisibleCajonApuntesAlConductor,
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.only(top: 50),
          height: MediaQuery.of(context).size.height * 0.6,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: blanco,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: gris,
                offset: Offset(3, -2),
                blurRadius: 10,
              )
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(20.r),
            child: Column(
              children: [
                Text(
                  "Escribe al conductor alguna información importante para tu viaje.",
                  style: TextStyle(
                    fontSize: 16.r,
                    color: negro,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 30.r),
                TextField(
                  maxLength: 80,
                  autofocus: true,
                  showCursor: true,
                  controller: _con,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: primary,
                  decoration: InputDecoration(
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: primary),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: primary),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _con.clear();
                      },
                    ),
                  ),
                ),
                SizedBox(height: 35.r),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 🔥 GUARDAR
                    OutlinedButton(
                      onPressed: () {
                        if (!mounted) return;

                        setState(() {
                          isVisibleCajonApuntesAlConductor = false;
                        });

                        _obtenerApuntesAlConductor();
                        _controller.guardarApuntesConductor(apuntesAlConductor!);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 10.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Guardar',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.r,
                            ),
                          ),
                          SizedBox(width: 8.r),
                          Icon(
                            Icons.check_circle_outline,
                            size: 18.r,
                            color: primary,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 10.r),

                    // 🔴 CANCELAR
                    OutlinedButton(
                      onPressed: () {
                        if (!mounted) return;

                        setState(() {
                          isVisibleCajonApuntesAlConductor = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade400, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 10.r),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.r,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _obtenerApuntesAlConductor(){
    apuntesAlConductor = _con.text;
  }

  void verificarCedulaInicial() {
    if (mounted) { // Verifica si el widget está montado
      setState(() {
        isVisibleTarjetaSolicitandoConductor = true;
      });
    }
    _startSearch();
    _controller.createTravelInfo();
    _controller.getNearbyDrivers();
  }

  Widget _tarjetaSolicitandoConductor() {
    if (!mounted) {
      return Container(); // Retorna un widget vacío si el widget ya no está montado
    }
    return Visibility(
      visible: isVisibleTarjetaSolicitandoConductor,
      child: Container(
        height: double.infinity,
        padding: EdgeInsets.only(top: 50.r, left: 30.r, right: 30.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30.r),
            topRight: Radius.circular(30.r),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primary,
              blancoCards,
            ],
            stops: [0.0, 0.5], // 👈 mitad y mitad
          ),
          boxShadow: [
            BoxShadow(
              color: negro.withOpacity(0.4),
              offset: Offset(0, 8.r),
              blurRadius: 9.r,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [

            SizedBox(height: 10.r),
            Image.asset("assets/imagen_taxi.png", height: 100),
            Column(
              children: [
                Text(
                  "Buscando un taxi\nque te lleve a:",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24.r, // 🔽 más compacto
                    color: negro,
                    height: 1.1
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 8.r),
                const Divider(color: Colors.black54, height: 1),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 4.r),
                    Flexible(
                      child: Text(
                        _controller.to ?? '', // 👈 destino
                        style: TextStyle(
                          fontSize: 14.r,
                          color: negro,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                if (_isSearching)
                  SpinKitRipple(
                    color: primary,
                    size: 200.r,
                  ),
                Image.asset(
                  'assets/metax_logo.png',
                  width: 80.r,
                  height: 80.r,
                ),

              ],
            ),
            Text(
              'Esperando respuesta...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.r, color: negro),
            ),
            SizedBox(height: 50.r),
            OutlinedButton(
              onPressed: () {
                if (!mounted) return;

                setState(() {
                  isVisibleTarjetaSolicitandoConductor = false;
                  _isSearching = false;
                });

                _controller.deleteTravelInfo();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade400, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
              ),

              // 🔥 mismo patrón visual que los otros
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    size: 20.r,
                    color: Colors.red.shade400,
                  ),
                  SizedBox(width: 8.r),
                  Text(
                    'Cancelar solicitud',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 14.r,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  void _startSearch() {
    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }
  }

}

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



  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context, refresh);
      setState(() {});
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
            )
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
      //margin: const EdgeInsets.only(bottom: 420),
      child: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _controller.initialPosition,
        onMapCreated: _controller.onMapCreated,
        rotateGesturesEnabled: false,
        zoomControlsEnabled: false,
        tiltGesturesEnabled: false,
        markers: Set<Marker>.of(_controller.markers.values),
        polylines: _controller.polylines,
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
          color: Colors.white,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30)
          ),
          boxShadow: [BoxShadow(
            color: gris,
            offset: const Offset(1,1),
            blurRadius: 10.r,
          )]
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

          const Divider(height: 2, color: grisMedio, indent: 15, endIndent: 15),

          Container(
            margin: const EdgeInsets.only(top: 5, bottom: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        headerText(text:'Distancia', fontSize: 10.r, color: negro, fontWeight: FontWeight.w500),
                        headerText(text: _controller.km ?? '', fontSize: 14.r, color: negro, fontWeight: FontWeight.w900),
                      ],
                    ),

                    Column(
                      children: [
                        headerText(text:'Duración', fontSize: 10.r, color: negro, fontWeight: FontWeight.w500),
                        headerText(text: _controller.min ?? '', fontSize: 14.r, color: negro, fontWeight: FontWeight.w900),
                      ],
                    ),
                  ],
                ),

                Container(
                    width: 200.r,
                    padding: EdgeInsets.all(10.r),
                    child: headerText(text: formattedTarifa, fontSize: 26.r, color: negro, fontWeight: FontWeight.w900)
                ),
              ],
            ),
          ),
          const Divider(height: 2, color: grisMedio, indent: 15, endIndent: 15),
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
                fontSize: 16.r, color: Colors.black, fontWeight: FontWeight.w900
            ),
                maxLines: 2),
          ),

          Expanded(
            child: Container(
            ),
          ),
          Container(
            width: double.infinity,
            height: 48.r,
            margin: EdgeInsets.only(left: 25.r, right: 25.r, bottom: 30.r),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              onPressed: () async {
                bool hasConnection = await connectionService.hasInternetConnection();

                if (hasConnection) {
                  // Si hay conexión, ejecuta la acción de ir a "Olvidaste tu contraseña"
                  verificarCedulaInicial();
                } else {
                  // Si no hay conexión, muestra un AlertDialog
                  alertSinInternet();
                }


              },
              icon: Icon(Icons.check_circle, size: 30.r, color: Colors.black,),
              label: Text(
                'Confirmar Viaje',
                style: TextStyle(color: Colors.black, fontSize: 20.r, fontWeight: FontWeight.bold),
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
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() {
            isVisibleCajonApuntesAlConductor = true;
          });
        }
      },
      child: Container(
        margin: EdgeInsets.only(right: 10.r),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    isVisibleCajonApuntesAlConductor = true;
                  });
                }
              },
              icon: Icon(Icons.edit_note, size: 30.r, color: Colors.white),
              label: Text(
                'Dejar un apunte al conductor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.r,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary, // Cambia el color según tus preferencias
                padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ],
        ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        elevation: 6,
                      ),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            isVisibleCajonApuntesAlConductor = false;
                          });
                        }
                        _obtenerApuntesAlConductor();
                        _controller.guardarApuntesConductor(apuntesAlConductor!);
                      },
                      child: Row(
                        children: [
                          Text(
                            'Guardar',
                            style: TextStyle(
                              color: blanco,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.r,
                            ),
                          ),
                          SizedBox(width: 10.r),
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16.r,
                            color: blanco,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        elevation: 6,
                      ),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            isVisibleCajonApuntesAlConductor = false;
                          });
                        }
                      },
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: negro,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.r,
                        ),
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
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
          ),
          color: blancoCards,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [

            SizedBox(height: 10.r),
            Image.asset("assets/imagen_taxi.png", height: 100),
            Text("Estamos buscando un taxi para ti.",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24.r, color: negro),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.r),
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                if (mounted) {
                  setState(() {
                    isVisibleTarjetaSolicitandoConductor = false;
                    _isSearching = false;
                  });
                }
                _controller.deleteTravelInfo();
              },
              icon: const Icon(Icons.cancel, color: blanco),
              label: Text('Cancelar solicitud', style: TextStyle(color: blanco, fontSize: 16.r)),
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

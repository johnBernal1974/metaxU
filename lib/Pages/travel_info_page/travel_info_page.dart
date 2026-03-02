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
import 'package:cloud_firestore/cloud_firestore.dart';


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

  String _metodoPagoSeleccionado = 'Efectivo';

  String _caracteristicaSeleccionada = 'No';

  final List<String> _caracteristicasVehiculo = [
    'No', // 👈 default
    'Aire acondicionado',
    'Vidrios polarizados',
    'Con baúl',
    'Porta bicicletas',
    'Silla de ruedas',
    'Con mascota',
  ];

  String _tipoServicioSeleccionado = 'standard'; // 'standard' | 'vip'

  int _valorVipExtra = 0;
  bool _cargandoValorVip = false;



  @override
  void initState() {
    super.initState();

    _loadingRoute = true;

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await connectionService.checkConnectionAndShowCard(context, () async {

        if (mounted) setState(() => _loadingRoute = true);

        await _controller.init(context, refresh);

        // ✅ AQUÍ llamas el valor VIP
        await _cargarValorVip();

        if (mounted) setState(() => _loadingRoute = false);
      });
    });
  }

  Future<void> _cargarValorVip() async {
    if (_cargandoValorVip) return;

    try {
      _cargandoValorVip = true;

      final snap = await FirebaseFirestore.instance
          .collection('Prices')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final raw = data['valor_vip'];

        int parsed = 0;
        if (raw is int) parsed = raw;
        if (raw is double) parsed = raw.toInt();
        if (raw is String) parsed = int.tryParse(raw) ?? 0;

        if (mounted) {
          setState(() => _valorVipExtra = parsed);
        }
      } else {
        // Si no hay docs, queda en 0
        if (mounted) setState(() => _valorVipExtra = 0);
      }
    } catch (_) {
      if (mounted) setState(() => _valorVipExtra = 0);
    } finally {
      _cargandoValorVip = false;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    final base = _controller.total?.toInt() ?? 0;
    final esVip = _tipoServicioSeleccionado == 'vip';

    tarifa = base + (esVip ? _valorVipExtra : 0);
    formattedTarifa = FormatUtils.formatCurrency(tarifa!);
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
            child: SafeArea(
              top: false,
              child: _cardInfoViaje(from, to),
            ),
          ),
            Align(
              alignment: Alignment.topLeft,
              child: _buttonVolverAtras(),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: _tarjetaSolicitandoConductor(),
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
      height: MediaQuery.of(context).size.height * 0.45,
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
      height: MediaQuery.of(context).size.height * 0.55,
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
          // ✅ MÉTODOS DE PAGO (fila independiente)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Método de pago',
                  style: TextStyle(
                    fontSize: 12.r,
                    fontWeight: FontWeight.w800,
                    color: negro,
                  ),
                ),
                SizedBox(height: 6.r),
                _metodoPagoSelector(),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Divider(height: 2, color: Colors.black87, indent: 15, endIndent: 15),
          const SizedBox(height: 15),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.r),
            child: _textApuntes(),
          ),

          Expanded(
            child: Container(
            ),
          ),
          Container(
            width: double.infinity,
            height: 40.r,
            margin: EdgeInsets.only(
              left: 25.r,
              right: 25.r,
              bottom: MediaQuery.of(context).padding.bottom + 45.r, // ✅ SAFE AREA
            ),
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
                side: const BorderSide(color: primary, width: 1.5), // 👈 igual al OTP
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
                      color: Colors.black,
                    ),
                    SizedBox(width: 8.r),
                    Text(
                      'SOLICITAR SERVICIO',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14.r,
                        fontWeight: FontWeight.w900,
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

  Widget _selectorTipoServicio() {
    return Row(
      children: [
        _buildTipoServicioItem(
          id: 'standard',
          titulo: 'Básico',
        ),
        // SizedBox(width: 10.r),
        // _buildTipoServicioItem(
        //   id: 'vip',
        //   titulo: 'VIP',
        // ),
      ],
    );
  }

  Widget _buildTipoServicioItem({
    required String id,
    required String titulo,
  }) {
    final bool seleccionado = _tipoServicioSeleccionado == id;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!mounted) return;
        setState(() => _tipoServicioSeleccionado = id);
      },
      child: Container(
        width: 120,
        padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
        decoration: BoxDecoration(
          color: seleccionado ? primary.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: seleccionado ? primary : Colors.grey.shade300,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 10.r,
                fontWeight: FontWeight.w800,
                color: negro,
              ),
            ),
            SizedBox(height: 6.r),
            Image.asset(
              "assets/imagen_taxi.png", // ✅ por ahora el mismo asset
              height: 38.r,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metodoPagoSelector() {
    return Row(
      children: [
        _buildMetodoPagoItem('Efectivo'),
        SizedBox(width: 8.r),
        _buildMetodoPagoItem('Nequi'),
        SizedBox(width: 8.r),
        _buildMetodoPagoItem('Daviplata'),
      ],
    );
  }

  Widget _buildMetodoPagoItem(String metodo) {
    final bool seleccionado = _metodoPagoSeleccionado == metodo;

    return GestureDetector(
      onTap: () {
        setState(() {
          _metodoPagoSeleccionado = metodo;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 6.r),
        decoration: BoxDecoration(
          color: seleccionado ? primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: seleccionado ? primary : Colors.grey.shade300,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔘 Círculo tipo radio
            Container(
              width: 14.r,
              height: 14.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: seleccionado ? primary : Colors.grey,
                  width: 2,
                ),
              ),
              child: seleccionado
                  ? Center(
                child: Container(
                  width: 6.r,
                  height: 6.r,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                  ),
                ),
              )
                  : null,
            ),
            SizedBox(width: 6.r),
            Text(
              metodo,
              style: TextStyle(
                fontSize: 12.r,
                fontWeight: FontWeight.w700,
                color: negro,
              ),
            ),
          ],
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

  Widget _textApuntes() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // ✅ TODO a la izquierda
        children: [
          Text(
            '¿Requieres algo especial para este viaje?',
            style: TextStyle(
              fontSize: 12.r,
              fontWeight: FontWeight.w800,
              color: negro,
            ),
          ),
          SizedBox(height: 6.r),

          // 🔥 Contenedor ancho completo
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: primary, width: 1.3),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _caracteristicaSeleccionada,
                isExpanded: true, // ✅ CLAVE para que ocupe todo el ancho
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: primary,
                  size: 22.r,
                ),
                items: _caracteristicasVehiculo.map((c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(
                      c,
                      textAlign: TextAlign.left, // ✅ texto a la izquierda
                      style: TextStyle(
                        fontSize: 13.r,
                        fontWeight: FontWeight.w700,
                        color: negro,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _caracteristicaSeleccionada = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }


  void verificarCedulaInicial() {
    if (mounted) {
      setState(() {
        isVisibleTarjetaSolicitandoConductor = true;
      });
    }

    _startSearch();

    final base = _controller.total?.toInt() ?? 0;
    final esVip = _tipoServicioSeleccionado == 'vip';
    final tarifaFinal = base + (esVip ? _valorVipExtra : 0);

    _controller.createTravelInfo(
      tipoServicio: _tipoServicioSeleccionado,
      valorVipExtra: esVip ? _valorVipExtra : 0,
      tarifaFinal: tarifaFinal,
      metodoPago: _metodoPagoSeleccionado,
      caracteristicaVehiculo: _caracteristicaSeleccionada, // ✅ corregido
    );

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

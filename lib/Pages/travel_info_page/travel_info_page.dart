import 'dart:async';

import 'package:apptaxis/Pages/travel_info_page/travel_info_Controller/travel_info_Controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../helpers/FormValidators.dart';
import '../../helpers/conectivity_service.dart';
import '../../helpers/header_text.dart';
import '../../models/promocion.dart';
import '../../src/colors/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ClientTravelInfoPage extends StatefulWidget {
  const ClientTravelInfoPage({super.key});

  @override
  State<ClientTravelInfoPage> createState() => _ClientTravelInfoPageState();
}

class _ClientTravelInfoPageState
    extends State<ClientTravelInfoPage>

    with TickerProviderStateMixin {

  final TravelInfoController _controller = Get.put(TravelInfoController());
  late bool isVisibleTarjetaSolicitandoConductor = false;
  late String formattedTarifa;
  late String formattedTarifaFinal;
  int? tarifa;
  bool _isSearching = false;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  late bool isVisibleCajonApuntesAlConductor = false;
  final TextEditingController _con = TextEditingController();
  String? apuntesAlConductor;
  String? tipoServicioSeleccionado;
  final ConnectionService connectionService = ConnectionService();
  bool _loadingRoute = true;

  String _metodoPagoSeleccionado = 'Efectivo';

  String _caracteristicaSeleccionada = 'No';
  late AnimationController _waveController;

  final List<String> _caracteristicasVehiculo = [
    'No', // 👈 default
    'Aire acondicionado',
    'Vidrios polarizados',
    'Con baúl',
    'Silla de ruedas',
    'Con mascota',
  ];

  String _tipoServicioSeleccionado = 'standard'; // 'standard' | 'vip'

  int _valorVipExtra = 0;
  bool _cargandoValorVip = false;

  Timer? _timerBusqueda;

  int _reintentosBusqueda = 0;
  String _mensajeBusqueda = "Buscando conductores cercanos...";
  int _conductoresConsultados = 0;

  Promocion? promocionAplicada;

  int descuentoPromocion = 0;

  int tarifaFinalConDescuento = 0;


  bool buscandoConductor = false;


  @override
  void initState() {
    super.initState();

    /// 🔥 WAVES
    _waveController = AnimationController(

      vsync: this,

      duration: const Duration(
        milliseconds: 4200,
      ),
    )..repeat();

    _loadingRoute = true;

    SchedulerBinding.instance
        .addPostFrameCallback((_) async {

      await connectionService
          .checkConnectionAndShowCard(

        context,

            () async {

          if (mounted) {
            setState(() {
              _loadingRoute = true;
            });
          }

          await _controller.init(
            context,
            refresh,
          );

          _controller.conductoresEncontradosCallback = (cantidad) {
            if (!mounted) return;

            // 🔥 NUEVO: Si el controlador envía -1, apagamos las ondas y la búsqueda de inmediato
            if (cantidad == -1) {
              setState(() {
                _conductoresConsultados = 0;
                isVisibleTarjetaSolicitandoConductor = false;
                _isSearching = false;
              });
              return; // Rompe la ejecución para que no asigne el -1 a la variable visual
            }

            // Si llega un número normal (0, 1, 2...), actualiza el contador en pantalla
            setState(() {
              _conductoresConsultados = cantidad;
            });
          };

          final args =
          ModalRoute.of(context)
              ?.settings
              .arguments

          as Map<String, dynamic>?;

          if (args != null) {

            final promoMap =
            args['promocion_aplicada'];

            if (promoMap != null) {

              promocionAplicada =
                  Promocion.fromJson(

                    promoMap['id'],

                    promoMap,
                  );

              descuentoPromocion =
                  promocionAplicada!
                      .bono;
            }
          }

          /// ✅ CARGAR VIP
          await _cargarValorVip();

          if (mounted) {

            setState(() {

              _loadingRoute = false;
            });
          }
        },
      );
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
    _timerBusqueda?.cancel();
    _controller.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    final base =

    _controller.total == null

        ? null

        : _controller.total!.toInt();
    final esVip = _tipoServicioSeleccionado == 'vip';

    tarifa =

    base == null

        ? null

        : base + (esVip ? _valorVipExtra : 0);

    if (tarifa == null) {

      tarifaFinalConDescuento = 0;

    } else {

      tarifaFinalConDescuento =
          tarifa! - descuentoPromocion;

      if (tarifaFinalConDescuento < 0) {

        tarifaFinalConDescuento = 0;
      }
    }
    formattedTarifa =

    tarifa == null

        ? ''

        : FormatUtils.formatCurrency(
      tarifa!,
    );

    formattedTarifaFinal =

    tarifa == null

        ? ''

        : FormatUtils.formatCurrency(
      tarifaFinalConDescuento,
    );
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

            Column(
              children: [

                /// 🔥 MAPA DINÁMICO
                Expanded(
                  flex: descuentoPromocion > 0 ? 3 : 4,

                  child: _googleMapsWidget(),
                ),

                /// 🔥 CAJÓN DINÁMICO
                SafeArea(
                  top: false,

                  child: AnimatedContainer(

                    duration:
                    const Duration(milliseconds: 350),

                    curve: Curves.easeInOut,

                    child: isVisibleTarjetaSolicitandoConductor

                        ? _cardSolicitudMinimizada()

                        : _cardInfoViaje(
                      from,
                      to,
                    ),
                  ),
                 ),

              ],
            ),

            /// 🔙 BOTÓN
            Align(
              alignment: Alignment.topLeft,
              child: _buttonVolverAtras(),
            ),

            /// 🔥 BUSCANDO CONDUCTOR
            Align(
              alignment: Alignment.bottomCenter,
              child: _tarjetaSolicitandoConductor(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardSolicitudMinimizada() {

    return Container(

      width: double.infinity,

      padding: EdgeInsets.only(
        top: 16.r,
        left: 20.r,
        right: 20.r,
        bottom:
        MediaQuery.of(context)
            .padding
            .bottom + 15.r,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),

        boxShadow: [

          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          /// 🔥 HANDLE
          Container(
            width: 45.r,
            height: 5.r,

            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius:
              BorderRadius.circular(20.r),
            ),
          ),

          SizedBox(height: 14.r),

          /// DESTINO
          Row(
            children: [

              Icon(
                Icons.location_on,
                color: primary,
                size: 18.r,
              ),

              SizedBox(width: 8.r),

              Expanded(
                child: Text(

                  _controller.to ?? '',

                  maxLines: 1,

                  overflow:
                  TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 14.r,
                    fontWeight: FontWeight.w800,
                    color: negro,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 14.r),

          /// TARIFA
          Container(

            padding: EdgeInsets.symmetric(
              horizontal: 14.r,
              vertical: 10.r,
            ),

            decoration: BoxDecoration(

              color:
              descuentoPromocion > 0
                  ? Colors.green.withOpacity(0.08)
                  : grisMapa,

              borderRadius:
              BorderRadius.circular(16.r),
            ),

            child: Row(

              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [

                Text(
                  descuentoPromocion > 0
                      ? 'TOTAL PROMO'
                      : 'TOTAL',

                  style: TextStyle(
                    fontSize: 12.r,
                    fontWeight: FontWeight.w800,
                    color:
                    descuentoPromocion > 0
                        ? Colors.green
                        : Colors.black54,
                  ),
                ),

                Text(

                  tarifa == null

                      ? 'Calculando...'

                      : tarifaFinalConDescuento <= 0 &&
                      descuentoPromocion > 0

                      ? 'Gratis 🎉'

                      : formattedTarifaFinal,

                  style: TextStyle(

                    fontSize:

                    tarifa == null

                        ? 16.r

                        : tarifaFinalConDescuento <= 0 &&
                        descuentoPromocion > 0

                        ? 16.r

                        : 18.r,

                    fontWeight: FontWeight.w900,

                    color:
                    descuentoPromocion > 0
                        ? Colors.green
                        : negro,
                  ),
                )
              ],
            ),
          ),

          SizedBox(height: 16.r),

          /// CANCELAR
          SizedBox(

            width: double.infinity,
            height: 48.r,

            child: ElevatedButton.icon(

              onPressed: () async {

                if (!mounted) return;

                final confirm = await showDialog<bool>(

                  context: context,

                  barrierDismissible: false,

                  builder: (context) {

                    return AlertDialog(

                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(15),
                      ),

                      title: const Text(
                        "Cancelar solicitud",
                      ),

                      content: const Text(
                        "¿Estás seguro de que quieres cancelar el servicio?",
                      ),

                      actions: [

                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),

                          child: const Text("No"),
                        ),

                        ElevatedButton(

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),

                          onPressed: () {
                            // 1. Cerramos el diálogo regresando 'true'
                            Navigator.pop(context, true);

                            // 2. 🔥 APAGAMOS TODOS LOS MOTORES LÓGICOS DE INMEDIATO
                            _timerBusqueda?.cancel();
                            _controller.detenerBusquedaLogica();
                          },


                          child: const Text(
                            "Sí, cancelar",
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (confirm != true) return;

                final hasInternet =
                await connectionService
                    .hasInternetConnection();

                if (!hasInternet) {

                  if(context.mounted){

                    showDialog(
                      context: context,

                      builder: (_) => AlertDialog(

                        title:
                        const Text(
                          "Sin conexión a internet",
                        ),

                        content: const Text(
                          "No podemos verificar el estado del servicio.\n\nEs posible que ya haya sido aceptado.",
                        ),

                        actions: [

                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context),

                            child:
                            const Text("Entendido"),
                          )
                        ],
                      ),
                    );
                  }

                  return;
                }

                final uid =
                    FirebaseAuth.instance
                        .currentUser
                        ?.uid;

                if (uid == null) return;

                final doc = await FirebaseFirestore.instance
                    .collection('TravelInfo')
                    .doc(uid)
                    .get();

                if (!doc.exists) return;

                final status = doc.get('status');

                /// 🔥 TODAVÍA NO ACEPTADO
                if (status == 'created') {


                  setState(() {

                    isVisibleTarjetaSolicitandoConductor =
                    false;

                    _isSearching = false;
                  });

                  await _controller.deleteTravelInfo();

                  _timerBusqueda?.cancel();
                }

                /// 🔥 YA ACEPTADO
                else {

                  if (!mounted) return;

                  Navigator.pushNamedAndRemoveUntil(

                    context,

                    'travel_map_page',

                        (route) => false,

                    arguments: uid,
                  );
                }
              },

              icon: Icon(
                Icons.close,
                size: 18.r,
              ),

              label: Text(
                'Cancelar solicitud',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.r,
                ),
              ),

              style: ElevatedButton.styleFrom(

                backgroundColor:
                Colors.red,

                foregroundColor:
                Colors.white,

                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void refresh(){
    if(mounted){
      setState(() {
      });
    }
  }

  void _mostrarDetalleTarifa() {

    if (tarifa == null) return;

    final tarifaBase = tarifa!
        - _controller.recargoNocturno.toInt()
        - _controller.recargoDominical.toInt()
        - _controller.recargoAeropuerto.toInt()
        - _controller.recargoYellowWoman.toInt();

    showModalBottomSheet(

      context: context,

      backgroundColor: Colors.transparent,

      builder: (_) {

        return Container(

          padding: EdgeInsets.all(20.r),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28.r),
              topRight: Radius.circular(28.r),
            ),
          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Container(
                width: 45.r,
                height: 5.r,

                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius:
                  BorderRadius.circular(20.r),
                ),
              ),

              SizedBox(height: 18.r),

              Text(

                'Detalle de la tarifa',

                style: TextStyle(
                  fontSize: 18.r,
                  fontWeight: FontWeight.w900,
                  color: negro,
                ),
              ),

              SizedBox(height: 20.r),

              _itemTarifa(
                'Tarifa base',
                tarifaBase,
              ),

              if (_controller.recargoNocturno > 0)

                _itemTarifa(
                  '🌙 Recargo nocturno',
                  _controller.recargoNocturno.toInt(),
                ),

              if (_controller.recargoDominical > 0)

                _itemTarifa(
                  '📅 Dominical/Festivo',
                  _controller.recargoDominical.toInt(),
                ),

              if (_controller.recargoAeropuerto > 0)

                _itemTarifa(
                  '✈️ Aeropuerto',
                  _controller.recargoAeropuerto.toInt(),
                ),

              if (_controller.recargoYellowWoman > 0)

                _itemTarifa(
                  '💛 YellowWoman',
                  _controller.recargoYellowWoman.toInt(),
                ),

              if (descuentoPromocion > 0)

                _itemTarifa(
                  '🎁 Bono MetaX',
                  -descuentoPromocion,
                  esDescuento: true,
                ),

              Divider(height: 28.r),

              Row(

                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

                children: [

                  Text(

                    'TOTAL',

                    style: TextStyle(
                      fontSize: 16.r,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  Text(

                    formattedTarifaFinal,

                    style: TextStyle(
                      fontSize: 18.r,
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: MediaQuery.of(context)
                    .padding
                    .bottom,
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _itemTarifa(
      String titulo,
      int valor, {
        bool esDescuento = false,
      }) {

    return Padding(

      padding: EdgeInsets.only(bottom: 12.r),

      child: Row(

        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,

        children: [

          Text(

            titulo,

            style: TextStyle(
              fontSize: 14.r,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          Text(

            esDescuento
                ? '- ${FormatUtils.formatCurrency(valor.abs())}'
                : '+ ${FormatUtils.formatCurrency(valor)}',

            style: TextStyle(

              fontSize: 14.r,

              fontWeight: FontWeight.w800,

              color:
              esDescuento
                  ? Colors.green
                  : Colors.black,
            ),
          ),
        ],
      ),
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
      markers:

      isVisibleTarjetaSolicitandoConductor

          ?

      Set<Marker>.of(

        _controller.markers.values.where(

              (marker) =>

          marker.markerId.value !=
              'to',
        ),
      )

          :

      Set<Marker>.of(
        _controller.markers.values,
      ),
      polylines:

      isVisibleTarjetaSolicitandoConductor

          ? {}

          : _loadingRoute

          ? {}

          : _controller.polylines,
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
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          topRight: Radius.circular(30.r),
        ),
        color: blanco,
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

          /// 🔵 SECCIÓN FROM / TO
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30.r),
                topRight: Radius.circular(30.r),
              ),
            ),
            child: Column(
              children: [

                Container(
                  margin: EdgeInsets.only(top: 15.r, left: 25.r, right: 25.r),
                  child: Row(
                    children: [
                      Image.asset('assets/ubicacion_client.png', height: 15.r, width: 15.r),
                      SizedBox(width: 5.r),
                      Expanded(
                        child: Text(
                          from,
                          style: TextStyle(fontSize: 12.r, color: negro),
                          maxLines: 1,
                        ),
                      )
                    ],
                  ),
                ),

                Container(
                  margin: EdgeInsets.only(left: 25.r, right: 25.r, bottom: 15.r),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/marker_destino.png', height: 15.r, width: 15.r),
                      SizedBox(width: 5.r),
                      Expanded(
                        child: Text(
                          to,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.r,
                            color: negro,
                            height: 1.1,
                          ),
                          maxLines: 2,
                        ),
                      )
                    ],
                  ),
                ),

              ],
            ),
          ),

          const SizedBox(height: 5),

          /// 📏 DISTANCIA / DURACIÓN / TARIFA
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
                        fontSize: 8.r,
                        color: negro,
                        fontWeight: FontWeight.w500,
                      ),
                      headerText(
                        text: _controller.km ?? '',
                        fontSize: 11.r,
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
                        fontSize: 8.r,
                        color: negro,
                        fontWeight: FontWeight.w500,
                      ),
                      headerText(
                        text: _controller.min ?? '',
                        fontSize: 11.r,
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

                    padding: EdgeInsets.symmetric(
                      horizontal: 6.r,
                    ),

                    child: GestureDetector(
                      onTap: () {

                        final tieneDetalles =

                            _controller.recargoNocturno > 0 ||

                                _controller.recargoDominical > 0 ||

                                _controller.recargoAeropuerto > 0 ||

                                _controller.recargoYellowWoman > 0 ||

                                descuentoPromocion > 0;

                        if (!tieneDetalles) return;

                        _mostrarDetalleTarifa();
                      },
                      child: Container(
                      
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.r,
                          vertical: 8.r,
                        ),
                      
                        decoration: BoxDecoration(
                      
                          color: Colors.white,
                      
                          borderRadius: BorderRadius.circular(20.r),
                      
                          boxShadow: [
                      
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              offset: const Offset(0, 2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                      
                          mainAxisSize: MainAxisSize.min,
                      
                          children: [
                      
                            Text(
                      
                              descuentoPromocion > 0
                                  ? 'PROMO'
                                  : 'Total',
                      
                              style: TextStyle(
                      
                                fontSize: 9.r,
                      
                                color: descuentoPromocion > 0
                                    ? Colors.green
                                    : Colors.black54,
                      
                                fontWeight: FontWeight.w900,
                      
                                letterSpacing:
                                descuentoPromocion > 0
                                    ? 0.5
                                    : 0,
                              ),
                            ),
                      
                            SizedBox(height: 2.r),
                      
                            headerText(

                              text:

                              tarifa == null

                                  ? 'Calculando...'

                                  : tarifaFinalConDescuento <= 0 &&
                                  descuentoPromocion > 0

                                  ? 'Gratis 🎉'

                                  : formattedTarifaFinal,

                              fontSize:

                              tarifa == null

                                  ? 13.r

                                  : tarifaFinalConDescuento <= 0 &&
                                  descuentoPromocion > 0

                                  ? 13.r

                                  : 17.r,
                      
                              color: descuentoPromocion > 0
                                  ? Colors.green
                                  : Colors.black,
                      
                              fontWeight: FontWeight.w900,
                            ),
                            SizedBox(height: 3.r),

                            if (
                            _controller.recargoNocturno > 0 ||
                                _controller.recargoDominical > 0 ||
                                _controller.recargoAeropuerto > 0 ||
                                _controller.recargoYellowWoman > 0 ||
                                descuentoPromocion > 0
                            )

                              Column(
                                children: [

                                  SizedBox(height: 3.r),

                                  Container(

                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.r,
                                      vertical: 2.r,
                                    ),

                                    decoration: BoxDecoration(

                                      color: primary.withOpacity(0.10),

                                      borderRadius:
                                      BorderRadius.circular(8.r),
                                    ),

                                    child: Row(

                                      mainAxisSize: MainAxisSize.min,

                                      children: [

                                        Icon(
                                          Icons.receipt_long,
                                          size: 10.r,
                                          color: Colors.black,
                                        ),

                                        SizedBox(width: 3.r),

                                        Text(

                                          'Ver detalles',

                                          style: TextStyle(

                                            fontSize: 9.r,

                                            fontWeight: FontWeight.w800,

                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          /// MÉTODOS DE PAGO
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cómo quieres pagar?',
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

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.r),
            child: _textApuntes(),
          ),

          SizedBox(height: 12.r),

          /// BOTÓN
          Container(
            width: double.infinity,
            height: 50.r,
            margin: EdgeInsets.only(

              left: 25.r,
              right: 25.r,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            child: ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
                padding: EdgeInsets.symmetric(vertical: 10.r),
              ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    ),
                    SizedBox(width: 8.r),
                    Text(
                      'Calculando ruta...',
                      style: TextStyle(
                        color: Colors.black,
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
                    Text(
                      'SOLICITAR SERVICIO',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16.r,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _resumenPromocion() {

    return Container(

      margin: EdgeInsets.symmetric(
        horizontal: 17.r,
        vertical: 6.r,
      ),

      padding: EdgeInsets.all(12.r),

      decoration: BoxDecoration(

        color: Colors.green.withOpacity(0.06),

        borderRadius: BorderRadius.circular(18.r),

        border: Border.all(
          color: Colors.green.withOpacity(0.25),
        ),
      ),

      child: Column(
        children: [

          /// SUBTOTAL
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

            children: [

              Text(
                'Tarifa estimada',

                style: TextStyle(
                  fontSize: 13.r,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),

              Text(
                formattedTarifa,

                style: TextStyle(
                  fontSize: 13.r,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          SizedBox(height: 8.r),

          /// BONO
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

            children: [

              Row(
                children: [

                  Icon(
                    Icons.local_offer,
                    color: Colors.green,
                    size: 16.r,
                  ),

                  SizedBox(width: 5.r),

                  Text(
                    'Bono MetaX',

                    style: TextStyle(
                      fontSize: 13.r,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              Text(
                '- ${FormatUtils.formatCurrency(descuentoPromocion)}',

                style: TextStyle(
                  fontSize: 14.r,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 12.r),

          Divider(
            color: Colors.green.withOpacity(0.2),
            height: 1,
          ),

          SizedBox(height: 12.r),

          /// TOTAL FINAL
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

            children: [

              Text(
                'Total a pagar',

                style: TextStyle(
                  fontSize: 15.r,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),

              Text(

                tarifa == null

                    ? 'Calculando...'

                    : tarifaFinalConDescuento <= 0 &&
                    descuentoPromocion > 0

                    ? 'Gratis 🎉'

                    : formattedTarifaFinal,

                style: TextStyle(

                  fontSize: tarifaFinalConDescuento <= 0
                      ? 15.r
                      : 17.r,

                  fontWeight: FontWeight.w900,

                  color: Colors.green,
                ),
              )
            ],
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
    const Color verde = Colors.green;

    return GestureDetector(
      onTap: () {
        setState(() {
          _metodoPagoSeleccionado = metodo;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 6.r),
        decoration: BoxDecoration(
          color: seleccionado ? verde.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: seleccionado ? verde : Colors.grey.shade300,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14.r,
              height: 14.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: seleccionado ? verde : Colors.grey,
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
                    color: verde,
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
    return Column(
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
              border: Border.all(color: grisMedio, width: 1.3),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _caracteristicaSeleccionada,
                isExpanded: true, // ✅ CLAVE para que ocupe todo el ancho
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: grisMedio,
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
      );
  }


  void verificarCedulaInicial() async {

    _startSearch();

    /// 🔥 1. VALIDAR SI HAY CONDUCTORES ANTES DE TODO
    bool hayConductores =
    await _controller.hayConductoresEnRadio();

    if (!hayConductores) {

      if (mounted) {

        setState(() {

          isVisibleTarjetaSolicitandoConductor =
          false;

          _isSearching = false;
        });
      }

      if (context.mounted) {

        showDialog(

          context: context,

          builder: (context) {

            return AlertDialog(

              shape: RoundedRectangleBorder(

                borderRadius:
                BorderRadius.circular(16),
              ),

              contentPadding:
              const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                10,
              ),

              content: Column(

                mainAxisSize:
                MainAxisSize.min,

                children: [

                  /// 🔥 LOGO
                  Image.asset(

                    'assets/metax_logo.png',

                    height: 70,
                  ),

                  const SizedBox(height: 10),

                  /// 🔥 TÍTULO
                  const Text(

                    "Sin taxis cercanos",

                    textAlign:
                    TextAlign.center,

                    style: TextStyle(

                      fontWeight:
                      FontWeight.w900,

                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// 🔥 MENSAJE
                  const Text(

                    "No hay taxis disponibles cerca en este momento 🚕\n\nPuedes intentarlo nuevamente en unos segundos.",

                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(fontSize: 14),
                  ),
                ],
              ),

              actionsAlignment:
              MainAxisAlignment.center,

              actions: [

                SizedBox(

                  width: double.infinity,

                  child: TextButton(

                    style:
                    TextButton.styleFrom(

                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),

                    onPressed: () =>
                        Navigator.pop(context),

                    child: const Text(

                      "Entendido",

                      style: TextStyle(

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }

      return;
    }

    /// 🔥 2. SOLO SI HAY CONDUCTORES
    if (mounted) {

      /// 🔥 ACTIVAR MODO BÚSQUEDA
      _controller.buscandoConductor = true;

      setState(() {

        isVisibleTarjetaSolicitandoConductor =
        true;
      });
    }

    /// 🔥 CENTRAR MAPA EN ORIGEN
    await _controller.animateCameraToPosition(

      _controller.fromLatlng.latitude,

      _controller.fromLatlng.longitude,
    );

    final esVip =
        _tipoServicioSeleccionado == 'vip';

    /// 🔥 3. CREAR VIAJE
    bool viajeCreado =
    await _controller.createTravelInfo(

      tipoServicio:
      _tipoServicioSeleccionado,

      valorVipExtra:
      esVip ? _valorVipExtra : 0,

      tarifaFinal:
      tarifaFinalConDescuento,

      metodoPago:
      _metodoPagoSeleccionado,

      caracteristicaVehiculo:
      _caracteristicaSeleccionada,

      /// 🔥 NUEVOS
      recargoNocturno:
      _controller.recargoNocturno,

      recargoDominical:
      _controller.recargoDominical,

      recargoAeropuerto:
      _controller.recargoAeropuerto,

      recargoYellowWoman:
      _controller.recargoYellowWoman,

      promocionId:
      promocionAplicada?.id,

      descuentoPromocion:
      descuentoPromocion,

      tarifaOriginal:
      tarifa!,
    );

    if (!viajeCreado) {

      if (mounted) {

        setState(() {

          isVisibleTarjetaSolicitandoConductor =
          false;

          _isSearching = false;
        });
      }

      return;
    }

    /// 🔥 4. INICIAR BÚSQUEDA
    _controller.getNearbyDrivers();
  }

  Widget _tarjetaSolicitandoConductor() {

    if (!mounted) {
      return Container();
    }

    return Visibility(

      visible:
      isVisibleTarjetaSolicitandoConductor,

      child: IgnorePointer(

        ignoring: true,

        child: Center(

          child: Stack(

            alignment: Alignment.center,

            children: [

              /// 🔥 OLAS CENTRADAS REALES
              Positioned.fill(

                child: Builder(

                  builder: (_) {

                    /// 🔥 ALTURA APROX DEL CAJÓN
                    final bottomSheetHeight = 260.r;

                    return Transform.translate(

                      offset: Offset(
                        0,
                        -(bottomSheetHeight / 2),
                      ),

                      child: Center(

                        child: AnimatedBuilder(

                          animation: _waveController,

                          builder: (_, __) {

                            return Stack(

                              alignment: Alignment.center,

                              children: [

                                _buildWave(
                                  _waveController.value,
                                  0.32,
                                ),

                                _buildWave(
                                  (_waveController.value + 0.33) % 1,
                                  0.24,
                                ),

                                _buildWave(
                                  (_waveController.value + 0.66) % 1,
                                  0.16,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              /// 🔥 TARJETA INDEPENDIENTE
              Positioned(

                top: 60.r,

                left: 0,

                right: 0,

                child: Center(

                  child: Container(

                    padding: EdgeInsets.symmetric(

                      horizontal: 18.r,

                      vertical: 12.r,
                    ),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius:
                      BorderRadius.circular(
                        18.r,
                      ),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors.black.withOpacity(
                            0.08,
                          ),

                          blurRadius: 10,
                        ),
                      ],
                    ),

                    child: Column(

                      mainAxisSize:
                      MainAxisSize.min,

                      children: [

                        Text(

                          'Buscando un conductor...',

                          textAlign: TextAlign.center,

                          style: TextStyle(

                            fontWeight:
                            FontWeight.w800,

                            fontSize: 14.r,

                            color: negro,
                          ),
                        ),

                        SizedBox(height: 5.r),

                        if (_conductoresConsultados > 0)

                          Text(

                            '$_conductoresConsultados '
                                '${_conductoresConsultados == 1 ? 'taxi cercano' : 'taxis cercanos'}',

                            style: TextStyle(

                              fontSize: 12.r,

                              color: Colors.black54,

                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWave(

      double progress,

      double opacity,
      ) {

    final screenWidth =
        MediaQuery.of(context)
            .size
            .width;

    final size =

        120 +

            (screenWidth * 1.8 * progress);

    return Container(

      width: size,

      height: size,

      decoration: BoxDecoration(

        shape: BoxShape.circle,

        color:
        const Color(0xFFBDBDBD)
            .withOpacity(

          (1 - progress) *
              opacity *
              0.14,
        ),

        border: Border.all(

          color:
          const Color(0xFFBDBDBD)
              .withOpacity(

            (1 - progress) *
                opacity,
          ),

          width: 10,
        ),

        boxShadow: [

          BoxShadow(

            color:
            const Color(0xFFBDBDBD)
                .withOpacity(

              (1 - progress) *
                  opacity *
                  0.25,
            ),

            blurRadius: 35,

            spreadRadius: 8,
          ),
        ],
      ),
    );
  }

  void _startSearch() {

    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    _timerBusqueda?.cancel();
    _reintentosBusqueda = 0;

    _timerBusqueda = Timer.periodic(
      const Duration(seconds: 1),
          (timer) async {

        // =========================================================================
        // 🛑 🔥 APAGADOR GLOBAL: Si el controlador detuvo el radar, matamos el timer
        // =========================================================================
        if (!_controller.buscandoConductor) {
          print("⏹️ [VISTA METAX] El controlador apagó el radar. Cancelando Timer de la vista.");
          timer.cancel();
          if (mounted) {
            setState(() {
              isVisibleTarjetaSolicitandoConductor = false;
              _isSearching = false;
            });
          }
          return;
        }
        // =========================================================================

        /// 🌐 INTERNET
        if (!await connectionService.hasInternetConnection()) {
          print("⛔ Sin internet → detener búsqueda");
          timer.cancel();
          if (mounted) {
            setState(() {
              _mensajeBusqueda = "📡 Sin conexión, reconectando...";
              _isSearching = false;
            });
          }
          return;
        }

        /// 🛑 YA ACEPTADO
        if (_controller.serviceAccepted) {
          print("🛑 Servicio aceptado → detener búsqueda");
          timer.cancel();
          return;
        }

        /// 🔥 SIN VIP
        if (_tipoServicioSeleccionado == "vip" &&
            _controller.yaIntentoTodosLosVIP &&
            !_controller.serviceAccepted) {

          print("⚠️ No hay VIP reales → mostrar opción");
          _controller.yaIntentoTodosLosVIP = false;

          if (!mounted) return;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  "Sin vehículos VIP",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                content: const Text(
                  "No encontramos vehículos VIP disponibles.\n\n¿Deseas buscar un servicio estándar?",
                  textAlign: TextAlign.center,
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  /// 🔥 STANDARD
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        print("🔁 Usuario acepta estándar");
                        await _controller.deleteTravelInfo();
                        final base = _controller.total?.toInt() ?? 0;

                        await _controller.createTravelInfo(
                          tipoServicio: "standard",
                          valorVipExtra: 0,
                          tarifaFinal: base,
                          metodoPago: _metodoPagoSeleccionado,
                          caracteristicaVehiculo: _caracteristicaSeleccionada,
                          recargoNocturno: _controller.recargoNocturno,
                          recargoDominical: _controller.recargoDominical,
                          recargoAeropuerto: _controller.recargoAeropuerto,
                          recargoYellowWoman: _controller.recargoYellowWoman,
                        );

                        _reintentosBusqueda = 0;
                        _controller.getNearbyDrivers();

                        Future.delayed(
                          const Duration(milliseconds: 1500),
                              () {
                            if (!mounted) return;
                            _startSearch();
                          },
                        );
                      },
                      child: const Text("Buscar servicio estándar"),
                    ),
                  ),

                  /// 🔴 CANCELAR
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _controller.deleteTravelInfo();
                        _timerBusqueda?.cancel();
                        setState(() {
                          isVisibleTarjetaSolicitandoConductor = false;
                          _isSearching = false;
                        });
                      },
                      child: const Text("Cancelar"),
                    ),
                  ),
                ],
              );
            },
          );
          return;
        }

        /// 🔥 CICLOS
        _reintentosBusqueda++;
      },
    );
  }

}

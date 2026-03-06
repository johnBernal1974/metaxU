import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../src/colors/colors.dart';
import '../travel_info_page/travel_info_Controller/travel_info_Controller.dart';

class HomePorteriaPage extends StatefulWidget {
  const HomePorteriaPage({super.key});

  @override
  State<HomePorteriaPage> createState() => _HomePorteriaPageState();
}

class _HomePorteriaPageState extends State<HomePorteriaPage> {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TravelInfoController _travelController = TravelInfoController();

  String nombrePorteria = "";
  String nombreConjunto = "";
  String direccion = "";

  String _metodoPagoSeleccionado = 'Efectivo';
  String _caracteristicaSeleccionada = 'No';

  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController aptoController = TextEditingController();

  double? latPorteria;
  double? lngPorteria;


  final List<String> _caracteristicasVehiculo = [
    'No',
    'Aire acondicionado',
    'Vidrios polarizados',
    'Con baúl',
    'Porta bicicletas',
    'Silla de ruedas',
    'Con mascota',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _travelController.init(context, () {
        setState(() {});
      });
    });

    _loadPorteria();
  }

  Future<void> _loadPorteria() async {

    final uid = _auth.currentUser?.uid;

    if (uid == null) return;

    final doc = await _firestore
        .collection("UsuariosPorteria")
        .doc(uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    print(data);

    setState(() {
      nombrePorteria = data["nombrePorteria"] ?? "";
      nombreConjunto = data["nombreConjunto"] ?? "";
      direccion = data["direccion"] ?? "";

      latPorteria = data["lat"];
      lngPorteria = data["lng"];
    });

    print("====== PORTERIA CARGADA ======");
    print("Porteria: $nombrePorteria");
    print("Direccion: $direccion");
    print("Lat: $latPorteria");
    print("Lng: $lngPorteria");
    print("===============================");

    /// CONFIGURAR ORIGEN PARA GEO FIRE
    _travelController.from = direccion;

    _travelController.fromLatlng = LatLng(
      latPorteria!,
      lngPorteria!,
    );

    print("Preparando GeoFire...");
    print("FromLatLng: ${_travelController.fromLatlng}");

    /// OBTENER RADIO DE BUSQUEDA
    _travelController.obtenerRadiodeBusqueda();

    print("Radio de búsqueda: ${_travelController.radioDeBusqueda}");

    /// BUSCAR CONDUCTORES CERCANOS
    _travelController.getNearbyDriversPorteria();
  }

  @override
  Widget build(BuildContext context) {

    ScreenUtil.init(context, designSize: const Size(375, 812));

    return Scaffold(
      backgroundColor: grisMapa,

      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 10.r),
            constraints: const BoxConstraints(maxWidth: 900),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                /// =========================
                /// TAXI
                /// =========================

                Image.asset(
                  "assets/imagen_taxi.png",
                  height: 50.r,
                ),

                /// =========================
                /// LOGO METAX
                /// =========================

                Image.asset(
                  "assets/metax_logo.png",
                  height: 45.r,
                ),

                SizedBox(height: 10.r),

                /// =========================
                /// NOMBRE CONJUNTO
                /// =========================

                Text(
                  nombreConjunto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.r,
                    fontWeight: FontWeight.w900,
                    color: negro,
                    height: 1.1
                  ),
                ),

                SizedBox(height: 4.r),

                /// =========================
                /// NOMBRE PORTERIA
                /// =========================

                Text(
                  "Portería $nombrePorteria",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.r,
                    fontWeight: FontWeight.w700,
                    color: negro,
                  ),
                ),

                /// =========================
                /// DIRECCION
                /// =========================

                Text(
                  direccion,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.r,
                    color: Colors.black,
                  ),
                ),

                SizedBox(height: 15.r),
                Builder(
                  builder: (context) {
                    print("UI taxis cerca: ${_travelController.nearbyDrivers.length}");

                    final taxisCerca = _travelController.nearbyDrivers.length;

                    final texto = taxisCerca == 0
                        ? "No hay taxis disponibles"
                        : taxisCerca == 1
                        ? "1 taxi disponible cerca"
                        : "$taxisCerca taxis disponibles cerca";

                    final colorBorde =
                    taxisCerca == 0 ? Colors.red.shade300 : Colors.green;

                    final icono =
                    taxisCerca == 0
                        ? Icons.warning_amber_rounded
                        : Icons.local_taxi;

                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: colorBorde,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          Icon(
                            icono,
                            color: negro,
                            size: 20.r,
                          ),

                          SizedBox(width: 8.r),

                          Text(
                            texto,
                            style: TextStyle(
                              fontSize: 14.r,
                              fontWeight: FontWeight.w900,
                              color: negro,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                SizedBox(height: 20.r),

                /// =========================
                /// METODO DE PAGO
                /// =========================

                _metodoPagoSelector(),

                SizedBox(height: 10.r),

                /// =========================
                /// CARACTERISTICAS
                /// =========================

                _selectorCaracteristicas(),


                SizedBox(height: 10.r),

                _buildUsuarioField(),

                SizedBox(height: 12.r),

                _buildAptoField(),
                SizedBox(height: 20.r),

                /// =========================
                /// BOTON SOLICITAR SERVICIO
                /// =========================

                SizedBox(
                  width: double.infinity,
                  height: 42.r,
                  child: OutlinedButton(
                    onPressed: _solicitarServicio,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        Icon(
                          Icons.local_taxi,
                          color: negro,
                          size: 22.r,
                        ),

                        SizedBox(width: 8.r),

                        Text(
                          "SOLICITAR SERVICIO",
                          style: TextStyle(
                            fontSize: 14.r,
                            fontWeight: FontWeight.w900,
                            color: negro,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                /// margen inferior seguro para gestos
                SizedBox(height: 30.r),

              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ===============================
  /// METODO DE PAGO
  /// ===============================

  Widget _metodoPagoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// TITULO
        Text(
          "Método de pago",
          style: TextStyle(
            fontSize: 12.r,
            fontWeight: FontWeight.w800,
            color: negro,
          ),
        ),

        SizedBox(height: 8.r),

        /// OPCIONES
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMetodoPagoItem('Efectivo'),
            SizedBox(width: 10.r),
            _buildMetodoPagoItem('Nequi'),
            SizedBox(width: 10.r),
            _buildMetodoPagoItem('Daviplata'),
          ],
        ),
      ],
    );
  }



  Widget _buildUsuarioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          "Usuario",
          style: TextStyle(
            fontSize: 12.r,
            fontWeight: FontWeight.w800,
            color: negro,
          ),
        ),

        SizedBox(height: 6.r),

        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: primary, width: 1.3),
          ),

          child: TextField(
            controller: usuarioController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              fontSize: 13.r,
              fontWeight: FontWeight.w700,
              color: negro,
            ),

            decoration: const InputDecoration(
              hintText: "Ej: Jorge Pérez",
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAptoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          "Apto / Torre / Casa (opcional)",
          style: TextStyle(
            fontSize: 12.r,
            fontWeight: FontWeight.w800,
            color: negro,
          ),
        ),

        SizedBox(height: 6.r),

        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: primary, width: 1.3),
          ),

          child: TextField(
            controller: aptoController,
            style: TextStyle(
              fontSize: 13.r,
              fontWeight: FontWeight.w700,
              color: negro,
            ),

            decoration: const InputDecoration(
              hintText: "Ej: Torre B - Apto 302",
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetodoPagoItem(String metodo) {

    final seleccionado = _metodoPagoSeleccionado == metodo;

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
          children: [

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

  /// ===============================
  /// CARACTERISTICAS
  /// ===============================

  Widget _selectorCaracteristicas() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// TITULO
        Text(
          "Características del vehículo",
          style: TextStyle(
            fontSize: 12.r,
            fontWeight: FontWeight.w800,
            color: negro,
          ),
        ),

        SizedBox(height: 8.r),

        /// SELECTOR
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
              isExpanded: true,

              items: _caracteristicasVehiculo.map((c) {

                return DropdownMenuItem(
                  value: c,
                  child: Text(
                    c,
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

  Future<void> _solicitarServicio() async {

    if (usuarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes escribir el nombre del usuario")),
      );
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    /// 1️⃣ CREAR TRAVEL REQUEST
    final docRef = await _firestore.collection("TravelRequests").add({

      "tipoSolicitud": "porteria",
      "porteriaId": uid,

      "nombreConjunto": nombreConjunto,
      "nombrePorteria": nombrePorteria,
      "direccion": direccion,

      "lat": latPorteria,
      "lng": lngPorteria,

      "usuario": usuarioController.text.trim(),
      "apto": aptoController.text.trim(),

      "metodoPago": _metodoPagoSeleccionado,
      "caracteristica": _caracteristicaSeleccionada,

      "status": "created",
      "timestamp": FieldValue.serverTimestamp(),

    });

    final requestId = docRef.id;

    await _firestore.collection("TravelInfo").doc(requestId).set({

      "from": direccion,
      "fromLat": latPorteria,
      "fromLng": lngPorteria,

      "status": "created",
      "tipoSolicitud": "porteria",

      "timestamp": FieldValue.serverTimestamp(),

    });

    /// 3️⃣ ACTIVAR BUSQUEDA DE CONDUCTORES

    _travelController.from = direccion;

    _travelController.fromLatlng = LatLng(
      latPorteria!,
      lngPorteria!,
    );

   _travelController.obtenerRadiodeBusqueda();

    _travelController.getNearbyDriversPorteria();
  }
}
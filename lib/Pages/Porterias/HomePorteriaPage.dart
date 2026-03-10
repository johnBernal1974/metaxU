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
  String ciudad = "";
  String barrio = "";

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
      ciudad = data["ciudad"] ?? "";
      barrio = data["barrio"] ?? "";

      latPorteria = data["lat"];
      lngPorteria = data["lng"];
    });

    /// CONFIGURAR ORIGEN PARA GEO FIRE
    _travelController.from = direccion;

    _travelController.fromLatlng = LatLng(
      latPorteria!,
      lngPorteria!,
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));

    return Scaffold(
      backgroundColor: grisMapa,
      drawer: _menuPorteria(),
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, right: 16),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("TravelRequests")
                .where(
              "porteriaId",
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
                .snapshots(),
            builder: (context, snapshot) {

              int cantidad = 0;
              bool taxiEsperando = false;

              if (snapshot.hasData) {

                final docs = snapshot.data!.docs.where((doc) {

                  final data = doc.data() as Map<String, dynamic>;
                  final status = data["status"];

                  return status == "created" ||
                      status == "accepted" ||
                      status == "driver_on_the_way" ||
                      status == "driver_is_waiting";

                }).toList();

                cantidad = docs.length;

                taxiEsperando = docs.any((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data["status"] == "driver_is_waiting";
                });

              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: taxiEsperando
                      ? Colors.green
                      : Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: taxiEsperando
                          ? Colors.green.withOpacity(0.6)
                          : Colors.black.withOpacity(0.15),
                      blurRadius: taxiEsperando ? 18 : 8,
                      spreadRadius: taxiEsperando ? 2 : 0,
                    )
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(35),
                  onTap: () {
                    Navigator.pushNamed(context, "viajes_porteria");
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [

                      Center(
                        child: Text(
                          "Solicitudes",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: taxiEsperando
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),

                      if (cantidad > 0)
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              "$cantidad",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 10.r),
            constraints: const BoxConstraints(maxWidth: 900),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                /// HEADER (MENU + LOGO)
                Builder(
                  builder: (context) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        IconButton(
                          icon: const Icon(
                            Icons.menu,
                            size: 28,
                          ),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            "assets/metax_logo2.png",
                            height: 25.r,
                          ),
                        ),

                        /// espacio para balancear el Row
                        SizedBox(width: 40.r),

                      ],
                    );
                  },
                ),

                SizedBox(height: 10.r),

                /// NOMBRE CONJUNTO
                Text(
                  nombreConjunto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.r,
                    fontWeight: FontWeight.w900,
                    color: negro,
                    height: 1.1,
                  ),
                ),

                /// NOMBRE PORTERIA
                Text(
                  "Portería $nombrePorteria",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.r,
                    fontWeight: FontWeight.w700,
                    color: negro,
                  ),
                ),
                SizedBox(height: 15.r),

                _metodoPagoSelector(),

                SizedBox(height: 10.r),

                _selectorCaracteristicas(),

                SizedBox(height: 10.r),

                _buildUsuarioField(),

                SizedBox(height: 12.r),

                _buildAptoField(),

                SizedBox(height: 40.r),

                /// BOTON SOLICITAR SERVICIO
                SizedBox(
                  width: double.infinity,
                  height: 44.r,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _solicitarServicio();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      elevation: 4,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        Icon(
                          Icons.send_to_mobile,
                          color: Colors.black,
                          size: 22.r,
                        ),

                        SizedBox(width: 8.r),

                        Text(
                          "SOLICITAR SERVICIO",
                          style: TextStyle(
                            fontSize: 14.r,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30.r),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuPorteria() {
    return Drawer(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: DrawerHeader(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(
                color: primary,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      nombreConjunto,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.1
                      ),
                    ),
                    Text(
                      "Portería $nombrePorteria",

                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1
                      ),
                    ),
                    Text(
                      direccion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.r,
                        color: Colors.black,
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [

                        Text(
                          barrio,
                          style: TextStyle(
                            fontSize: 10.r,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),

                        SizedBox(width: 6.r),

                        Text(
                          "-",
                          style: TextStyle(
                            fontSize: 10.r,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),

                        SizedBox(width: 6.r),

                        Text(
                          ciudad,
                          style: TextStyle(
                            fontSize: 10.r,
                            color: Colors.black,
                          ),
                        ),

                      ],
                    ),

                  ],
                ),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.send_to_mobile),
            title: const Text("Solicitar servicio"),
            onTap: () {
              Navigator.pop(context);
            },
          ),

          ListTile(
            leading: const Icon(Icons.local_taxi),
            title: const Text("Viajes activos"),
            onTap: () {
              Navigator.pushNamed(context, "viajes_porteria");
            },
          ),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("Historial"),
            onTap: () {
              Navigator.pushNamed(context, "historial_porteria");
            },
          ),

          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text("Contacto"),
            onTap: () {
              Navigator.pushNamed(context, "contacto_porteria");
            },
          ),

          const Spacer(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Cerrar sesión"),
            onTap: () async {

              await FirebaseAuth.instance.signOut();

              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  'login',
                      (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),

        ],
      ),
    );
  }

  Widget _metodoPagoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// TITULO
        Text(
          "Selecciona el método de pago",
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
          "Nombre del pasajero",
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

  Widget _selectorCaracteristicas() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// TITULO
        Text(
          "¿Algún requerimiento especial?",
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

    /// validar nombre del usuario
    if (usuarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes escribir el nombre del usuario"),
        ),
      );
      return;
    }

    /// guardar valores antes de limpiar
    final usuario = usuarioController.text.trim();
    final apto = aptoController.text.trim();

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    /// 1️⃣ CREAR TRAVEL REQUEST

    final docRef = await _firestore.collection("TravelRequests").add({

      "tipoSolicitud": "porteria",
      "porteriaId": uid,

      "nombreConjunto": nombreConjunto,
      "barrio": barrio,
      "nombrePorteria": nombrePorteria,
      "direccion": direccion,

      "lat": latPorteria,
      "lng": lngPorteria,

      "usuario": usuario,
      "apto": apto,

      "metodoPago": _metodoPagoSeleccionado,
      "caracteristica": _caracteristicaSeleccionada,

      "status": "created",
      "timestamp": FieldValue.serverTimestamp(),
    });

    final requestId = docRef.id;

    _travelController.requestId = requestId;

    /// 2️⃣ CREAR TRAVEL INFO

    await _firestore.collection("TravelInfo").doc(requestId).set({

      "from": direccion,
      "fromLat": latPorteria,
      "fromLng": lngPorteria,

      "status": "created",
      "tipoSolicitud": "porteria",

      "timestamp": FieldValue.serverTimestamp(),
    });

    /// 3️⃣ INICIAR BUSQUEDA DE CONDUCTORES

    _travelController.from = direccion;

    _travelController.fromLatlng = LatLng(
      latPorteria!,
      lngPorteria!,
    );

    _travelController.obtenerRadiodeBusqueda();
    _travelController.getNearbyDriversPorteria();

    /// 4️⃣ LIMPIAR CAMPOS
    usuarioController.clear();
    aptoController.clear();

    /// 5️⃣ MOSTRAR ALERT
    _mostrarServicioSolicitado(context, usuario, apto);
  }

  void _mostrarServicioSolicitado(
      BuildContext context,
      String usuario,
      String apto,
      ) {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {

        return AlertDialog(

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          title: const Text(
            "Servicio solicitado",
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const SizedBox(height: 5),

              Text(
                "Servicio solicitado para:",
                style: TextStyle(
                  fontSize: 14.r,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                usuario,
                style: TextStyle(
                  fontSize: 18.r,
                  fontWeight: FontWeight.w900,
                ),
              ),

              if (apto.isNotEmpty)
                Text(
                  "Apto: $apto",
                  style: TextStyle(
                    fontSize: 14.r,
                    fontWeight: FontWeight.w700,
                  ),
                ),

              const SizedBox(height: 15),

              Text(
                "Esperando respuesta del conductor...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.r,
                  color: Colors.black54,
                ),
              ),

            ],
          ),

          actions: [

            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Entendido",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 10),

          ],
        );
      },
    );
  }

}
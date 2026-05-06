import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../helpers/sound_manager.dart';
import '../../src/colors/colors.dart';
import '../travel_info_page/travel_info_Controller/travel_info_Controller.dart';
import 'package:vibration/vibration.dart';

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

  bool _yaVibroTaxi = false;
  String _ultimoEstadoBoton = "";

  final SoundManager _sound = SoundManager();

  final Set<String> taxisNotificados = {};

  bool _solicitandoServicio = false;
  int tiempoEsperaPorteria = 10;


  final List<String> _caracteristicasVehiculo = [
    'No',
    'Aire acondicionado',
    'Vidrios polarizados',
    'Con baúl',
    'Porta bicicletas',
    'Silla de ruedas',
    'Con mascota',
  ];

  int cantidad = 0;
  bool taxiEsperando = false;
  bool hayCancelaciones = false;

  String textoBoton = "Solicitudes";
  Color colorBoton = primary.withOpacity(0.7);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      _travelController.init(context, () {
        setState(() {});
      });

      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {

        usuarioController.text = args["usuario"] ?? "";
        aptoController.text = args["apto"] ?? "";

        setState(() {
          _metodoPagoSeleccionado = args["metodoPago"] ?? "Efectivo";
          _caracteristicaSeleccionada = args["caracteristica"] ?? "No";
        });

        /// auto solicitar
        if (args["autoSolicitar"] == true) {
          Future.delayed(const Duration(milliseconds: 400), () {
            _solicitarServicio();
          });
        }

      }

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

      body: Stack(
        children: [
        SafeArea(
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
                              color: primary.withOpacity(0.7),
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
                              height: 20.r,
                            ),
                          ),

                          /// WIDGET SOLICITUDES
                          _widgetSolicitudes(),

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
                        onPressed: _solicitandoServicio
                            ? null
                            : () async {
                          await _solicitarServicio();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary.withOpacity(0.7),
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: Text(
                          "SOLICITAR SERVICIO",
                          style: TextStyle(
                            fontSize: 14.r,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      )
                  ),
                  SizedBox(height: 30.r),

                ],
              ),
            ),
          ),
        ),

       ]
      ),
    );
  }

  Future<void> _notificarCambioEstado(String estado) async {

    if (_ultimoEstadoBoton == estado) return;

    _ultimoEstadoBoton = estado;

    final hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator ?? false) {

      if (estado == "taxi") {
        Vibration.vibrate(pattern: [0, 200, 100, 200]);
        _sound.playTaxiLlegada();
      }

      else if (estado == "cancelacion") {
        Vibration.vibrate(pattern: [0, 300, 150, 300]);
        _sound.playCancelacionConductor; // si lo tienes en tu SoundManager
      }
    }
  }


  Widget _widgetSolicitudes() {

    return StreamBuilder<QuerySnapshot>(
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
        bool hayCancelaciones = false;

        String textoBoton = "Solicitudes";
        Color colorBoton = primary.withOpacity(0.7);

        if (snapshot.hasData) {

          final docs = snapshot.data!.docs.where((doc) {

            final data = doc.data() as Map<String, dynamic>;

            final status = data["status"];
            final subStatus = data["subStatus"];

            /// excluir desistidos
            if (subStatus == "desistido") return false;

            return status == "created" ||
                status == "accepted" ||
                status == "driver_on_the_way" ||
                status == "driver_is_waiting" ||
                status == "cancelByDriverAfterAccepted" ||
                status == "cancelTimeIsOver";

          }).toList();

          cantidad = docs.length;

          /// detectar taxi esperando
          taxiEsperando = docs.any((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data["status"] == "driver_is_waiting";
          });

          /// detectar cancelaciones (solo de los docs filtrados)
          hayCancelaciones = docs.any((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data["status"];

            return status == "cancelByDriverAfterAccepted" ||
                status == "cancelTimeIsOver";
          });

          /// vibración + sonido cuando llega taxi
          if (taxiEsperando && !_yaVibroTaxi) {

            _yaVibroTaxi = true;

            Vibration.hasVibrator().then((value) {
              if (value ?? false) {
                Vibration.vibrate(duration: 400);
              }
            });

            _sound.playTaxiLlegada();
          }

          /// reset cuando ya no hay taxi esperando
          if (!taxiEsperando) {
            _yaVibroTaxi = false;
          }

          /// prioridad visual
          if (taxiEsperando) {

            textoBoton = "Taxi llegó";
            colorBoton = Colors.green;

            _notificarCambioEstado("taxi");

          }
          else if (hayCancelaciones) {

            textoBoton = "Cancelación";
            colorBoton = Colors.red;

            _notificarCambioEstado("cancelacion");

          }
          else if (cantidad > 0) {

            textoBoton = "Solicitudes";
            colorBoton = primary.withOpacity(0.7);

            _notificarCambioEstado("solicitud");

          }
          else {

            _ultimoEstadoBoton = "";

          }

        }

        return InkWell(
          onTap: () {
            Navigator.pushNamed(context, "viajes_porteria");
          },
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [

                /// lado izquierdo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorBoton,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    textoBoton,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                /// lado derecho
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(10),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$cantidad",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuPorteria() {
    return Drawer(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: DrawerHeader(
              padding: const EdgeInsets.all(10),
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.7),
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

          SafeArea(
            top: false,
            child: ListTile(
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
          ),

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
            border: Border.all(color: gris, width: 1.3),
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
            border: Border.all(color: gris, width: 1.3),
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
            color: seleccionado ? Colors.green : Colors.grey.shade300,
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
                  color: seleccionado ? Colors.green : Colors.grey,
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
                    color: Colors.green,
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
            border: Border.all(color: gris, width: 1.3),
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

    if (_solicitandoServicio) return;

    _solicitandoServicio = true;

    /// 1️⃣ VALIDAR NOMBRE
    if (usuarioController.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes escribir el nombre del usuario"),
        ),
      );

      setState(() {
        _solicitandoServicio = false;
      });

      return;
    }

    final usuario = usuarioController.text.trim();
    final apto = aptoController.text.trim();

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    /// 2️⃣ CONFIGURAR ORIGEN PARA GEO FIRE

    _travelController.from = direccion;

    // 🔥 VALIDAR QUE LA PORTERÍA YA CARGÓ
    if (latPorteria == null || lngPorteria == null) {
      print("⛔ ERROR: portería aún no cargada");
      return;
    }

// 🔥 DEBUG
    print("📍 lat: $latPorteria, lng: $lngPorteria");

    _travelController.fromLatlng = LatLng(
      latPorteria!,
      lngPorteria!,
    );

    /// obtener radio de búsqueda
    await _travelController.obtenerRadiodeBusqueda();

    /// 3️⃣ VALIDAR SI HAY CONDUCTORES EN EL RADIO

    bool hayConductores = await _travelController.hayConductoresEnRadio();

    if (!hayConductores) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No hay taxis disponibles cerca en este momento"),
          ),
        );
      }

      setState(() {
        _solicitandoServicio = false;
      });

      return;
    }

    /// 4️⃣ CREAR TRAVEL REQUEST

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

      "notifiedTaxiWaiting": false,
      "notifiedDriverCancel": false,
      "notifiedTimeOver": false
    });

    final requestId = docRef.id;

    _travelController.requestId = requestId;

    /// 5️⃣ CREAR TRAVEL INFO

    await _firestore.collection("TravelInfo").doc(requestId).set({

      "from": direccion,
      "fromLat": latPorteria,
      "fromLng": lngPorteria,

      "usuario": usuario,
      "apto": apto,

      "nombreConjunto": nombreConjunto,
      "nombrePorteria": nombrePorteria,
      "barrio": barrio,

      "metodoPago": _metodoPagoSeleccionado,
      "caracteristica": _caracteristicaSeleccionada,

      "status": "created",
      "tipoSolicitud": "porteria",

      "timestamp": FieldValue.serverTimestamp(),
    });

    /// 6️⃣ INICIAR BUSQUEDA REAL DE CONDUCTORES

    _travelController.getNearbyDriversPorteria();

    /// 7️⃣ LIMPIAR CAMPOS

    usuarioController.clear();
    aptoController.clear();

    setState(() {
      _caracteristicaSeleccionada = "No";
      _metodoPagoSeleccionado = "Efectivo";
    });

    /// 8️⃣ MOSTRAR ALERT

    if (context.mounted) {
      _mostrarServicioSolicitado(context, usuario, apto);
    }

    setState(() {
      _solicitandoServicio = false;
    });
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

        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pushNamed(context, "viajes_porteria");
          }
        });

        return AlertDialog(

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          title: const Text(
            "Servicio solicitado\nPara:",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

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
        );
      },
    );
  }

}
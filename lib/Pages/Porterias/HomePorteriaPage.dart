import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../src/colors/colors.dart';

class HomePorteriaPage extends StatefulWidget {
  const HomePorteriaPage({super.key});

  @override
  State<HomePorteriaPage> createState() => _HomePorteriaPageState();
}

class _HomePorteriaPageState extends State<HomePorteriaPage> {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String nombrePorteria = "";
  String nombreConjunto = "";
  String direccion = "";

  String _metodoPagoSeleccionado = 'Efectivo';
  String _caracteristicaSeleccionada = 'No';

  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController aptoController = TextEditingController();

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
    });
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
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection("Locations")
                      .where("status", isEqualTo: "driver_available")
                      .snapshots(),
                  builder: (context, snapshot) {

                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }

                    final taxisCerca = snapshot.data!.docs.length;

                    final texto = taxisCerca == 0
                        ? "No hay taxis disponibles"
                        : taxisCerca == 1
                        ? "1 taxi disponible cerca"
                        : "$taxisCerca taxis disponibles cerca";

                    final colorBorde =
                    taxisCerca == 0 ? Colors.red.shade300 : Colors.green;

                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: colorBorde,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        texto,
                        style: TextStyle(
                          fontSize: 14.r,
                          fontWeight: FontWeight.w900,
                          color: negro,
                        ),
                        textAlign: TextAlign.center,
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
                    onPressed: () {

                      /// luego conectaremos con solicitud
                    },
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
}
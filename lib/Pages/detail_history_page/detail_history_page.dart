import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../helpers/header_text.dart';
import '../../src/colors/colors.dart';
import 'detail_history_Controller/detail_history_controller.dart';

class DetailHistoryPage extends StatefulWidget {
  const DetailHistoryPage({super.key});

  @override
  State<DetailHistoryPage> createState() => _DetailHistoryPageState();
}

class _DetailHistoryPageState extends State<DetailHistoryPage> {
  final DetailHistoryController _controller = DetailHistoryController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context, refresh);
    });
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    return Scaffold(
      backgroundColor: blancoCards,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Detalle del viaje", style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14
        ),),
        actions: const <Widget>[
          Image(
              height: 40.0,
              width: 100.0,
              image: AssetImage('assets/metax_logo.png'))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildDriverInfo(),
            const SizedBox(height: 15),
            _buildDivider(),
            _buildOrigin(),
            _buildDivider(),
            _buildDestination(),
            _buildDivider(),
            _inicioViaje(),
            _buildDivider(),
            _finalViaje(),
            _buildDivider(),
            _tarifa(),
            _buildDivider(),
            _calificacion(),
            _buildDivider(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfilePhoto(),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conductor', style: TextStyle(fontSize: 12)),
            Row(
              children: [
                _buildName(),
                const SizedBox(width: 3),
                _buildSurname(),
              ],
            ),

            const SizedBox(height: 10),
            _buildTipovehiculo(),
          ],
        )
      ],
    );
  }

  Widget _buildProfilePhoto() {
    if (_controller.driver == null) {
      return const SizedBox(
        width: 80,
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return CircleAvatar(
      backgroundColor: blanco,
      backgroundImage: _controller.driver!.image != null
          ? CachedNetworkImageProvider(_controller.driver!.image)
          : null,
      radius: 40,
    );
  }


  Widget _buildName() {
    return Container(
      alignment: Alignment.topLeft,
      child: headerText(
        text: _controller.driver?.the01Nombres ?? "",
        color: negro,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSurname() {
    return Container(
      alignment: Alignment.topLeft,
      child: headerText(
        text: _controller.driver?.the02Apellidos ?? "",
        color: negro,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTipovehiculo() {
    return Container(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            'Placa',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade400, // gris claro
              borderRadius: BorderRadius.circular(6), // bordes redondeados
            ),
            child: Text(
              _controller.driver?.the18Placa ?? '',
              style: const TextStyle(
                color: negro,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDivider() {
    return const Divider(height: 1, color: grisMedio);
  }

  Widget _buildOrigin() {
    return _buildLocationInfo(
      title: 'Origen:',
      content: _controller.travelHistory?.from ?? '',
    );
  }

  Widget _buildDestination() {
    return _buildLocationInfo(
      title: 'Destino:',
      content: _controller.travelHistory?.to ?? '',
    );
  }

  Widget _buildLocationInfo({required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color:negro,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            content,
            style: const TextStyle(
              color: negroLetras,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _inicioViaje() {
    // Obtiene el Timestamp de inicioViaje
    final Timestamp? inicioViajeTimestamp = _controller.travelHistory?.inicioViaje;

    // Convierte el Timestamp a DateTime
    final DateTime? inicioViajeDateTime = inicioViajeTimestamp?.toDate();

    // Formatea el DateTime a un string legible
    final String formattedInicioViaje = inicioViajeDateTime != null
        ? DateFormat('dd/MM/yyyy hh:mm a').format(inicioViajeDateTime)
        : 'Sin información';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeInfoInicio(
          title: 'Inicio del Viaje',
          content: formattedInicioViaje, // Usa el valor formateado
        ),
      ],
    );
  }

  Widget _buildTimeInfoInicio({required String title, required String content}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.r, vertical: 5.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: negro,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            content,
            style: const TextStyle(
              color: negroLetras,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfoFinal({required String title, required String content}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.r, vertical: 5.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: negro,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            content,
            style: const TextStyle(
              color: negroLetras,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalViaje() {
    // Obtiene el Timestamp de finalViaje
    final Timestamp? finalViajeTimestamp = _controller.travelHistory?.finalViaje;

    // Convierte el Timestamp a DateTime
    final DateTime? finalViajeDateTime = finalViajeTimestamp?.toDate();

    // Formatea el DateTime a un string legible
    final String formattedFinalViaje = finalViajeDateTime != null
        ? DateFormat('dd/MM/yyyy hh:mm a').format(finalViajeDateTime)
        : 'Sin información';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeInfoFinal(
          title: 'Finalización del Viaje',
          content: formattedFinalViaje, // Usa el valor formateado
        ),
      ],
    );
  }



  Widget _tarifa() {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '', // sin símbolo
      decimalDigits: 0,
      name: '',
      customPattern: '#,##0',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tarifa',
                style: TextStyle(
                  color: negro,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$ ${formatter.format(_controller.travelHistory?.tarifa ?? 0)}',
                style: const TextStyle(
                  color: negroLetras,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _calificacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 15.r, vertical: 10.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Le diste una calificación de:',
                    style: TextStyle(
                      color: negro,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              headerText(
                text: _controller.travelHistory?.calificacionAlConductor.toString() ?? '',
                color: negroLetras,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void refresh() {
    setState(() {});
  }
}

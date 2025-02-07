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
            fontWeight: FontWeight.w900,
            fontSize: 20
        ),),
        actions: const <Widget>[
          Image(
              height: 40.0,
              width: 100.0,
              image: AssetImage('assets/metax_logo.png'))
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildDriverInfo(),
            SizedBox(height: 15.r),
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
        SizedBox(width: 25.r),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conductor', style: TextStyle(fontSize: 14)),
            _buildName(),
            _buildSurname(),
            const SizedBox(height: 10),
            _buildTipovehiculo(),
          ],
        )
      ],
    );
  }

  Widget _buildProfilePhoto() {
    if (_controller.driver != null) {
      return Container(
        alignment: Alignment.center,
        margin: EdgeInsets.only(bottom: 15.r),
        child: CircleAvatar(
          backgroundColor: blanco,
          backgroundImage: _controller.driver!.image != null
              ? CachedNetworkImageProvider(_controller.driver!.image)
              : null,
          radius: 50,
        ),
      );
    } else {
      return const CircularProgressIndicator();
    }
  }

  Widget _buildName() {
    return Container(
      alignment: Alignment.topLeft,
      child: headerText(
        text: _controller.driver?.the01Nombres ?? "",
        color: negro,
        fontSize: 18.r,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildSurname() {
    return Container(
      alignment: Alignment.topLeft,
      child: headerText(
        text: _controller.driver?.the02Apellidos ?? "",
        color: negro,
        fontSize: 14.r,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildTipovehiculo() {
    return Container(
      alignment: Alignment.topLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText(text: "Taxi de placa",color: negro,fontSize: 14,fontWeight: FontWeight.w700),
              headerText(
                text: _controller.driver?.the18Placa ?? '',
                color: negro,
                fontSize: 18.r,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
          SizedBox(width: 30.r),
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
      padding: EdgeInsets.symmetric(horizontal: 15.r, vertical: 5.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color:primary,
                  fontSize: 14.r,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            content,
            style: TextStyle(
              color: negro,
              fontSize: 18.r,
              fontWeight: FontWeight.w600,
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
                style: TextStyle(
                  color: primary,
                  fontSize: 14.r,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            content,
            style: TextStyle(
              color: negro,
              fontSize: 14.r,
              fontWeight: FontWeight.w600,
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
                style: TextStyle(
                  color: primary,
                  fontSize: 14.r,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            content,
            style: TextStyle(
              color: negro,
              fontSize: 14.r,
              fontWeight: FontWeight.w600,
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
      symbol: '',
      decimalDigits: 0,
      name: '',
      customPattern: '\u00A4#,##0',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 15.r, vertical: 5.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                children: [
                  Text(
                    'Tarifa',
                    style: TextStyle(
                      color: primary,
                      fontSize: 14.r,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                formatter.format(_controller.travelHistory?.tarifa ?? 0),
                style: TextStyle(
                  color: negro,
                  fontSize: 14.r,
                  fontWeight: FontWeight.w600,
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
              Row(
                children: [
                  Text(
                    'Calificación',
                    style: TextStyle(
                      color: primary,
                      fontSize: 14.r,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              headerText(
                text: _controller.travelHistory?.calificacionAlConductor.toString() ?? '',
                color: negro,
                fontSize: 14.r,
                fontWeight: FontWeight.w600,
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

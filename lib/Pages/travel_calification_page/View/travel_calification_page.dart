import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../helpers/conectivity_service.dart';
import '../../../src/colors/colors.dart';
import '../travel_calification_controller/travel_calification_controller.dart';

class TravelCalificationPage extends StatefulWidget {
  const TravelCalificationPage({super.key});

  @override
  State<TravelCalificationPage> createState() => _TravelCalificationPageState();
}

class _TravelCalificationPageState extends State<TravelCalificationPage> {

  late TravelCalificationController _controller;
  String? tarifaFormatted;
  final ConnectionService connectionService = ConnectionService();
  bool isLoading = false;


  @override
  void initState() {
    super.initState();
    _controller = TravelCalificationController();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context, refresh);
    });
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: blancoCards,
        key: _controller.key,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Asegura que la columna se extienda horizontalmente
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _tituloNotificacion(),
                    SizedBox(height: 30.r),
                    _infoOrigenDestino(),
                    SizedBox(height: 30.r),
                    _tarifa(),
                    SizedBox(height: 30.r),
                    _subtituloCuantasEstrellas(),
                    SizedBox(height: 10.r),
                    _ratingBar (),
                    if ((_controller.calification ?? 0) >
                        0)

                      _feedbackDinamico(),

                  ],
                ),
              ),
              _botones(), // Mueve los botones fuera del Expanded
            ],
          ),
        ),
      ),
    );
  }

  Widget _subtituloCuantasEstrellas() {

    final rating =
        _controller.calification ?? 0;

    final positiva =
        rating >= 4;

    final negativa =
        rating > 0 && rating < 4;

    return Column(

      children: [

        if (rating > 0) ...[

          AnimatedContainer(

            duration:
            const Duration(
              milliseconds: 250,
            ),

            padding:
            const EdgeInsets.all(18),

            decoration: BoxDecoration(

              shape: BoxShape.circle,

              color:

              positiva

                  ? Colors.green
                  .withOpacity(0.15)

                  : Colors.red
                  .withOpacity(0.15),
            ),

            child: Icon(

              positiva

                  ? Icons.sentiment_very_satisfied

                  : Icons.sentiment_very_dissatisfied,

              color:

              positiva

                  ? Colors.green

                  : Colors.red,

              size: 55,
            ),
          ),

          const SizedBox(height: 14),
        ],

        Text(

          negativa

              ? '¿Qué debe mejorar el conductor?'

              : '¿Cuántas estrellas le das al conductor?',

          style: TextStyle(

            color:

            negativa
                ? Colors.red

                : Colors.black,

            fontSize: 16,

            fontWeight:
            FontWeight.w900,
          ),

          textAlign:
          TextAlign.center,
        ),

        if (positiva) ...[

          const SizedBox(height: 8),

          const Text(

            '¡Gracias por confiar en MetaX!',

            style: TextStyle(

              fontSize: 13,

              fontWeight:
              FontWeight.w600,

              color: Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tituloNotificacion(){
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 25, right: 25, top: 15, bottom: 15),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(70),
              bottomLeft: Radius.circular(70)),
          color: primary.withOpacity(0.7),
          boxShadow: const [BoxShadow(
            color: gris,
            offset: Offset(5,5),
            blurRadius: 5,
          )]),
      child: const Text('Servicio Finalizado', style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
        height: 1.2
          ),
      textAlign: TextAlign.center),
    );
  }

  Widget _infoOrigenDestino(){
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100.r,
          padding: EdgeInsets.only(left: 10.r, top: 2.r, bottom: 2.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(70.r),
                topRight: Radius.circular(70.r)),
            color: blanco,
          ),
          child: Row(
            children: [
              Image.asset('assets/ubicacion_client.png', height: 12, width: 12),
              const SizedBox(width: 10),
              const Text('Origen', style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: negro)),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 35, right: 15, top: 5),
          child: Text(_controller.travelHistory?.from ?? '', style: const TextStyle(
              fontWeight: FontWeight.w900,fontSize: 16, color: negro), maxLines: 2),
        ),
        const SizedBox(height: 10),
        const Divider(color: grisMedio,height: 1,indent: 2, endIndent: 2),
        const SizedBox(height: 15),
        Container(
          width: 100,
          padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(70),
                topRight: Radius.circular(70)),
            color: blanco,
          ),
          child: Row(
            children: [
              Image.asset('assets/marker_destino.png', height: 11, width: 11),
              const SizedBox(width: 10),
              const Text('Destino', style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: negro)),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 35, right: 15, top: 5),
          child: Text(_controller.travelHistory?.to ?? '', style: const TextStyle(
              fontWeight: FontWeight.w900,fontSize: 16, color: negro), maxLines: 2),
        ),
        const SizedBox(height: 15),
        const Divider(color: grisMedio,height: 1,indent: 2, endIndent: 2)
      ],
    );
  }

  void formateartarifa() {
    String tarifa = _controller.travelHistory?.tarifa.toString() ?? '';
    double tarifaDouble = double.tryParse(tarifa) ?? 0.0;
    NumberFormat formatter = NumberFormat('#,###', 'es_ES');
    tarifaFormatted = '\$ ${formatter.format(tarifaDouble)}';
  }

  @override
  void dispose() {
    connectionService.dispose();
    super.dispose();
  }

  Widget _feedbackDinamico() {

    final esPositiva =

        (_controller.calification ?? 0)
            >= 4;

    final opciones = esPositiva

        ? _controller.opcionesPositivas

        : _controller.opcionesNegativas;

    final seleccionadas = esPositiva

        ? _controller.aspectosPositivos

        : _controller.aspectosNegativos;

    return Container(

      margin: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 25,
      ),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(20),

        boxShadow: [

          BoxShadow(

            color:
            Colors.black.withOpacity(0.05),

            blurRadius: 10,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Text(

            esPositiva

                ? '¿Qué fue lo que más te gustó?'

                : '¿Qué ocurrió durante el servicio?',

            style: const TextStyle(

              fontSize: 16,

              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(height: 15),

          Wrap(

            spacing: 10,

            runSpacing: 10,

            children:

            opciones.map((opcion) {

              final selected =

              seleccionadas.contains(
                opcion,
              );

              return GestureDetector(

                onTap: () {

                  setState(() {

                    if (selected) {

                      seleccionadas.remove(
                        opcion,
                      );

                    } else {

                      seleccionadas.add(
                        opcion,
                      );
                    }
                  });
                },

                child: AnimatedContainer(

                  duration:
                  const Duration(
                    milliseconds: 180,
                  ),

                  padding:
                  const EdgeInsets.symmetric(

                    horizontal: 14,
                    vertical: 10,
                  ),

                  decoration: BoxDecoration(

                    color:

                    selected

                        ? primary.withOpacity(
                      0.18,
                    )

                        : Colors.grey.shade100,

                    borderRadius:
                    BorderRadius.circular(30),

                    border: Border.all(

                      color:

                      selected

                          ? primary

                          : Colors.grey.shade300,
                    ),
                  ),

                  child: Text(

                    opcion,

                    style: TextStyle(

                      fontWeight:
                      FontWeight.w700,

                      color:

                      selected

                          ? Colors.black

                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          TextField(

            controller:
            _controller
                .comentarioController,

            maxLines: 4,

            decoration: InputDecoration(

              hintText:

              esPositiva

                  ? '¿Qué fue lo mejor del servicio?'

                  : '¿En qué debe mejorar el conductor?',

              filled: true,

              fillColor:
              Colors.grey.shade100,

              border: OutlineInputBorder(

                borderRadius:
                BorderRadius.circular(16),

                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar () {
    return Center(
        child: RatingBar.builder(

          itemBuilder: (context, _) => Icon(

            Icons.star,

            color: Colors.orange.shade300,
          ),

          itemCount: 5,

          initialRating:
          (_controller.calification ?? 0)
              .toDouble(),

          direction: Axis.horizontal,

          itemSize: 35,

          itemPadding:
          const EdgeInsets.symmetric(
            horizontal: 4,
          ),

          allowHalfRating: true,

          unratedColor: grisMedio,

          onRatingUpdate: (ratingBar) {

            setState(() {

              _controller.calification =
                  ratingBar;

              if (ratingBar >= 4) {

                _controller
                    .aspectosNegativos
                    .clear();

              } else {

                _controller
                    .aspectosPositivos
                    .clear();
              }
            });
          },
        )
    );
  }

  Widget _tarifa() {

    final tarifa =

        _controller.travelHistory
            ?.tarifa

            ??

            0;

    final descuento =
        _controller.travelHistory
            ?.tarifaDescuento ?? 0;

    final totalCliente =
        _controller.travelHistory
            ?.totalClientePaga
            ?? tarifa;

    final tienePromo = descuento > 0;

    final esGratis =
        totalCliente <= 0;

    return Container(

      margin: const EdgeInsets.symmetric(
        horizontal: 20,
      ),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(20),

        boxShadow: [

          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(

        children: [

          if (tienePromo) ...[

            _itemCobro(
              'Valor del viaje',
              tarifa,
            ),

            Padding(

              padding:
              const EdgeInsets.symmetric(
                vertical: 10,
              ),

              child: _itemCobro(

                'Bono MetaX',

                -descuento,

                color: Colors.green,
              ),
            ),

            const Divider(),

            _itemCobro(

              esGratis
                  ? 'Viaje gratis'
                  : 'Debes pagar',

              totalCliente,

              isTotal: true,
            ),

          ] else ...[

            _itemCobro(

              'Debes pagar',

              tarifa,

              isTotal: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemCobro(

      String titulo,

      double valor, {

        Color color = Colors.black,

        bool isTotal = false,
      }) {

    final formatter = NumberFormat(
      '#,###',
      'es_CO',
    );

    return Row(

      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,

      children: [

        Text(

          titulo,

          style: TextStyle(

            fontSize:
            isTotal ? 16 : 14,

            fontWeight:
            isTotal
                ? FontWeight.w900
                : FontWeight.w600,

            color: Colors.black87,
          ),
        ),

        Text(

          valor <= 0 && isTotal
              ? 'GRATIS'
              : '\$ ${formatter.format(valor)}',

          style: TextStyle(

            fontSize:
            isTotal ? 24 : 16,

            fontWeight: FontWeight.w900,

            color: color,
          ),
        ),
      ],
    );
  }

  Widget _botones() {
    return Container(
      margin: const EdgeInsets.only(bottom: 50),
      alignment: Alignment.center,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            flex: 2, // Proporción del primer botón
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary.withOpacity(0.7),
                shadowColor: gris,
                elevation: 6,
              ),

              onPressed: isLoading
                  ? null
                  : () async {
                await connectionService.checkConnectionAndShowCard(context, () async {
                  if (!mounted) return;

                  setState(() => isLoading = true);

                  try {
                    await _controller.calificate();
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                });
              },
              child: isLoading
                  ? const CircularProgressIndicator(
                color: blanco, // Color del indicador
              )
                  : Text(
                'CALIFICAR CONDUCTOR',
                style: TextStyle(color: Colors.black, fontSize: 18.r, fontWeight: FontWeight.w900),
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
        formateartarifa();
      });
    }
  }
}

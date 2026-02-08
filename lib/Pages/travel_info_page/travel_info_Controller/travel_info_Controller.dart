
import 'dart:async';
import 'dart:math';
import 'package:apptaxis/helpers/conectivity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/geofire_provider.dart';
import '../../../../providers/push_notifications_provider.dart';
import '../../../models/driver.dart';
import '../../../models/price.dart';
import '../../../models/travel_info.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/price_provider.dart';
import '../../../providers/travel_info_provider.dart';
import 'package:apptaxis/models/client.dart';
import 'package:apptaxis/utils/utilsMap.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../travel_map_page/View/travel_map_page.dart';

import 'package:cloud_functions/cloud_functions.dart';


class TravelInfoController{
  late BuildContext context;
  late PricesProvider _pricesProvider;
  late TravelInfoProvider _travelInfoProvider;
  late MyAuthProvider _authProvider;
  late DriverProvider _driverProvider;
  late GeofireProvider _geofireProvider;
  late PushNotificationsProvider _pushNotificationsProvider;
  late ClientProvider _clientProvider;
  Client? client;
  String? apuntesAlConductor;
  late Function refresh;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  late Completer<GoogleMapController> _mapController = Completer();
  CameraPosition initialPosition = const CameraPosition(
    target: LatLng(4.1461765, -73.641138),
    zoom: 12.0,
  );
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  late String from = "";
  late String to = "";
  late LatLng fromLatlng;
  late LatLng toLatlng;
  LatLngBounds? bounds;
  Set<Polyline> polylines = {};
  List<LatLng> points = List.from([]);
  late BitmapDescriptor fromMarker;
  late BitmapDescriptor toMarker;
  String? min;
  String? km;
  double? total;
  int? totalInt;
  double? radioDeBusqueda;
  int distancia = 0;
  String distanciaString = '';
  int duracion = 0;
  String duracionString = '';
  double tiempoEnMinutos = 0;
  List<String> nearbyDrivers = [];
  List<String> nearbyMotorcyclers = [];
  StreamSubscription<List<DocumentSnapshot>>? _streamSubscription;
  StreamSubscription<DocumentSnapshot<Object?>>? _clientInfoSuscription;
  StreamSubscription<DocumentSnapshot<Object?>>? _streamStatusSuscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isSendingNotification = false; // Indicador para controlar el envío de notificaciones
  Set<String> notifiedDrivers = <String>{};
  Position? _position;
  bool serviceAccepted = false; // Bandera global para detener notificaciones
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Cambio a Api desde el backend
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  //para internet
  final ConnectionService connectionService = ConnectionService();



  // ✅ listo solo si ya hay ruta y tarifa
  bool get canConfirmTrip {
    final hasRoute = (points.length > 1) || polylines.isNotEmpty;
    final hasFare = (total != null) && (total! > 0);
    return hasRoute && hasFare;
  }

  bool get isCalculatingTrip => !canConfirmTrip;




  Future<void> init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _pricesProvider = PricesProvider();
    _travelInfoProvider = TravelInfoProvider();
    _driverProvider = DriverProvider();
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
    _geofireProvider = GeofireProvider();
    _pushNotificationsProvider = PushNotificationsProvider();

    // Reinicia el Completer del controlador de mapa cada vez que se llama init
    _mapController = Completer();

    Map<String, dynamic>? arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    await getClientInfo();

    // if (arguments != null) {
    //   updateMap();
    //   from = arguments['from'] ?? "Desconocido";
    //   to = arguments['to'] ?? "Desconocido";
    //   fromLatlng = arguments['fromlatlng'];
    //   toLatlng = arguments['tolatlng'];
    //   animateCameraToPosition(fromLatlng.latitude, fromLatlng.longitude);
    //   getGoogleMapsDirections(fromLatlng, toLatlng);
    // } else {
    //   if (kDebugMode) {
    //     print('Error: Los argumentos son nulos');
    //   }
    // } 8 febe 2026

    if (arguments != null) {
      from = arguments['from'] ?? "Desconocido";
      to = arguments['to'] ?? "Desconocido";
      fromLatlng = arguments['fromlatlng'];
      toLatlng = arguments['tolatlng'];

      // ✅ Todo lo que requiere internet va aquí
      await connectionService.checkConnectionAndShowCard(context, () {
        // No pongas await aquí porque el callback es VoidCallback
        Future.microtask(() async {
          updateMap();
          animateCameraToPosition(fromLatlng.latitude, fromLatlng.longitude);
          await getGoogleMapsDirections(fromLatlng, toLatlng);
        });
      });
    } else {
      if (kDebugMode) {
        print('Error: Los argumentos son nulos');
      }
    }
  }


  void dispose() {
    _streamSubscription?.cancel();
    _clientInfoSuscription?.cancel();
    _streamStatusSuscription?.cancel();
    clearApuntesAlConductor();
    _audioPlayer.dispose();
    km = null;
    min = null;
    total = 0.0;
  }

  Future<void> updateMap() async {
    clearMap();
    // Crea o actualiza los marcadores
    fromMarker = await createMarkerImageFromAssets('assets/ubicacion_client.png');
    toMarker = await createMarkerImageFromAssets('assets/marker_destino.png');
    addMarker('from', fromLatlng.latitude, fromLatlng.longitude, 'Origen', '', fromMarker);
    addMarker('to', toLatlng.latitude, toLatlng.longitude, 'Destino', '', toMarker);
    // Crear los límites para incluir ambos marcadores
    LatLngBounds bounds = LatLngBounds(
      northeast: LatLng(
        fromLatlng.latitude > toLatlng.latitude ? fromLatlng.latitude : toLatlng.latitude,
        fromLatlng.longitude > toLatlng.longitude ? fromLatlng.longitude : toLatlng.longitude,
      ),
      southwest: LatLng(
        fromLatlng.latitude < toLatlng.latitude ? fromLatlng.latitude : toLatlng.latitude,
        fromLatlng.longitude < toLatlng.longitude ? fromLatlng.longitude : toLatlng.longitude,
      ),
    );
    // Ajustar los límites con un margen extra
    bounds = _extendBounds(bounds, fromLatlng);
    bounds = _extendBounds(bounds, toLatlng);
    // Ajustar la cámara del mapa a los límites calculados
    if(context.mounted){
      await fitBounds(bounds, context);
    }

  }
  void clearMap() {
    polylines.clear(); // Limpia todas las polilíneas actuales
    markers.clear();   // Limpia todos los marcadores actuales
  }

  void addMarker(String markerId, double lat, double lng, String title, String content, BitmapDescriptor iconMarker) {
    MarkerId id = MarkerId(markerId);
    Marker marker = Marker(
      markerId: id,
      icon: iconMarker,
      position: LatLng(lat, lng),
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(title: title, snippet: content),
    );
    // Añade el marcador al mapa
    markers[id] = marker;
  }


  LatLngBounds _extendBounds(LatLngBounds? bounds, LatLng newPoint) {
    if (bounds == null) {
      return LatLngBounds(northeast: newPoint, southwest: newPoint);
    }
    double minLat = bounds.southwest.latitude < newPoint.latitude ? bounds.southwest.latitude : newPoint.latitude;
    double minLng = bounds.southwest.longitude < newPoint.longitude ? bounds.southwest.longitude : newPoint.longitude;
    double maxLat = bounds.northeast.latitude > newPoint.latitude ? bounds.northeast.latitude : newPoint.latitude;
    double maxLng = bounds.northeast.longitude > newPoint.longitude ? bounds.northeast.longitude : newPoint.longitude;
    const double margin = 0.002; // Ajustar el margen según sea necesario
    return LatLngBounds(
      southwest: LatLng(minLat - margin, minLng - margin),
      northeast: LatLng(maxLat + margin, maxLng + margin),
    );
  }


  // Método para calcular la distancia entre dos LatLng
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371e3; // En metros
    double lat1 = point1.latitude * (3.14159265359 / 180);
    double lat2 = point2.latitude * (3.14159265359 / 180);
    double deltaLat = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    double deltaLng = (point2.longitude - point1.longitude) * (3.14159265359 / 180);
    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) *
            sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // Distancia en metros
  }

  Future<void> fitBounds(LatLngBounds bounds, BuildContext context) async {
    GoogleMapController controller = await _mapController.future;
    if(context.mounted){
      double padding = MediaQuery.of(context).size.height * 0.1; // 10% del alto de la pantalla
      // Calcular el tamaño de la distancia entre los marcadores
      double distance = _calculateDistance(fromLatlng, toLatlng);
      // Si la distancia es muy pequeña, ajustar el zoom
      if (distance < 0.001) { // Puedes ajustar este valor según sea necesario
        await controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(
            (fromLatlng.latitude + toLatlng.latitude) / 2,
            (fromLatlng.longitude + toLatlng.longitude) / 2,
          ),
          15.0, // Ajusta el nivel de zoom deseado
        ));
      } else {
        await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
      }
    }
  }

  void guardarTipoServicio(String tipoServicio) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('tipoServicio', tipoServicio);
  }


  void guardarApuntesConductor(String apuntes) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apuntes_al_conductor', apuntes);
    apuntesAlConductor = apuntes;
  }

  void clearApuntesAlConductor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apuntes_al_conductor', "");
    // Actualizar la variable en la memoria
    apuntesAlConductor = "";
  }

  Future<void> deleteTravelInfo() async {
    try {
      // Obtener el ID del cliente actual
      String currentUserId = _authProvider.getUser()!.uid;

      // Obtener el documento del viaje usando el ID del cliente
      DocumentSnapshot travelInfoSnapshot = await _firestore.collection('TravelInfo').doc(currentUserId).get();

      // Verificar si el documento existe
      if (travelInfoSnapshot.exists) {
        // Hacer un casting del resultado a Map<String, dynamic>
        Map<String, dynamic> travelInfoData = travelInfoSnapshot.data() as Map<String, dynamic>;

        // Obtener el estado del viaje
        String status = travelInfoData['status'] ?? '';

        // Verificar si el estado es 'created'
        if (status == 'created') {
          // Borrar el documento
          await _firestore.collection('TravelInfo').doc(currentUserId).delete();
        }
      } else {
        if (kDebugMode) {
          print('El documento no existe.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al borrar el documento: $e');
      }
    }
  }


  Future<void> getClientInfo() async {
    final user = _authProvider.getUser();
    if (user != null) {
      final userId = user.uid;
      Stream<DocumentSnapshot> clientStream = _clientProvider.getByIdStream(userId);
      _clientInfoSuscription = clientStream.listen((DocumentSnapshot document) {
        if (document.exists) {
          client = Client.fromJson(document.data() as Map<String, dynamic>);
          refresh();
        } else {
          if (kDebugMode) {
            print('Error: El documento del cliente no existe.');
          }
        }
      }, onError: (error) {
        if (kDebugMode) {
          print('Error al escuchar los cambios en la información del cliente: $error');
        }
      });
    } else {
      if (kDebugMode) {
        print('Error: Usuario no autenticado.');
      }
    }
  }

  void onMapCreated(GoogleMapController controller) async {
    controller.setMapStyle(utilsMap.mapStyle);
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
   // await setPolylines(); // Asegúrate de que esto no dependa de _mapController ya completado a menos que necesario
  }


  Future<void> getGoogleMapsDirections(LatLng from, LatLng to) async {
    final ok = await connectionService.hasInternetConnection();
    if (!ok) return;
    try {
      final res = await _functions.httpsCallable('getDirections').call({
        'fromLat': from.latitude,
        'fromLng': from.longitude,
        'toLat': to.latitude,
        'toLng': to.longitude,
        'mode': 'driving',
      });

      final data = Map<String, dynamic>.from(res.data);

      if (data['ok'] != true) {
        if (kDebugMode) print('getDirections failed: $data');
        return;
      }

      final String polylineEncoded = (data['polyline'] ?? '').toString();
      final int distanceMeters = (data['distanceMeters'] ?? 0) as int;
      final int durationSeconds = (data['durationSeconds'] ?? 0) as int;

      // ✅ Actualiza variables que ya usas
      distancia = distanceMeters;
      duracion = durationSeconds;
      tiempoEnMinutos = durationSeconds / 60.0;

      // Formatos tipo “X km” y “Y min”
      final double kmValue = distanceMeters / 1000.0;
      km = '${kmValue.toStringAsFixed(1)} km';

      final int minsValue = (durationSeconds / 60).round();
      min = '$minsValue min';

      distanciaString = km ?? '';
      duracionString = min ?? '';

      // ✅ Calcula tarifa y radio (igual que hoy)
      calcularPrecio();
      obtenerRadiodeBusqueda();

      // ✅ Dibuja polyline usando el encoded
      await setPolylinesFromEncoded(polylineEncoded);

    } catch (e) {
      if (kDebugMode) print('getGoogleMapsDirections (via function) error: $e');
    }
  }

  Future<void> setPolylinesFromEncoded(String encodedPolyline) async {
    clearMap();

    // Decodifica la polyline
    final decoded = PolylinePoints().decodePolyline(encodedPolyline);

    points = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

    polylines.clear();
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.black,
        points: points,
        width: 5,
      ),
    );

    // Marcadores
    addMarker('from', fromLatlng.latitude, fromLatlng.longitude, 'Origen', '', fromMarker);
    addMarker('to', toLatlng.latitude, toLatlng.longitude, 'Destino', '', toMarker);

    refresh();
  }

  void calcularPrecio() async {
    try {
      final Price price = await _pricesProvider.getAll();

      // ✅ Rol del usuario (por defecto regular)
      final rol = (client?.the20Rol ?? 'regular').toLowerCase().trim();

      // ✅ Valores según rol
      final double valorKm = (rol == 'hotel')
          ? price.theValorKmHotel
          : (rol == 'turismo')
          ? price.theValorKmTurismo
          : price.theValorKmRegular;

      final double valorMin = (rol == 'hotel')
          ? price.theValorMinHotel
          : (rol == 'turismo')
          ? price.theValorMinTurismo
          : price.theValorMinRegular;

      final double tarifaMinima = (rol == 'hotel')
          ? price.theTarifaMinimaHotel.toDouble()
          : (rol == 'turismo')
          ? price.theTarifaMinimaTurismo.toDouble()
          : price.theTarifaMinimaRegular.toDouble();

      // ✅ Declara estas variables (antes no estaban y por eso fallaba)
      double valorKilometro = 0.0;
      double valorMinuto = 0.0;

      // --------- KM ---------
      if (km != null) {
        final double distanciaKm =
        double.parse(km!.split(" ")[0].replaceAll(',', ''));

        // 👇 aquí usas el valorKm del rol (NO el regular)
        valorKilometro = distanciaKm * valorKm;

        // Incrementos según distancia (se aplican igual)
        if (distanciaKm > 100) {
          valorKilometro *= 2.00;
        } else if (distanciaKm > 80) {
          valorKilometro *= 1.80;
        } else if (distanciaKm > 50) {
          valorKilometro *= 1.50;
        } else if (distanciaKm > 40) {
          valorKilometro *= 1.40;
        } else if (distanciaKm > 30) {
          valorKilometro *= 1.30;
        } else if (distanciaKm > 20) {
          valorKilometro *= 1.20;
        }
      }

      // --------- MIN ---------
      if (min != null) {
        final double minutos =
        double.parse(min!.split(" ")[0].replaceAll(',', ''));

        // 👇 aquí usas el valorMin del rol (NO el regular)
        valorMinuto = minutos * valorMin;
      }

      // ✅ Total con dinámica
      total = (valorMinuto + valorKilometro) * price.theDinamica;

      // ✅ Redondeo
      total = redondearACentena(total);

      // ✅ Mínima según rol (NO redeclarar)
      total = total?.clamp(tarifaMinima, double.infinity);

      totalInt = total?.toInt();
      refresh();
    } catch (e) {
      if (kDebugMode) {
        print('Error al calcular el precio: $e');
      }
    }
  }


  // new para ajustar roles y tarifas del rol del usuario

  String _rolUsuario() {
    return (client?.the20Rol ?? 'regular').toLowerCase();
  }

  double _valorKmPorRol(Price price) {
    switch (_rolUsuario()) {
      case 'hotel':
        return price.theValorKmHotel;
      case 'turismo':
        return price.theValorKmTurismo;
      default:
        return price.theValorKmRegular;
    }
  }

  double _valorMinPorRol(Price price) {
    switch (_rolUsuario()) {
      case 'hotel':
        return price.theValorMinHotel;
      case 'turismo':
        return price.theValorMinTurismo;
      default:
        return price.theValorMinRegular;
    }
  }

  double _tarifaMinimaPorRol(Price price) {
    switch (_rolUsuario()) {
      case 'hotel':
        return price.theTarifaMinimaHotel.toDouble();
      case 'turismo':
        return price.theTarifaMinimaTurismo.toDouble();
      default:
        return price.theTarifaMinimaRegular.toDouble();
    }
  }

  void obtenerRadiodeBusqueda() async {
    try {
      Price price = await _pricesProvider.getAll();
      radioDeBusqueda = price.theRadioDeBusqueda;
      if (kDebugMode) {
        print("Radio de busqueda: $radioDeBusqueda");
      }
      refresh();
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener el radio de busqueda: $e');
      }
    }
  }

  double? redondearACentena(double? valor) {
    if (valor == null) return null;
    return (valor / 100).ceil() * 100.toDouble();
  }

  Future<void> animateCameraToPosition(double latitude, double longitude) async {
    GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        bearing: 0,
        target: LatLng(latitude, longitude),
        zoom: 15,
      ),
    ));
  }

  Future<BitmapDescriptor> createMarkerImageFromAssets(String path) async {
    try {
      ImageConfiguration configuration = const ImageConfiguration();
      BitmapDescriptor bitmapDescriptor = await BitmapDescriptor.fromAssetImage(configuration, path);
      return bitmapDescriptor;
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar la imagen del marcador: $e');
      }
      return BitmapDescriptor.defaultMarker;
    }
  }

  String formatDuration(String durationText) {
    List<String> parts = durationText.split(' ');
    List<String> formattedParts = parts.map((part) {
      switch (part) {
        case 'hours':
          return 'h';
        case 'hour':
          return 'hs';
        case 'mins':
          return 'mins';
        case 'min':
          return 'min';
        default:
          return part;
      }
    }).toList();
    return formattedParts.join(' ');
  }

  String? extractCity(String? fullAddress) {
    if (fullAddress != null) {
      List<String> addressParts = fullAddress.split(',');
      if (addressParts.isNotEmpty) {
        return addressParts[1].trim();
      }
    }
    return null;
  }

  ///marca para saber si se hizo el rebase

  void getNearbyDrivers() {
    serviceAccepted = false; // Restablecer la bandera al inicio del proceso
    Stream<List<DocumentSnapshot>> stream = _geofireProvider.getNearbyDrivers(
      fromLatlng.latitude,
      fromLatlng.longitude,
      radioDeBusqueda ?? 1,
    );

    _streamSubscription = stream.listen((List<DocumentSnapshot> documentList) {
      _streamSubscription?.cancel();  // Cancela la suscripción después de recibir los datos
      if (documentList.isNotEmpty) {
        nearbyDrivers = documentList.map((d) => d.id).toList(); // Aquí defines 'nearbyDrivers'
        if (kDebugMode) {
          print('Se encontraron ${nearbyDrivers.length} conductores cercanos.');
        }
        _attemptToSendNotification(nearbyDrivers, 0); // Cambiado de 'driverIds' a 'nearbyDrivers'
      } else {
        if (kDebugMode) {
          print('No se encontraron conductores cercanos.');
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print('Error al escuchar el stream de conductores cercanos: $error');
      }
    });
  }

  void _attemptToSendNotification(List<String> driverIds, int index) {
    if (index >= driverIds.length || serviceAccepted) {
      if (kDebugMode) {
        print('No hay más conductores disponibles o el servicio fue aceptado.');
      }
      notifiedDrivers.clear(); // Limpiamos el conjunto para futuras búsquedas.
      return;
    }

    String driverId = driverIds[index];
    if (notifiedDrivers.contains(driverId)) {
      _attemptToSendNotification(driverIds, index + 1);
      return;
    }

    notifiedDrivers.add(driverId); // Añadimos el conductor al conjunto de notificados.
    if (kDebugMode) {
      print("Enviando notificación al conductor $driverId");
    }

    getDriverInfo(driverId).then((_) async {
      Driver? driver = await _driverProvider.getById(driverId);
      if (driver != null) {
        if (kDebugMode) {
          print('ID del conductor: ${driver.id}');
          print('Token del conductor: ${driver.token}');
        }
      } else {
        if (kDebugMode) {
          print('El conductor no fue encontrado.');
        }
      }

      if (driver?.token != null) {
        bool accepted = await sendNotification(driver!.token);
        if (accepted) {
          if (kDebugMode) {
            print('El conductor $driverId aceptó el servicio.');
          }
          serviceAccepted = true; // Detener el envío de notificaciones
        } else {
          if (kDebugMode) {
            print('El conductor $driverId no aceptó el servicio, pasando al siguiente...');
          }
        }
      } else {
        if (kDebugMode) {
          print('No se pudo obtener el token del conductor $driverId, pasando al siguiente...');
        }
      }

      _attemptToSendNotification(driverIds, index + 1);
    }).catchError((error) {
      if (kDebugMode) {
        print('Error al obtener información del conductor $driverId: $error');
      }
      _attemptToSendNotification(driverIds, index + 1);
    });
  }

  void playAudio(String audioPath) async {
    print('****************************Reproduciendo audio con objeto _audioPlayer: $_audioPlayer');
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.stop(); // Detener cualquier reproducción anterior.
      }
      await _audioPlayer.setAsset('asset:$audioPath'); // Establecer el audio a reproducir.
      await _audioPlayer.play(); // Reproducir el audio.
    } catch (e) {
      if (kDebugMode) {
        print('Error al reproducir el audio: $e');
      }
    }
  }

  void _soundServicioAceptado() {
    playAudio('assets/audio/servicio_aceptado_new.wav');
  }

  void _checkDriverResponse() {
    Stream<DocumentSnapshot> stream = _travelInfoProvider.getByIdStream(_authProvider.getUser()!.uid);
    _streamStatusSuscription = stream.listen((DocumentSnapshot document) {
      if (document.exists && document.data() != null) {
        Map<String, dynamic> data = document.data() as Map<String, dynamic>;
        TravelInfo travelInfo = TravelInfo.fromJson(data);

        if (travelInfo.status == 'accepted') {
          serviceAccepted = true; // Detener el envío de notificaciones
          _soundServicioAceptado();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const TravelMapPage()),
                (route) => false,
          );
        }
      }
    });
  }


  void createTravelInfo() async {
    TravelInfo travelInfo = TravelInfo(
        id: _authProvider.getUser()!.uid,
        status: 'created',
        idDriver: "",
        from: from,
        to: to,
        idTravelHistory: "",
        fromLat: fromLatlng.latitude,
        fromLng: fromLatlng.longitude,
        toLat: toLatlng.latitude,
        toLng: toLatlng.longitude,
        tarifa: total!,
        tarifaDescuento: 0,
        tarifaInicial: total!,
        distancia: distancia.toDouble(),
        tiempoViaje: tiempoEnMinutos,
        horaInicioViaje: null,
        horaSolicitudViaje: Timestamp.now(),
        horaFinalizacionViaje: null,
        apuntes: apuntesAlConductor ?? ''
    );
    await _travelInfoProvider.create(travelInfo);
    _checkDriverResponse();
  }

  Future<void> getDriverInfo(String idDriver) async {
  }

  Future<bool> sendNotification(String token) async {
    final user = _authProvider.getUser();
    if (user == null) {
      return false;
    }

    final data = {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'idClient': user.uid,
      'origin': from,
      'originLat': fromLatlng.latitude.toString(),
      'originLng': fromLatlng.longitude.toString(),
      'destination': to,
      'destinationLat': toLatlng.latitude.toString(),
      'destinationLng': toLatlng.longitude.toString(),
      'tarifa': totalInt.toString(),
      'apuntes_usuario': apuntesAlConductor,
    };

    try {
      await _pushNotificationsProvider.sendMessage(token, data);
      if (kDebugMode) {
        print('Notification sent successfully');
      }
      await Future.delayed(const Duration(seconds: 20)); // Simular tiempo de espera
      return false;
    } catch (error) {
      if (kDebugMode) {
        print('Failed to send notification: $error');
      }
      return false;
    }
  }

}


import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/geofire_provider.dart';
import '../../../../providers/push_notifications_provider.dart';
import '../../../models/directions.dart';
import '../../../models/driver.dart';
import '../../../models/place.dart';
import '../../../models/price.dart';
import '../../../models/travel_info.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/google_provider.dart';
import '../../../providers/price_provider.dart';
import '../../../providers/travel_info_provider.dart';
import 'package:apptaxis/models/client.dart';
import 'package:apptaxis/utils/utilsMap.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../../src/colors/colors.dart';
import '../../travel_map_page/View/travel_map_page.dart';

class TravelInfoController{
  late BuildContext context;
  late GoogleProvider _googleProvider;
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
  final String _yourGoogleAPIKey = dotenv.get('API_KEY');
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
  late Direction _directions;
  String? min;
  String? km;
  double? total;
  Place? place;
  int? totalInt;
  double? radioDeBusqueda;
  String rolUsuario = "";
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



  Future<void> init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _googleProvider = GoogleProvider();
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

    if (arguments != null) {
      updateMap();
      from = arguments['from'] ?? "Desconocido";
      to = arguments['to'] ?? "Desconocido";
      fromLatlng = arguments['fromlatlng'];
      toLatlng = arguments['tolatlng'];
      animateCameraToPosition(fromLatlng.latitude, fromLatlng.longitude);
      getGoogleMapsDirections(fromLatlng, toLatlng);
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


  void getGoogleMapsDirections(LatLng from, LatLng to) async {
    _directions = await _googleProvider.getGoogleMapsDirections(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    // Verifica que las direcciones se hayan recibido correctamente
    String fromCity = extractCity(_directions.startAddress) ?? 'Ciudad de Origen Desconocida';
    String toCity = extractCity(_directions.endAddress) ?? 'Ciudad de Destino Desconocida';
    if (kDebugMode) {
      print('Ciudad de Origen: $fromCity');
    }
    if (kDebugMode) {
      print('Ciudad de Destino: $toCity');
    }
    // Actualiza las variables de distancia y duración
    distancia = _directions.distance?.value ?? 0;
    distanciaString = _directions.distance?.text ?? '';
    duracion = _directions.duration?.value ?? 0;
    tiempoEnMinutos = duracion / 60;
    duracionString = _directions.duration?.text ?? '';
    // Formatea y actualiza las variables para la duración y la distancia
    min = formatDuration(_directions.duration?.text ?? '');
    km = _directions.distance?.text ?? '';
    // Llama a los métodos para calcular el precio, obtener el radio de búsqueda y el rol del usuario
    calcularPrecio();
    obtenerRadiodeBusqueda();

    setPolylines();
    }

  Future<void> setPolylines() async {
    clearMap(); // Limpia el mapa antes de establecer nuevas rutas y marcadores

    PointLatLng pointFromLatlng = PointLatLng(fromLatlng.latitude, fromLatlng.longitude);
    PointLatLng pointToLatlng = PointLatLng(toLatlng.latitude, toLatlng.longitude);

    // Obtenemos la ruta entre los puntos
    PolylineResult result = await PolylinePoints().getRouteBetweenCoordinates(
      _yourGoogleAPIKey,
      pointFromLatlng,
      pointToLatlng,
    );

    if (result.points.isNotEmpty) {
      // Limpia la lista de puntos para la nueva ruta
      points.clear();

      // Agrega los puntos obtenidos de la API
      for (PointLatLng point in result.points) {
        points.add(LatLng(point.latitude, point.longitude));
      }

      // Limpiar las polilíneas anteriores
      polylines.clear();

      // Crear la nueva polyline
      Polyline polyline = Polyline(
        polylineId: const PolylineId('route'),
        color: primary, // Asegúrate de definir el color correctamente
        points: points,
        width: 5,
      );

      // Añadir la nueva polyline a la lista de polilíneas
      polylines.add(polyline);

      // Añadir los marcadores de origen y destino
      addMarker('from', fromLatlng.latitude, fromLatlng.longitude, 'Origen', '', fromMarker);
      addMarker('to', toLatlng.latitude, toLatlng.longitude, 'Destino', '', toMarker);

      // Llama a refresh para actualizar la vista
      refresh();
    } else {
      if (kDebugMode) {
        print("No se encontraron puntos de ruta entre los puntos especificados.");
      }
    }
  }


  void calcularPrecio() async {
    try {
      // Obtener precios desde el proveedor
      Price price = await _pricesProvider.getAll();
      double? valorKilometro;
      double? valorMinuto;

      // Validar y calcular el costo por kilómetros
      if (km != null) {
        // Extraer y convertir la distancia en kilómetros
        double distanciaKm = double.parse(km!.split(" ")[0].replaceAll(',', ''));

        // Cálculo base del costo por kilómetros
        valorKilometro = distanciaKm * price.theValorKmRegular.toDouble();

        // Aplicar incrementos según la distancia
        if (distanciaKm > 100) {
          valorKilometro *= 2.00; // Incremento del 100%
        } else if (distanciaKm > 80) {
          valorKilometro *= 1.80; // Incremento del 80%
        } else if (distanciaKm > 50) {
          valorKilometro *= 1.50; // Incremento del 50%
        } else if (distanciaKm > 40) {
          valorKilometro *= 1.40; // Incremento del 40%
        } else if (distanciaKm > 30) {
          valorKilometro *= 1.30; // Incremento del 30%
        } else if (distanciaKm > 20) {
          valorKilometro *= 1.20; // Incremento del 20%
        }
      } else {
        valorKilometro = 0.0; // Si no hay kilómetros, asignar 0
      }

      // Validar y calcular el costo por minutos
      if (min != null) {
        double minutos = double.parse(min!.split(" ")[0].replaceAll(',', ''));
        valorMinuto = minutos * price.theValorMinRegular.toDouble();
      } else {
        valorMinuto = 0.0; // Si no hay minutos, asignar 0
      }

      // Verificar que ambos valores no sean nulos antes de sumar
      if (valorKilometro != null && valorMinuto != null) {
        // Cálculo del total con dinámica
        total = (valorMinuto + valorKilometro) * price.theDinamica.toDouble();

        // Redondear a la centena más cercana
        total = redondearACentena(total);

        // Obtener la tarifa mínima según el rol
        double tarifaMinima = price.theTarifaMinimaRegular.toDouble();

        // Asegurar que el total no sea menor a la tarifa mínima
        total = total?.clamp(tarifaMinima, double.infinity);

        // Convertir el total a entero para su representación
        totalInt = total?.toInt();

        // Actualizar la interfaz
        refresh();
      } else {
        throw Exception('Valores de cálculo no válidos');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al calcular el precio: $e');
      }
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

  void getNearbyDrivers() {
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
    if (index >= driverIds.length) {
      if (kDebugMode) {
        print('No hay más conductores disponibles. Proceso completado.');
      }
      notifiedDrivers.clear();  // Limpiamos el conjunto para futuras búsquedas.
      return;
    }

    String driverId = driverIds[index];
    if (notifiedDrivers.contains(driverId)) {
      _attemptToSendNotification(driverIds, index + 1);
      return;
    }

    notifiedDrivers.add(driverId);  // Añadimos el conductor al conjunto de notificados.
    if (kDebugMode) {
      print("Enviando notificación al conductor $driverId");
    }

    getDriverInfo(driverId).then((_) async {
      Driver? driver = await _driverProvider.getById(driverId);
      if (driver != null) {
        if (kDebugMode) {
          print('ID del conductor: ${driver.id}');
        }
        if (kDebugMode) {
          print('Token del conductor: ${driver.token}');
        }
      } else {
        if (kDebugMode) {
          print('El conductor no fue encontrado.');
        }
      }

      // Mover la verificación de `notifiedDrivers` al inicio del bloque condicional
      if (driver?.token != null) {
        bool accepted = await sendNotification(driver!.token);
        if (accepted) {
          if (kDebugMode) {
            print('El conductor $driverId aceptó el servicio.');
          }
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

      // Agregar al conductor después de verificar el token y enviar la notificación
      notifiedDrivers.add(driverId);
      _attemptToSendNotification(driverIds, index + 1);
    }).catchError((error) {
      if (kDebugMode) {
        print('Error al obtener información del conductor $driverId: $error');
      }
      _attemptToSendNotification(driverIds, index + 1);
    });
  }

  void _checkDriverResponse() {
    Stream<DocumentSnapshot> stream = _travelInfoProvider.getByIdStream(_authProvider.getUser()!.uid);
    _streamStatusSuscription = stream.listen((DocumentSnapshot document) {
      if (document.exists && document.data() != null) {
        Map<String, dynamic> data = document.data() as Map<String, dynamic>;
        TravelInfo travelInfo = TravelInfo.fromJson(data);

        if (travelInfo.status == 'accepted') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const TravelMapPage()),
                (route) => false,
          );
        }
      } else {
        if (kDebugMode) {
          print('El documento no existe o está vacío');
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

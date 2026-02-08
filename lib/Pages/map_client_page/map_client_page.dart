
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/auth_provider.dart';
import '../../helpers/conectivity_service.dart';
import '../../helpers/session_manager.dart';
import '../../providers/client_provider.dart';
import '../../src/colors/colors.dart';
import '../Login_page/login_page.dart';
import 'map_client_controler.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';




class MapClientPage extends StatefulWidget {
  const MapClientPage({super.key});

  @override
  State<MapClientPage> createState() => _MapClientPageState();
}

class _MapClientPageState extends State<MapClientPage> {
  final ClientMapController _controller = ClientMapController();
  late MyAuthProvider _authProvider;
  late ClientProvider _clientProvider;
  late bool isVisibleCajonBusquedaOrigenDestino = false;
  late bool isVisibleBotonBuscarVehiculo = false;
  late bool isVisibleADondeVamos = true;
  late bool isVisibleiconoLineaVertical = true;
  late bool isVisibleEspacio = true;
  late bool isVisiblePinBusquedaDestino = false;
  late bool isVisibleBotonPinBusquedaDestino = true;
  late bool isVisibleCerrarIconoBuscarenMapa = false;
  late bool isVisibleCajoncambiandoDireccionDestino = false;
  late bool isVisibleTextoEligetuViaje = true;
  late bool fromVisible = true;
  late bool isLoading = true;
  LatLng? selectedToLatLng;
  double iconTop = 0.0;
  final _textController = TextEditingController();
  List<SearchHistoryItem> searchHistory = [];
  bool _historyLoaded = false;

  LatLng? tolatlng;
  double bottomMaps= 270;
  final ConnectionService connectionService = ConnectionService();
  LatLng? _ubicacionActual;

  //new autocomplete backend
  Timer? _debounce;
  List<Map<String, String>> _predictions = [];
  bool _loadingPreds = false;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  void Function(void Function())? _sheetSetState;
  bool _isSheetOpen = false;
  bool _navigatingAfterPick = false;
  bool _pickingPlace = false;

  List<FavoritePlace> favoritePlaces = [];
  static const String _favKey = 'favorite_places_v1';
  SearchHistoryItem? _lastPickedPlace;





  void _safeSheetRepaint() {
    if (!_isSheetOpen) return;
    final s = _sheetSetState;
    if (s == null) return;

    try {
      s(() {});
    } catch (_) {
      // Si el sheet ya murió, cortamos la referencia
      _sheetSetState = null;
      _isSheetOpen = false;
    }
  }


  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _authProvider = MyAuthProvider();
      _clientProvider = ClientProvider();

      // 1) Primero valida sesión
      try {
        await SessionManager.loginGuard(collection: 'Clients');
        SessionManager.startHeartbeat(collection: 'Clients');
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Ya hay una sesión activa')
                  ? 'Tu cuenta ya está abierta en otro dispositivo. Cierra sesión allá o espera 1 minuto e intenta de nuevo.'
                  : 'No se pudo validar tu sesión. Intenta nuevamente.',
            ),
          ),
        );

        await _authProvider.signOut();

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
        return; // 👈 importante
      }

      // 2) Si la sesión está OK, ahora sí carga el resto
      _controller.init(context, refresh);
      _checkConnection();
      checkForUpdate();
      _loadSearchHistory();
      _loadFavorites();
    });
  }


  Future<void> _checkConnection() async {
    await connectionService.checkConnectionAndShowCard(context, () {
           setState(() {
      });
    });
  }

  @override
  void dispose() {
    SessionManager.stopHeartbeat();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }


  Future<void> checkForUpdate() async {
    try {
      AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      print('Estado de la actualización: ${updateInfo.updateAvailability}');
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        print('¡*****************Actualización disponible!*************');
        await InAppUpdate.performImmediateUpdate();
      } else {
        print('***********************No hay actualizaciones disponibles.****************');
      }
    } catch (e) {
      print('***************Error al verificar actualizaciones: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));
    return PopScope(
      canPop: false,
      child: Scaffold(
          appBar: AppBar(
            backgroundColor: primary,
            iconTheme: const IconThemeData(color: negro, size: 24),
            title: Text(
              'Hoy es: ${DateFormat("d MMM 'de' y", 'es').format(DateTime.now())}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            actions: const <Widget>[
              Image(
                height: 40.0,
                width: 90.0,
                image: AssetImage('assets/metax_logo.png'),
              ),
            ],
          ),
          backgroundColor: grisMapa,
          key: _controller.key,
          drawer: _drawer(),
          body: Stack(
            children: [
              _googleMapsWidget(),
              SafeArea(
                child: Column(
                  children: [
                      Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buttonCenterPosition(),
                      ],
                    ),

                    Expanded(child: Container()),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _letrerosADondeVamos (),
                      ],
                    ),
                    _cajonCambiandoDirecciondeDestino(),

                  ],
                ),
              ),

              Align(
                alignment: Alignment.center,
                child: _iconBuscarEnElMapaDestino(),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: _botonBuscarEnElMapaDestino(),
              ),

              Visibility(
                visible: isLoading,
                child: Container(
                  color: Colors.white.withOpacity(0.8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('Cargando...'),
                        SizedBox(height: 10.r),
                        const CircularProgressIndicator(color: gris),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
      ),
    );
  }


  Widget _letrerosADondeVamos () {
    return Visibility(
      visible: isVisibleADondeVamos,
      child: Container(
        height: 300.r, // Utiliza una función para calcular la altura dinámicamente
        width: double.infinity,
        decoration: BoxDecoration(
            borderRadius:  BorderRadius.only(
              topLeft: Radius.circular(30.r),
              topRight: Radius.circular(30.r),
            ),

            boxShadow: [
              BoxShadow(
                color: negro.withOpacity(0.4),
                offset:Offset(0, 8.r),
                blurRadius: 9.r,
              ),
            ],
            color: Colors.white
        ),
        padding: EdgeInsets.only(top: 15.r),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(left: 20.r, right: 20.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estás aquí', style: TextStyle( fontSize: 11, fontWeight: FontWeight.w500, color: negro)),
                  Row(
                    children: [
                      Image.asset(
                        'assets/ubicacion_client.png', // La imagen original
                        height: 12, // Ajusta la altura de la imagen
                        width: 12, // Ajusta el ancho de la imagen
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _controller.from ?? '',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: negro
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(vertical: 10.r, horizontal: 15.r),
              child: Row(
                children: [
                  // 🔍 A DÓNDE VAMOS (más angosto)
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: () {
                        connectionService.hasInternetConnection().then((hasConnection) {
                          if (hasConnection) {
                            _onBottomSheetOpened();
                            _mostrarCajonDeBusqueda(context, (selectedAddress) {});
                          } else {
                            alertSinInternet();
                          }
                        });
                      },
                      child: Container(
                        height: 52.r,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.6),
                              offset: Offset(0, 2.r),
                              blurRadius: 6.r,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12.r),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: negro),
                            SizedBox(width: 8.r),
                            const Expanded(
                              child: Text(
                                '¿A dónde vamos?',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 10.r),

                  // ⭐ FAVORITOS (container independiente)
              GestureDetector(
                onTap: () async {
                  await connectionService.checkConnectionAndShowCard(
                    context,
                        () {
                      _showFavoritesSheet();
                    },
                  );
                },
                child: Container(
                  height: 52.r,
                  width: 80.r,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black87, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        offset: Offset(0, 2.r),
                        blurRadius: 6.r,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Favoritos',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 2),
                      Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              ],
              ),
            ),
            const SizedBox(height: 6),

            _vistaHistorialBusquedas()
          ],
        ),
      ),
    );
  }

  void _showFavoritesSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Destinos frecuentes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              if (favoritePlaces.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Aún no tienes favoritos guardados.'),
                )
              else
                ...favoritePlaces.map((f) => ListTile(
                  leading: const Icon(Icons.star_rounded, color: Colors.amber),
                  title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    f.subtitle.isNotEmpty ? '${f.title}, ${f.subtitle}' : f.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    final hasConnection = await connectionService.hasInternetConnection();
                    if (!hasConnection) {
                      alertSinInternet(); // 👈 solo alerta
                      return;
                    }

                    final latLng = LatLng(f.lat, f.lng);

                    setState(() {
                      _controller.to = f.subtitle.isNotEmpty ? '${f.title}, ${f.subtitle}' : f.title;
                      _controller.tolatlng = latLng;
                    });

                    Navigator.pop(context);
                    _controller.requestDriver(); // aquí ya va a calcular ruta/tarifa con internet
                  },

                )),
            ],
          ),
        );
      },
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


  Widget _cajonCambiandoDirecciondeDestino (){
    return Visibility(
      visible: isVisibleCajoncambiandoDireccionDestino,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: blancoCards,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Buscando el lugar de destino en el mapa.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on, // Cambia la imagen por el icono de bandera
                        color: Colors.green, // Color verde para el icono
                        size: 20, // Ajusta el tamaño del icono al mismo que tenía la imagen
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _controller.to ?? '',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )

              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      elevation: 6,
                    ),
                    onPressed: () {
                      _controller.centerPosition();
                      setState(() {
                        isVisiblePinBusquedaDestino = false;
                        isVisibleBotonPinBusquedaDestino = true;
                        isVisibleCajoncambiandoDireccionDestino = false;
                        isVisibleADondeVamos = true;
                        _controller.requestDriver();
                      });
                    },
                    child:const Text(
                      'Confirmar',
                      style: TextStyle(
                        color: negro,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      elevation: 6,
                    ),
                    onPressed: () {
                      _controller.centerPosition();
                      //_controller.to = '¿A dónde quieres ir?';
                      if (mounted) {
                        setState(() {
                          bottomMaps= 270;
                          if (isVisiblePinBusquedaDestino) {
                            isVisiblePinBusquedaDestino = false;
                          }
                          isVisibleCajoncambiandoDireccionDestino = false;
                          isVisibleADondeVamos = true;
                          isVisibleBotonPinBusquedaDestino = true;
                        });
                      }
                    },
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: negro,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleMapsWidget() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300), // Ajusta la duración de la animación según sea necesario
      top: isVisibleCajonBusquedaOrigenDestino ? 0 : 0,
      left: 0,
      right: 0,
      bottom: bottomMaps,
      child: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _controller.initialPosition,

        onMapCreated: (GoogleMapController controller) {
          _controller.onMapCreated(controller);

          if (mounted) {
            setState(() {
              isLoading = false; // ✅ se quita apenas el mapa está listo
            });
          }
        },
        rotateGesturesEnabled: false,
        zoomControlsEnabled: false,
        tiltGesturesEnabled: false,
        markers: !isVisiblePinBusquedaDestino? Set<Marker>.of(_controller.markers.values): {},
        onCameraMove: (position) {
          _controller.initialPosition = position;
        },
        onCameraIdle: () async {
          if (_controller.currentLocation != null) {
            setState(() {
              _ubicacionActual = LatLng(
                _controller.currentLocation!.latitude,
                _controller.currentLocation!.longitude,
              );
              isLoading = false;
            });
          }

          if (isVisiblePinBusquedaDestino) {
            await _controller.setLocationdraggableInfo();
          }
          await _controller.setLocationdraggableInfoOrigen();
        },
      ),
    );
  }

  Widget _drawer(){
    return Drawer(
      backgroundColor: blancoCards,
      child: ListView(
        children: [
          SizedBox(
            height: 250.r,
            child: DrawerHeader(
              decoration: const BoxDecoration(
                  color: primary
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      _controller.goToProfile();
                    },
                    child: CircleAvatar(
                      backgroundColor: blanco,
                      backgroundImage: _controller.client?.image != null
                          ? CachedNetworkImageProvider(_controller.client!.image)
                          : null,
                      radius: 45,
                    ),
                  ),

                  Text(_controller.client?.the01Nombres ?? '', style: TextStyle(
                      fontSize: 18.r, fontWeight: FontWeight.w900, color: Colors.black
                  ),
                    maxLines: 1,
                  ),
                  Text(_controller.client?.the02Apellidos ?? '', style: TextStyle(
                      fontSize: 13.r, fontWeight: FontWeight.w500, color: Colors.black
                  ),
                    maxLines: 1,
                  ),
                ],
              ),

            ),
          ),

          ListTile(
            leading: const Icon(Icons.history, color: gris), // Icono para Historial de viajes
            title: Text('Historial de viajes', style: TextStyle(
                fontWeight: FontWeight.w400, color: negro, fontSize: 16.r
            )),
            onTap: _controller.goToHistorialViajes,
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip, color: gris), // Icono para Políticas de privacidad
            title: Text('Políticas de privacidad', style: TextStyle(
                fontWeight: FontWeight.w400, color: negro, fontSize: 16.r
            )),
            onTap: _controller.goToPoliticasDePrivacidad,
          ),

          ListTile(
            leading: const Icon(Icons.contact_mail, color: gris), // Icono para Contáctanos
            title: Text('Contáctanos', style: TextStyle(
                fontWeight: FontWeight.w400, color: negro, fontSize: 16.r
            )),
            onTap: _controller.goToContactanos,
          ),

          ListTile(
            leading: const Icon(Icons.share, color: gris), // Icono para Compartir aplicación
            title: Text('Compartir aplicación', style: TextStyle(
                fontWeight: FontWeight.w400, color: negro, fontSize: 16.r
            )),
            iconColor: gris,
            onTap: _controller.goToCompartirAplicacion,
          ),

          const Divider(color: grisMedio),

          ListTile(
            leading: const Icon(Icons.logout, color: gris), // Icono para Cerrar sesión
            title: Text('Cerrar sesión', style: TextStyle(
                fontWeight: FontWeight.w400, color: negro, fontSize: 16.r
            )),
            iconColor: gris,
            onTap: () {
              Navigator.pop(context);
              _mostrarAlertDialog(context);
            },
          ),

          ListTile(
            leading: const Icon(Icons.delete, color: gris), // Icono para Eliminar cuenta
            title: Text('Eliminar cuenta', style: TextStyle(
                fontWeight: FontWeight.w400, color: negro, fontSize: 16.r
            )),
            onTap: _controller.goToEliminarCuenta,
          ),
        ],
      ),
    );
  }

  void refresh() {
    if (mounted) {
      setState(() {
      });
    }
  }

  Widget _buttonCenterPosition(){
    return GestureDetector(
      onTap: _controller.centerPosition,
      child: Container(
        alignment: Alignment.bottomRight,
        margin: EdgeInsets.only(left: 10.r, top: 15.r),
        child: Card(
          shape: const CircleBorder(),
          color: primary,
          surfaceTintColor: Colors.white,
          elevation: 2,
          child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                boxShadow: const [
                  BoxShadow(
                    offset: Offset(0.0, 15.0),
                    blurRadius: 25,
                    color: gris,
                  )
                ],
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(Icons.location_searching, color: negro, size:20.r,)),
        ),
      ),
    );
  }


  void _mostrarAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cierre de sesión', textAlign: TextAlign.center, style: TextStyle(
              color: negro,
              fontWeight: FontWeight.bold
          ),),
          content: Text('¿En verdad quieres cerrar la sesión?', style: TextStyle(
              fontSize: 16.r
          ),),
          actions: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () async {
                      // 1) Cierra el diálogo
                      Navigator.of(context).pop();

                      // 2) Detén heartbeat + logout Firestore
                      try {
                        SessionManager.stopHeartbeat();
                        await SessionManager.logout(collection: 'Clients');
                      } catch (_) {}

                      // 3) Cierra sesión en Auth
                      await _authProvider.signOut();

                      if (!mounted) return;

                      // 4) Ir al login
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                            (route) => false,
                      );
                    },
                    child: Text('Sí', style: TextStyle(
                        fontSize: 16.r, fontWeight: FontWeight.bold, color: negro
                    ),),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('No', style: TextStyle(
                        fontSize: 16.r, fontWeight: FontWeight.bold, color: negro
                    ),),
                  ),
                ],
              ),
            )
          ],
        );
      },
    );
  }

  Widget _botonBuscarEnElMapaDestino(){
    return Visibility(
      visible: isVisibleBotonPinBusquedaDestino,
      child: GestureDetector(
        onTap: () async {
          // Verificar conexión a Internet antes de ejecutar la acción
          bool hasConnection = await connectionService.hasInternetConnection();

          if (hasConnection) {
            // Si hay conexión, ejecuta la acción de ir a "Olvidaste tu contraseña"
            if (mounted) {
              setState(() {
                bottomMaps = 170;
                isVisiblePinBusquedaDestino = true;
                isVisibleBotonPinBusquedaDestino = false;
                isVisibleCajoncambiandoDireccionDestino = true;
                isVisibleADondeVamos = false;

                // Llamar setLocationdraggableInfo solo cuando el icono es visible
                if (isVisiblePinBusquedaDestino) {
                  _controller.setLocationdraggableInfo();
                }
              });
            }
          } else {
            alertSinInternet();
          }
        },

        child: Container(
          height:  ScreenUtil().setSp(40),
          width: ScreenUtil().setSp(100),
          margin: const EdgeInsets.only(bottom: 350),
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24)
            ),

            boxShadow: [
              BoxShadow(
                offset: Offset(5.0, 3.0),
                blurRadius: 20,
                color: gris,
              )
            ],
          ),

          child: Row(
            children: [
              Image.asset('assets/icono_buscar_posicion.png', width: 35, height: 35),
              const Text('Mapa', style: TextStyle(fontSize: 10, color: negro, fontWeight: FontWeight.w900))
            ],

          ),
        ),
      ),
    );
  }

  Widget _iconBuscarEnElMapaDestino() {
    return Stack(
      children: [
        // Otros widgets en el Stack
        Positioned(
          top: MediaQuery.of(context).size.height / 2 - 165, // 40 es la mitad de la altura del icono (80)
          left: 0,
          right: 0,
          child: Visibility(
            visible: isVisiblePinBusquedaDestino,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: GestureDetector(
                onTap: () {
                  _mostrarCajonDeBusqueda(context, (selectedAddress) {
                    setState(() {
                      isVisiblePinBusquedaDestino = false;
                      isVisibleCajonBusquedaOrigenDestino = true;
                      isVisibleTextoEligetuViaje = true;
                      isVisibleBotonBuscarVehiculo = true;
                      isVisibleBotonPinBusquedaDestino = true;
                      isVisibleCajoncambiandoDireccionDestino = false;

                      // Actualizar el campo 'to' con la dirección seleccionada desde el mapa
                      _controller.to = selectedAddress;
                    });
                  });
                },
                child: Image.asset('assets/icono_buscar_posicion.png', width: 50.r, height: 50.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarCajonDeBusqueda(
      BuildContext context,
      Function(String) onAddressSelected,
      ) async {
    _onBottomSheetOpened(); // limpia antes de abrir

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            _sheetSetState = setModalState;
            _isSheetOpen = true;

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: _cajonDebusqueda(onAddressSelected),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _debounce?.cancel();
      _sheetSetState = null;
      _isSheetOpen = false;

      // Limpia lo visual para que al abrir NO salga lo anterior
      if (mounted) {
        setState(() {
          _predictions = [];
          _loadingPreds = false;
        });
      }
    });
  }

  void _onBottomSheetOpened() {
    _debounce?.cancel();
    _textController.clear();

    if (!mounted) return;
    setState(() {
      _predictions = [];
      _loadingPreds = false;
    });
  }

  void _cerrarBottomSheet(BuildContext context) {
    _saveSearchHistory();
    _debounce?.cancel();

    if (mounted) {
      setState(() {
        _textController.clear();
        _predictions = [];
        _loadingPreds = false;
      });
    }

    // repinta si está abierto (seguro)
    _safeSheetRepaint();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }


  Widget _cajonDebusqueda(Function(String) onSelectAddress) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 50.r),

              Text(
                'Escribe el sitio a donde vamos',
                style: TextStyle(
                  fontSize: 18.r,
                  fontWeight: FontWeight.w900,
                  color: negroLetras,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 10.r),

              Container(
                padding: EdgeInsets.all(5.r),
                margin: EdgeInsets.only(left: 10.r, right: 10.r),
                decoration: BoxDecoration(
                  color: blancoCards,
                  borderRadius: const BorderRadius.all(Radius.circular(1)),
                  boxShadow: [
                    BoxShadow(
                      color: gris,
                      offset: Offset(1, 1.r),
                      blurRadius: 6.r,
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Visibility(
                              visible: isVisibleiconoLineaVertical,
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/ubicacion_client.png',
                                    height: 25.r,
                                    width: 15.r,
                                  ),
                                  Container(
                                    color: negroLetras,
                                    width: 1,
                                    height: 65,
                                  ),
                                ],
                              ),
                            ),
                            Image.asset(
                              'assets/marker_destino.png',
                              height: 25.r,
                              width: 20.r,
                            ),
                          ],
                        ),

                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                margin: EdgeInsets.only(left: 5.r, right: 10.r),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 5),

                                    Text(
                                      'Origen',
                                      style: TextStyle(
                                        color: negroLetras,
                                        fontSize: 12.r,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    Container(
                                      margin: EdgeInsets.only(top: 10.r),
                                      width: MediaQuery.of(context).size.width.round() * 0.80,
                                      child: GestureDetector(
                                        onTap: () {},
                                        child: Container(
                                          padding: EdgeInsets.only(
                                            left: 8.r,
                                            top: 10.r,
                                            bottom: 10.r,
                                          ),
                                          decoration: BoxDecoration(
                                            color: blanco,
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(color: primary),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primary.withOpacity(0.3),
                                                offset: const Offset(0, 2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _controller.from ?? '',
                                            style: TextStyle(
                                              color: negroLetras,
                                              fontSize: 13.r,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (isVisibleEspacio) SizedBox(height: 10.r),

                              Container(
                                margin: EdgeInsets.only(left: 5.r, right: 10.r, bottom: 10.r),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 5),
                                    Text(
                                      'Destino',
                                      style: TextStyle(
                                        color: negroLetras,
                                        fontSize: 12.r,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(
                                      width: MediaQuery.of(context).size.width.round() * 0.80,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height: 50.r,
                                            margin: EdgeInsets.only(top: 10.r),
                                            decoration: BoxDecoration(
                                              color: grisClaro,
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(color: grisMedio),
                                            ),
                                            alignment: Alignment.center,
                                            child: TextField(
                                              autofocus: true,
                                              controller: _textController,
                                              textCapitalization: TextCapitalization.sentences,
                                              cursorColor: Colors.black,
                                              maxLines: 1,
                                              decoration: InputDecoration(
                                                hintText: 'Escribe el destino…',
                                                hintStyle: TextStyle(fontSize: 12.r),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(
                                                  horizontal: 12.r,
                                                ),
                                              ),
                                              onChanged: _onDestinoChanged,
                                            ),
                                          ),

                                          if (_loadingPreds)
                                            Padding(
                                              padding: EdgeInsets.only(top: 8.r),
                                              child: const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),

                                          if (_predictions.isNotEmpty)
                                            Container(
                                              margin: EdgeInsets.only(top: 8.r),
                                              height: 220.r,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: grisMedio),
                                              ),
                                              child: ListView.separated(
                                                itemCount: _predictions.length,
                                                separatorBuilder: (_, __) => const Divider(height: 1),
                                                itemBuilder: (_, i) {
                                                  final p = _predictions[i];

                                                  return ListTile(
                                                    dense: true,
                                                    title: Text(
                                                      p['description']!,
                                                      style: TextStyle(fontSize: 12.r),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),

                                                    // ✅ Bloquear taps mientras está procesando selección
                                                    enabled: !_pickingPlace,
                                                    onTap: _pickingPlace
                                                        ? null
                                                        : () => _selectPrediction(
                                                      placeId: p['placeId']!,
                                                      description: p['description']!,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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

              Container(
                margin: EdgeInsets.only(top: 10.r, bottom: 10.r, right: 15.r),
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: _pickingPlace ? null : () => _cerrarBottomSheet(context),
                  child: Container(
                    margin: EdgeInsets.only(top: 15.r, right: 10.r),
                    width: 80.r,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.cancel_rounded, size: 20.r),
                        const Text(
                          'Cerrar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ✅ OVERLAY de carga al seleccionar un lugar (bloquea interacción)
        if (_pickingPlace)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.65),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: 10.r),
                    Text(
                      'Cargando destino…',
                      style: TextStyle(
                        fontSize: 13.r,
                        fontWeight: FontWeight.w700,
                        color: negroLetras,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }



  Future<void> _selectPrediction({
    required String placeId,
    required String description,
  }) async {
    if (_navigatingAfterPick) return;
    _navigatingAfterPick = true;

    if (mounted) {
      setState(() => _pickingPlace = true);
    }
    _safeSheetRepaint();

    try {
      final res = await _functions.httpsCallable('placeDetails').call({
        'placeId': placeId,
      });

      final data = Map<String, dynamic>.from(res.data);

      if (data['ok'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pude obtener la ubicación. Intenta de nuevo.')),
          );
        }
        return;
      }

      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final latLng = LatLng(lat, lng);

      final split = _splitNameAndAddress(description);
      final title = split['title']!;
      final subtitle = split['subtitle']!;

      if (!mounted) return;

      // ✅ construimos el item UNA SOLA VEZ
      final pickedItem = SearchHistoryItem(
        placeId: placeId,
        title: title,
        subtitle: subtitle,
        lat: latLng.latitude,
        lng: latLng.longitude,
      );

      // ✅ Actualiza UI + controller con lo que el usuario vio
      setState(() {
        _textController.text = description;
        _controller.to = description;
        _controller.tolatlng = latLng;
        _predictions = [];
        _loadingPreds = false;

        // ✅ IMPORTANTE: guardamos "último destino seleccionado"
        _lastPickedPlace = pickedItem;
      });

      // ✅ Guarda historial
      await _guardarEnHistorialItem(pickedItem);

      if (!mounted) return;

      // ✅ Cierra el bottomsheet
      Navigator.of(context, rootNavigator: true).pop();

      // ✅ Navega al flujo normal
      _controller.requestDriver();
    } catch (e) {
      if (kDebugMode) print('selectPrediction error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hubo un error cargando el destino.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPlace = false);
      _safeSheetRepaint();
      _navigatingAfterPick = false;
    }
  }


  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final rawAny = prefs.get(_favKey);

    List<FavoritePlace> items = [];
    try {
      if (rawAny is String && rawAny.isNotEmpty) {
        final decoded = jsonDecode(rawAny) as List<dynamic>;
        items = decoded.map((e) => FavoritePlace.fromJson(Map<String, dynamic>.from(e))).toList();
      } else {
        items = [];
      }
    } catch (_) {
      await prefs.remove(_favKey);
      items = [];
    }

    if (!mounted) return;
    setState(() => favoritePlaces = items);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favoritePlaces.map((e) => e.toJson()).toList();
    await prefs.setString(_favKey, jsonEncode(jsonList));
  }




  Future<void> _onDestinoChanged(String value) async {
    _debounce?.cancel();
    final q = value.trim();

    if (q.length < 3) {
      if (!mounted) return;
      setState(() {
        _predictions = [];
        _loadingPreds = false;
      });
      _safeSheetRepaint();
      return;
    }

    // muestra loader rápido
    if (mounted) {
      setState(() => _loadingPreds = true);
    }
    _safeSheetRepaint();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final lat = _controller.currentLocation?.latitude;
        final lng = _controller.currentLocation?.longitude;

        final res = await _functions.httpsCallable('placesAutocomplete').call({
          'input': q,
          'country': 'co',
          'lat': lat,
          'lng': lng,
          'radiusMeters': 30000, // 12 km (ajústalo si quieres)
        });


        final data = Map<String, dynamic>.from(res.data);
        final list = (data['predictions'] as List? ?? []);

        final preds = list.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {
            'placeId': (m['placeId'] ?? '').toString(),
            'description': (m['description'] ?? '').toString(),
          };
        }).where((p) => p['placeId']!.isNotEmpty && p['description']!.isNotEmpty).toList();

        if (!mounted) return;
        setState(() => _predictions = preds);
        _safeSheetRepaint();
      } catch (_) {
        if (!mounted) return;
        setState(() => _predictions = []);
        _safeSheetRepaint();
      } finally {
        if (!mounted) return;
        setState(() => _loadingPreds = false);
        _safeSheetRepaint();
      }
    });
  }


  Widget _vistaHistorialBusquedas() {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(bottom: 15.r),
        child: !_historyLoaded
            ? const SizedBox.shrink() // ✅ mientras carga, no muestres nada (sin “flash”)
            : (searchHistory.isEmpty
            ? _estadoSinHistorial()
            : SingleChildScrollView(child: _listaHistorial())),
      ),
    );
  }


  Widget _estadoSinHistorial() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 50.r,
            color: gris,
          ),
          SizedBox(height: 10.r),
          Text(
            "Aún no tienes un\nhistorial de viajes recientes.",
            style: TextStyle(
              fontSize: 14.r,
              color: gris,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Map<String, String> _splitNameAndAddress(String description) {
    final parts = description.split(',');
    final title = parts.isNotEmpty ? parts.first.trim() : description.trim();
    final subtitle = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    return {'title': title, 'subtitle': subtitle};
  }




  Widget _listaHistorial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 10.r, bottom: 18.r),
          child: Text(
            'Tus últimas búsquedas',
            style: TextStyle(
              fontSize: 12.r,
              fontWeight: FontWeight.w900,
              color: negroLetras,
            ),
          ),
        ),

        ...searchHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          // ✅ para pintar el ícono diferente si ya está en favoritos
          final yaEsFavorito = favoritePlaces.any((f) =>
          f.title == item.title &&
              f.subtitle == item.subtitle &&
              f.lat == item.lat &&
              f.lng == item.lng);

          return Column(
            children: [
              GestureDetector(
                onTap: () async {
                  final hasConnection = await connectionService.hasInternetConnection();
                  if (!hasConnection) {
                    alertSinInternet();
                    return;
                  }

                  final latLng = LatLng(item.lat, item.lng);

                  setState(() {
                    _controller.to = item.subtitle.isNotEmpty
                        ? '${item.title}, ${item.subtitle}'
                        : item.title;
                    _controller.tolatlng = latLng;
                  });

                  _controller.requestDriver();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 3.r, horizontal: 6.r),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.green),
                      const SizedBox(width: 6),

                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: item.title,
                                style: TextStyle(
                                  fontSize: 11.r,
                                  fontWeight: FontWeight.w900,
                                  color: negro,
                                ),
                              ),
                              if (item.subtitle.isNotEmpty)
                                TextSpan(
                                  text: ', ${item.subtitle}',
                                  style: TextStyle(
                                    fontSize: 11.r,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ⭐ botón favorito (NO debe navegar)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _guardarFavoritoDesdeHistorial(item),
                        child: Padding(
                          padding: EdgeInsets.only(left: 8.r),
                          child: Icon(
                            yaEsFavorito ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 20.r,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (index != searchHistory.length - 1)
                const Divider(color: grisMedio),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _guardarFavoritoDesdeHistorial(SearchHistoryItem item) async {
    final labelController = TextEditingController(text: item.title);

    final label = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guardar en favoritos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colócale un nombre',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                hintText: 'Ej: Casa, Oficina, Tía Julia',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, labelController.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (label == null || label.isEmpty) return;

    final fav = FavoritePlace(
      label: label,
      title: item.title,
      subtitle: item.subtitle,
      lat: item.lat,
      lng: item.lng,
    );

    setState(() {
      favoritePlaces.removeWhere((f) => f.label.toLowerCase() == label.toLowerCase());
      favoritePlaces.insert(0, fav);
    });

    await _saveFavorites();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardado como "$label" ⭐')),
    );
  }



  Future<void> _guardarEnHistorialItem(SearchHistoryItem item) async {
    // Evitar duplicados por placeId (si viene)
    final exists = item.placeId.isNotEmpty
        ? searchHistory.any((e) => e.placeId == item.placeId)
        : searchHistory.any((e) => e.title == item.title && e.subtitle == item.subtitle);

    if (exists) return;

    setState(() {
      // Insertar primero
      searchHistory.insert(0, item);

      // Limitar a 3
      if (searchHistory.length > 3) {
        searchHistory = searchHistory.take(3).toList();
      }
    });

    await _saveSearchHistory();
  }


  void onSelectAddress(String address) async{
    // Obtener las coordenadas (LatLng) correspondientes a la dirección seleccionada
    LatLng? selectedLatLng = await getLatLngFromAddress(address);
    if (selectedLatLng != null) {
      setState(() {
        _controller.to = address;
        tolatlng = selectedLatLng;
      });
    }
  }

  Future<LatLng?> getLatLngFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      } else {
        if (kDebugMode) {
          print("No se encontraron coordenadas para la dirección: $address");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error al obtener coordenadas para la dirección: $address, Error: $e");
      }
      return null;
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // 👇 leemos el valor en bruto (puede ser String o List<String>)
    final rawAny = prefs.get('search_history_v2');

    List<SearchHistoryItem> items = [];

    try {
      if (rawAny is String && rawAny.isNotEmpty) {
        final decoded = jsonDecode(rawAny) as List<dynamic>;
        items = decoded
            .map((e) => SearchHistoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (rawAny is List) {
        // 🚨 Esto es el formato viejo/incorrecto que te está rompiendo.
        // Lo borramos para que ya no vuelva a dar rojo.
        await prefs.remove('search_history_v2');
        items = [];
      } else {
        items = [];
      }
    } catch (e) {
      if (kDebugMode) print('Error cargando historial v2: $e');
      await prefs.remove('search_history_v2'); // limpia por si quedó corrupto
      items = [];
    }

    // ✅ Opcional: borra también el historial viejo para evitar mezclas
    await prefs.remove('search_history');

    if (!mounted) return;
    setState(() {
      searchHistory = items;
      _historyLoaded = true;
    });
  }


  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = searchHistory.map((e) => e.toJson()).toList();
    await prefs.setString('search_history_v2', jsonEncode(jsonList));
  }


}

class SearchHistoryItem {
  final String placeId;
  final String title;      // nombre (negrilla)
  final String subtitle;   // dirección (gris)
  final double lat;
  final double lng;

  SearchHistoryItem({
    required this.placeId,
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'title': title,
    'subtitle': subtitle,
    'lat': lat,
    'lng': lng,
  };

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      placeId: (json['placeId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class FavoritePlace {
  final String label;     // Casa / Oficina / Tía Julia
  final String title;     // nombre en negrilla
  final String subtitle;  // dirección
  final double lat;
  final double lng;

  FavoritePlace({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'title': title,
    'subtitle': subtitle,
    'lat': lat,
    'lng': lng,
  };

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      label: (json['label'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}



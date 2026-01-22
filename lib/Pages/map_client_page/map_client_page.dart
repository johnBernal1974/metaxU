
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/auth_provider.dart';
import '../../helpers/conectivity_service.dart';
import '../../helpers/customloadingDialog.dart';
import '../../helpers/session_manager.dart';
import '../../providers/client_provider.dart';
import '../../service/places_functions_service.dart';
import '../../src/colors/colors.dart';
import '../Login_page/login_page.dart';
import 'map_client_controler.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';



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
  final String _yourGoogleAPIKey = dotenv.get('API_KEY');
  LatLng? selectedToLatLng;
  double iconTop = 0.0;
  final _textController = TextEditingController();
  List<String> searchHistory = [];
  LatLng? tolatlng;
  double bottomMaps= 270;
  final ConnectionService connectionService = ConnectionService();
  LatLng? _ubicacionActual;

  //new autocomplete backend
  Timer? _debounce;
  List<Map<String, String>> _predictions = [];
  bool _loadingPreds = false;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  //StateSetter? _sheetSetState; // para repintar SOLO el bottomsheet
  final FocusNode _destinoFocus = FocusNode();


  void Function(void Function())? _sheetSetState;
  bool _isSheetOpen = false;
  bool _navigatingAfterPick = false;




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





  // @override
  // void initState() {
  //   super.initState();
  //   SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
  //     _controller.init(context, refresh);
  //     _authProvider = MyAuthProvider();
  //     _clientProvider = ClientProvider();
  //     _checkConnection();
  //     checkForUpdate();
  //     _loadSearchHistory();
  //
  //   });
  // } comentado prueba

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
          SnackBar(content: Text(e.toString())),
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
            GestureDetector(
              onTap: () {
                // Verificar conexión a Internet antes de ejecutar la acción
                connectionService.hasInternetConnection().then((hasConnection) {
                  if (hasConnection) {
                    _onBottomSheetOpened();
                    // Llama a _mostrarCajonDeBusqueda inmediatamente
                    _mostrarCajonDeBusqueda(context, (selectedAddress) {});
                  } else {
                    // Llama a alertSinInternet inmediatamente si no hay conexión
                    alertSinInternet();
                  }
                });
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 10.r, horizontal: 15.r),
                decoration: BoxDecoration(
                  color: Colors.white, // Color de fondo del contenedor
                  borderRadius: BorderRadius.circular(24), // Esquinas redondeadas
                  border: Border.all(color: primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.8), // Color de la sombra
                      offset: Offset(0, 2.r),
                      blurRadius: 7.r,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(10.r), // Espaciado interno
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: negro), // Icono de búsqueda
                      SizedBox(width: 10.r), // Espacio entre el icono y el texto
                      const Expanded(
                        child: Text(
                          '¿A dónde vamos?', // Texto predeterminado
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            _vistaHistorialBusquedas()
          ],
        ),
      ),
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
        // onMapCreated: (GoogleMapController controller) async {
        //   _controller.onMapCreated(controller);
        //
        //   // Espera a que el mapa se cargue
        //   await Future.delayed(const Duration(seconds: 5));
        //
        //   // Oculta la capa de carga después del retraso
        //   setState(() {
        //     isLoading = false;
        //   });
        // }, comentado prueba 1
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
                      await SessionManager.logout(collection: 'Clients');
                      await _authProvider.signOut();

                      if (!context.mounted) return;

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
    return SingleChildScrollView(
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

                    // ✅ Columna derecha (Origen/Destino)
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 5.r, right: 10.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 5),

                                // ORIGEN
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

                          // DESTINO
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
                                      // ✅ 1) TextField en caja de 50.r (SOLO el input)
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

                                      // ✅ 2) Loader debajo
                                      if (_loadingPreds)
                                        Padding(
                                          padding: EdgeInsets.only(top: 8.r),
                                          child: const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),

                                      // ✅ 3) Lista debajo (YA con espacio)
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
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                onTap: () => _selectPrediction(
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

          // CERRAR
          Container(
            margin: EdgeInsets.only(top: 10.r, bottom: 10.r, right: 15.r),
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => _cerrarBottomSheet(context),
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
    );
  }

  Future<void> _selectPrediction({
    required String placeId,
    required String description,
  }) async {
    // 🔒 evita doble tap
    if (_navigatingAfterPick) return;
    _navigatingAfterPick = true;

    try {
      // 1) Trae details (mientras el bottomsheet sigue abierto)
      final res = await _functions.httpsCallable('placeDetails').call({
        'placeId': placeId,
      });

      final data = Map<String, dynamic>.from(res.data);
      if (data['ok'] != true) return;

      final address = (data['formattedAddress'] ?? description).toString();
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final latLng = LatLng(lat, lng);

      if (!mounted) return;

      // 2) Actualiza estado
      setState(() {
        _textController.text = address;
        _controller.to = address;
        _controller.tolatlng = latLng;
        _predictions = [];
        _loadingPreds = false;
      });

      await _guardarEnHistorial(address);

      // 3) ✅ AHORA sí cerramos el bottomsheet
      // (usa rootNavigator true para asegurarte de cerrar el sheet aunque estés dentro del builder)
      Navigator.of(context, rootNavigator: true).pop();

      // 4) ✅ Dispara tu flujo normal
      // (si requestDriver navega, ya no verás el mapa “solo” porque el pop y el request van pegados)
      _controller.requestDriver();
    } catch (e) {
      if (kDebugMode) print('selectPrediction error: $e');
    } finally {
      _navigatingAfterPick = false;
    }
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
        margin: EdgeInsets.only(bottom: 15.r, top: 10.r),
        child: searchHistory.isEmpty
            ? Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 20.r), // Ajusta el padding según sea necesario
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 60.r, color: negroLetras), // Icono para indicar que no hay historial
                SizedBox(height: 10.r),
                Text(
                  "Aún no tienes un historial de viajes recientes.",
                  style: TextStyle(fontSize: 14.r, color: negro),
                ),
              ],
            ),
          ),
        )
            : SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: searchHistory
                .map((historyItem) => GestureDetector(
              onTap: () async {
                String selectedAddress = historyItem;
                CustomLoadingDialog.show(context); // Mostrar el diálogo de carga
                _textController.text = historyItem;
                LatLng? selectedLatLng = await getLatLngFromAddress(selectedAddress);

                if (selectedLatLng != null) {
                  setState(() {
                    _controller.to = selectedAddress;
                    _controller.tolatlng = selectedLatLng;
                  });
                  if(context.mounted){
                    CustomLoadingDialog.hide(context);
                  }
                  _controller.requestDriver();
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 6.r, horizontal: 6.r),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.history, color: negroLetras, size: 16,),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        historyItem,
                        style: TextStyle(color: negro, fontSize: 10.r, fontWeight: FontWeight.w500),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _guardarEnHistorial(String searchTerm) async {
    if (!searchHistory.contains(searchTerm)) {
      // Limitar la cantidad de elementos en el historial a 3
      if (searchHistory.length >= 3) {
        setState(() {
          // Invertir el orden de la lista antes de agregar la búsqueda
          searchHistory = [searchTerm, ...searchHistory.sublist(0, 2)];
        });
      } else {
        setState(() {
          // Agregar la búsqueda al principio de la lista
          searchHistory.insert(0, searchTerm);
        });
      }
      // Obtener las coordenadas de la dirección seleccionada
      List<Location> locations = await locationFromAddress(searchTerm);
      if (locations.isNotEmpty) {
        setState(() {
          _controller.tolatlng = LatLng(locations[0].latitude, locations[0].longitude);
          _controller.to = searchTerm;  // Asegúrate de actualizar también la dirección
          refresh();
        });
      }
      onSelectAddress(searchTerm); // Llamar a onSelectAddress con la nueva búsqueda
    }
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
    setState(() {
      searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('search_history', searchHistory);
  }

}

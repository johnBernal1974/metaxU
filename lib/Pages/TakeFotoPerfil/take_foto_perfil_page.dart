import 'dart:io';
import 'package:apptaxis/Pages/TakeFotoPerfil/take_foto_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../helpers/conectivity_service.dart';
import '../../src/colors/colors.dart';

class TakeFotoPerfil extends StatefulWidget {
  const TakeFotoPerfil({super.key});

  @override
  State<TakeFotoPerfil> createState() => _TakeFotoPerfilState();
}

class _TakeFotoPerfilState extends State<TakeFotoPerfil> {

  late TakeFotoController _controller = TakeFotoController();
  File? imageFile;
  final double _radiusWithoutImage = 60;
  final double _radiusWithImage = 100;
  final ConnectionService connectionService = ConnectionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TakeFotoController();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context, refresh);
      _updateRadius();
    });
  }

  void _updateRadius() {
    setState(() {
      if (_controller.pickedFile != null) {
        _radiusWithoutImage;
        _radiusWithImage;
      }
    });
  }

  void refresh(){
    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Foto de perfil", style: TextStyle(
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
      body: Container(
        padding: const EdgeInsets.only(left: 25, right: 25),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _cajonFotoPerfil(),
              const SizedBox(height: 15),
              _instruccionesFoto(),
              const SizedBox(height: 15,),
              _botonTomarFoto(),
              const SizedBox(height: 10),
              _continuarButton()
            ],
          ),
        ),
      ),

    );
  }

  Widget _cajonFotoPerfil() {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(5),
      // Aplicar un borde al CircleAvatar cuando no hay una imagen cargada
      decoration: _controller.pickedFile == null ? BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:primary, // Color del borde
          width: 1.0, // Ancho del borde
        ),
      ) : null,
      child: CircleAvatar(
        backgroundColor: blancoCards,
        radius: _controller.pickedFile != null ? _radiusWithImage : _radiusWithoutImage,
        child: ClipOval(
          child: Stack(
            children: [
              if (_controller.pickedFile != null)
                Positioned.fill(
                  child: Image.file(
                    File(_controller.pickedFile!.path),
                    fit: BoxFit.cover,
                  ),
                ),
              if (_controller.pickedFile == null || _controller.pickedFile?.name == 'asd')
                Positioned.fill(
                  child: Image.asset(
                    "assets/icono_persona.png",
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
        ),
      ), // Si hay una imagen cargada, no aplicar ningún borde
    );
  }

  Widget _botonTomarFoto() {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      child: ElevatedButton(
        onPressed: () {
          _controller.takePicture();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, // Color del botón
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, color: blanco, size: 16,), // Icono de cámara
            SizedBox(width: 8), // Espacio entre el icono y el texto
            Text(
              'Tomar Foto',
              style: TextStyle(fontSize: 16, color: blanco),
            ),
          ],
        ),
      ),
    );
  }

  Widget _continuarButton() {
    // Verifica si se ha tomado y cargado una foto
    bool hasPhoto = _controller.pickedFile != null;
    return Visibility(
      visible: hasPhoto,
      child: ElevatedButton(
        onPressed: () {
          // Verificar conexión a Internet antes de ejecutar la acción
          connectionService.hasInternetConnection().then((hasConnection) {
            if (hasConnection) {
              _controller.guardarFotoPerfil();
            } else {
              // Llama a alertSinInternet inmediatamente si no hay conexión
              alertSinInternet();
            }
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: azulOscuro, // Color del botón
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload, color: blanco, size: 16,),
            SizedBox(width: 12),
            Text(
              'Subir foto',
              style: TextStyle(fontSize: 16, color: blanco),
            ),
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

  Widget _instruccionesFoto(){
    return const Text('Por favor toma una selfie donde se pueda observar perfectamente toda tu cabeza y parte de los hombros. Verifica que no la tomes a contra luz.',
      style: TextStyle(
          fontSize: 14,
          color: Colors.black,
          height: 1
      ),);
  }

}

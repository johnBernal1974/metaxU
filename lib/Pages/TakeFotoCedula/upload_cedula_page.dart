
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../src/colors/colors.dart';
import '../../helpers/conectivity_service.dart';
import 'take_cedula_controller.dart';

class UploadCedulaPage extends StatefulWidget {
  const UploadCedulaPage({super.key});

  @override
  State<UploadCedulaPage> createState() => _UploadCedulaPageState();
}

class _UploadCedulaPageState extends State<UploadCedulaPage> {
  late TakeCedulaController _controller;
  final ConnectionService connectionService = ConnectionService();
  String tipoCedula = 'ambas'; // frontal | reverso | ambas

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    tipoCedula = (args?['tipo'] ?? 'ambas').toString();
  }



  @override
  void initState() {
    super.initState();
    _controller = TakeCedulaController();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context, refresh);
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // ✅ condición para habilitar botón según tipo
    final bool puedeSubir = (tipoCedula == 'ambas')
        ? _controller.hasBoth
        : (tipoCedula == 'frontal')
        ? (_controller.frontFile != null)
        : (_controller.backFile != null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text(
          "Cédula",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: const <Widget>[
          Image(
            height: 40.0,
            width: 100.0,
            image: AssetImage('assets/metax_logo.png'),
          )
        ],
      ),
      body: Container(
        padding: const EdgeInsets.only(left: 25, right: 25),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 15),
              const Column(
                children: [
                  Icon(Icons.verified_user, size: 48, color: primary),
                  SizedBox(height: 12),
                  Text(
                    'Más seguridad para todos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Verificar tu cédula nos permite proteger tu cuenta, evitar suplantaciones '
                        'y garantizar viajes más seguros para conductores y pasajeros.\n\n'
                        'Tus documentos se usan únicamente para validación interna y '
                        'no se comparten con terceros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 🔐 micro-sello + botón info
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.green.withOpacity(0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          'Información protegida y cifrada',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showInfoSheet,
                    child: const Text(
                      '¿Por qué te pedimos esto?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ✅ SOLO muestra FRONTAL si aplica
              if (tipoCedula == 'frontal' || tipoCedula == 'ambas')
                _cardFoto(
                  titulo: 'Frontal de la cédula',
                  file: _controller.frontFile,
                  onTap: _controller.takeFront,
                ),

              // ✅ espacio SOLO si también va reverso
              if (tipoCedula == 'ambas') const SizedBox(height: 14),

              // ✅ SOLO muestra REVERSO si aplica
              if (tipoCedula == 'reverso' || tipoCedula == 'ambas')
                _cardFoto(
                  titulo: 'Reverso de la cédula',
                  file: _controller.backFile,
                  onTap: _controller.takeBack,
                ),

              const SizedBox(height: 18),

              // ✅ Botón subir según tipo
              Visibility(
                visible: puedeSubir,
                child: ElevatedButton(
                  onPressed: () async {
                    final hasConnection = await connectionService.hasInternetConnection();
                    if (!hasConnection) {
                      _alertSinInternet();
                      return;
                    }

                    // ✅ IMPORTANTE: aquí debe recibir tipo (paso siguiente en controller)
                    await _controller.guardarCedula(tipo: tipoCedula);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: azulOscuro),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload, color: blanco, size: 16),
                      SizedBox(width: 12),
                      Text('Subir cédula', style: TextStyle(fontSize: 16, color: blanco)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }


  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ permite usar más altura
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return const SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Icon(Icons.security, size: 40, color: Colors.black87),
                ),
                SizedBox(height: 10),
                Center(
                  child: Text(
                    'Verificación de identidad',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(height: 14),

                Text('¿Quién revisa?', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  'Nuestro equipo de verificación revisa las fotos únicamente para confirmar '
                      'que la identidad coincide con la cuenta.',
                  style: TextStyle(color: Colors.black54, height: 1.25),
                ),
                SizedBox(height: 12),

                Text('¿Cuánto tarda?', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  'Normalmente toma pocos minutos. En horas de alta demanda puede tardar un poco más.',
                  style: TextStyle(color: Colors.black54, height: 1.25),
                ),
                SizedBox(height: 12),

                Text('¿Qué pasa si no la subes?', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  'Puedes explorar la app, pero para continuar con nuevas solicitudes (por seguridad) '
                      'te pediremos completar este paso.',
                  style: TextStyle(color: Colors.black54, height: 1.25),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _cardFoto({
    required String titulo,
    required File? file,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blancoCards,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: file == null
                ? const Center(child: Text('Aún no has tomado esta foto'))
                : ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              icon: const Icon(Icons.camera_alt, color: blanco, size: 16),
              label: const Text('Tomar foto', style: TextStyle(color: blanco)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _alertSinInternet() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sin Internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        content: const Text('Por favor, verifica tu conexión e inténtalo nuevamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Aceptar')),
        ],
      ),
    );
  }
}

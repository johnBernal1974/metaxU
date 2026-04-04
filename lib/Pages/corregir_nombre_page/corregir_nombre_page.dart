import 'package:flutter/material.dart';
import '../../providers/client_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CorregirNombrePage extends StatefulWidget {
  const CorregirNombrePage({super.key});

  @override
  State<CorregirNombrePage> createState() => _CorregirNombrePageState();
}

class _CorregirNombrePageState extends State<CorregirNombrePage> {

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController apellidoController = TextEditingController();

  bool isLoading = false;

  bool validarNombre(String nombre, String apellido) {
    final regex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$');

    if (nombre.trim().length < 3 || apellido.trim().length < 3) {
      return false;
    }

    if (!regex.hasMatch(nombre) || !regex.hasMatch(apellido)) {
      return false;
    }

    return true;
  }

  void guardar() async {
    final nombre = nombreController.text.trim();
    final apellido = apellidoController.text.trim();

    if (!validarNombre(nombre, apellido)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre válido')),
      );
      return;
    }

    setState(() => isLoading = true);

    final clientProvider = ClientProvider();
    final authProvider = MyAuthProvider();

    final user = authProvider.getUser();

    if (user != null) {
      await clientProvider.update({
        '01_Nombres': nombre,
        '02_Apellidos': apellido,

        // 🔥 CLAVE (nuevo sistema)
        'nombre_estado': 'corregida',

        // 🔒 vuelve a revisión
        'status': 'procesando',
      }, user.uid);
    }

    setState(() => isLoading = false);

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        'verificacion_pendiente', // 🔥 NO al mapa
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Corrige tu nombre")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            const Text(
              "Debes ingresar tu nombre real para continuar",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            TextField(
              textCapitalization: TextCapitalization.words,
              controller: nombreController,
              decoration: const InputDecoration(labelText: "Nombres"),
            ),

            const SizedBox(height: 10),

            TextField(
              textCapitalization: TextCapitalization.words,
              controller: apellidoController,
              decoration: const InputDecoration(labelText: "Apellidos"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isLoading ? null : guardar,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }
}
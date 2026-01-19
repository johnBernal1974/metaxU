import 'dart:io';
import 'package:apptaxis/src/colors/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AfterCalificationPage extends StatelessWidget {
  const AfterCalificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primary,
          title: const Text('Viaje finalizado', style: TextStyle(fontWeight: FontWeight.w700)),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Image(
                  height: 100.0,
                  width: 200.0,
                  image: AssetImage('assets/metax_logo.png')),
              const Icon(Icons.star, size: 60, color: primary),
              const SizedBox(height: 12),
              const Text(
                '¡Gracias por calificar!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Deseas solicitar otro viaje o salir?',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ✅ Botón: Solicitar otro viaje
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_taxi),
                  label: const Text('Solicitar otro viaje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black, // color del texto e ícono
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      'map_client',
                          (route) => false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ✅ Botón: Salir
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.exit_to_app, color: Colors.black),
                  label: const Text('Salir', style: TextStyle(color: Colors.black)),
                  onPressed: () async {
                    await SystemNavigator.pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';

class ContactoPorteriaPage extends StatelessWidget {
  const ContactoPorteriaPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Contacto"),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [

            Text(
              "Soporte METAX",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 20),

            ListTile(
              leading: Icon(Icons.phone),
              title: Text("Llamar soporte"),
              subtitle: Text("+57 300 0000000"),
            ),

            ListTile(
              leading: Icon(Icons.email),
              title: Text("Correo"),
              subtitle: Text("soporte@metax.com"),
            ),

            ListTile(
              leading: Icon(Icons.chat),
              title: Text("WhatsApp"),
              subtitle: Text("Chat de soporte"),
            ),

          ],
        ),
      ),
    );
  }
}
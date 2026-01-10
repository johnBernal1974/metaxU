
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/client_provider.dart';
import '../../helpers/header_text.dart';
import '../../models/price.dart';
import '../../providers/price_provider.dart';
import '../../src/colors/colors.dart';
import 'package:apptaxis/models/client.dart';

class PaginaDeBloqueo extends StatefulWidget {
  const PaginaDeBloqueo({super.key});


  @override
  State<PaginaDeBloqueo> createState() => _PaginaDeBloqueoState();
}


class _PaginaDeBloqueoState extends State<PaginaDeBloqueo> {

  late MyAuthProvider _authProvider;
  late ClientProvider  _clientProvider ;
  late PricesProvider _pricesProvider;
  String? whatsappAtencionCliente;
  String? celularAtencionCliente;

  @override
  void initState() {
    super.initState();
    _authProvider = MyAuthProvider();
    _clientProvider = ClientProvider();
    _pricesProvider = PricesProvider();
    obtenerDatosPrice();
  }


  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent)

    );
    return  Scaffold(
      backgroundColor: blancoCards,
      appBar: AppBar(
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Usuario bloqueado", style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16
        ),),
        actions: const <Widget>[
          Image(
              height: 40.0,
              width: 100.0,
              image: AssetImage('assets/metax_logo.png'))
        ],
      ),
      body:
          Container(
            margin: const EdgeInsets.only(top: 60, right: 15),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Column(
                      children: [
                        headerText(
                            text: 'Tu usuario se encuentra temporalmente',
                            fontSize: 16,
                            color: negroLetras,
                            fontWeight: FontWeight.w400
                        ),
                        headerText(
                            text: 'BLOQUEADO',
                            fontSize: 20,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.block, color: Colors.redAccent, size: 60),

                  Container(
                    margin: const EdgeInsets.only(left: 20, right: 20),
                    padding: const EdgeInsets.all(10),
                    child: headerText(
                        text: 'Si deseas tener más detalles al respecto comunicate con nosotros por cualquiera de nuestros canales de información.',
                        fontSize: 14,
                        color: negroLetras,
                        fontWeight: FontWeight.w400,
                        textAling: TextAlign.justify
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 50, right: 50, top: 25,bottom: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            IconButton(
                              onPressed: (){
                                makePhoneCall(whatsappAtencionCliente ?? "");
                              },
                              icon: const Icon(Icons.phone),
                              iconSize: 30,),

                            headerText(
                                text: "Llámanos",
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: negroLetras
                            ),
                          ],
                        ),


                        Column(
                          children: [
                            IconButton(
                              onPressed: (){
                                _openWhatsApp(context);
                              },
                              icon: Image.asset('assets/icono_whatsapp.png',
                                  width: 30,
                                  height: 30),
                            ),

                            headerText(
                                text: "Chatea",
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: negroLetras
                            ),
                          ],
                        )
                      ],
                    ),

                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _openWhatsApp(BuildContext context) async {
    String userId = _authProvider.getUser()!.uid;

    // Obtener el conductor actualizado
    Client? client = await _clientProvider.getById(userId);
    String? phoneNumber = whatsappAtencionCliente;
    String? name = client?.the01Nombres;
    String message = 'Hola Metax, mi nombre es $name. Requiero saber el motivo del bloqueo de mi cuenta.';

    final whatsappLink = Uri.parse('whatsapp://send?phone=+57$phoneNumber&text=${Uri.encodeQueryComponent(message)}');

    try {
      await launchUrl(whatsappLink);
    } catch (e) {
      if(context.mounted){
        showNoWhatsAppInstalledDialog(context);
      }
    }
  }

  void showNoWhatsAppInstalledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('WhatsApp no instalado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          content: const Text('No tienes WhatsApp en tu dispositivo. Instálalo e intenta de nuevo'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Aceptar', style: TextStyle(color: negro, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  void makePhoneCall(String phoneNumber) async {
    final phoneCallUrl = 'tel:$phoneNumber';
    try {
      await launch(phoneCallUrl);
    } catch (e) {
      if (kDebugMode) {
        print('No se pudo realizar la llamada: $e');
      }
    }
  }

  void obtenerDatosPrice() async {
    try {
      Price price = await _pricesProvider.getAll();
      // Convertir a double explícitamente si es necesario
      whatsappAtencionCliente = price.theCelularAtencionUsuarios;
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo los datos: $e');
      }
    }
  }
}

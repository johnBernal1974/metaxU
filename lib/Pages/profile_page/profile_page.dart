import 'package:apptaxis/Pages/profile_page/profileController/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../helpers/header_text.dart';
import '../../src/colors/colors.dart';



class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  final ProfileController _controller = ProfileController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context, refresh);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blancoCards,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 30),
        title: const Text("Mis datos", style: TextStyle(
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

      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fotoPerfil(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'Viajes realizados',
                          style: TextStyle(color: primary, fontSize: 12),
                          textAlign: TextAlign.center, // Asegúrate de centrar el texto también
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _controller.client?.the19Viajes.toString() ?? 'hola',
                        style: const TextStyle(color: negro, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center, // Asegúrate de centrar el texto
                      ),
                      const SizedBox(height: 25),
                      const Divider(height: 1, color: grisMedio),
                      const SizedBox(height: 5),
                    ],
                  ),

                ],
              ),
              _textSubtitledatosPersonales(),
              const Divider(height: 1, color: grisMedio),
              const SizedBox(height: 5),
              _nombres(),
              _apellidos(),
              _email(),
              _celular(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fotoPerfil(){
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(bottom: 15),
      child: CircleAvatar(
        backgroundColor: blanco,
        backgroundImage: _controller.client?.image != null
            ? CachedNetworkImageProvider(_controller.client!.image)
            : null,
        radius: 80,
      ),
    );
  }
  Widget _nombres(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        headerText( text: 'Nombre:' , color: gris, fontSize: 14,fontWeight: FontWeight.w500),
        const SizedBox(width: 5),
        headerText( text: _controller.client?.the01Nombres ?? "", color: negro,fontSize: 14,fontWeight: FontWeight.w700),
      ],
    );
  }

  Widget _apellidos(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        headerText( text: 'Apellidos:' , color: gris, fontSize: 14,fontWeight: FontWeight.w500),
        const SizedBox(width: 5),
        headerText( text: _controller.client?.the02Apellidos ?? "", color: negro,fontSize: 14,fontWeight: FontWeight.w700),
      ],
    );
  }


  Widget _email(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        headerText( text: 'Email:' , color: gris, fontSize: 14,fontWeight: FontWeight.w500),
        const SizedBox(width: 5),
        headerText( text: _controller.client?.the06Email ?? '', color: negro,fontSize: 14,fontWeight: FontWeight.w700),
      ],
    );
  }

  Widget _celular(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        headerText( text: 'Celular:' , color: gris, fontSize: 14,fontWeight: FontWeight.w500),
        const SizedBox(width: 5),
        headerText( text: _controller.client?.the07Celular ?? '', color: negro,fontSize: 14,fontWeight: FontWeight.w700),
      ],
    );
  }

  void refresh(){
    setState(() {

    });
  }
}

Widget _textSubtitledatosPersonales(){
  return const Text('Datos personales', style: TextStyle(
    color: negro, fontSize: 20, fontWeight: FontWeight.w900
      ));
}


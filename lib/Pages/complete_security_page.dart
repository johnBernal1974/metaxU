import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../src/colors/colors.dart';

class CompleteSecurityPage extends StatefulWidget {
  const CompleteSecurityPage({Key? key}) : super(key: key);

  @override
  State<CompleteSecurityPage> createState() => _CompleteSecurityPageState();
}

class _CompleteSecurityPageState extends State<CompleteSecurityPage> {
  final MyAuthProvider _authProvider = MyAuthProvider();

  final List<String> questions = const [
    'Nombre de tu mascota',
    'Nombre de tu abuelo materno',
    '¿Cuál es el nombre de tu profesor favorito?',
  ];

  String? selectedQuestion;
  final TextEditingController answerController = TextEditingController();

  String? questionError;
  String? answerError;
  bool saving = false;

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      questionError = null;
      answerError = null;

      if (selectedQuestion == null) {
        questionError = 'Debes seleccionar una pregunta.';
      }

      if (answerController.text.trim().isEmpty) {
        answerError = 'Debes escribir tu respuesta.';
      }
    });

    if (questionError != null || answerError != null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('Clients')
          .doc(user.uid)
          .set({
        'pregunta_palabra_clave': selectedQuestion,
        'palabra_clave': answerController.text.trim(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      // ✅ salir de esta pantalla y dejar que el flujo normal se ejecute
      Navigator.pushNamedAndRemoveUntil(context, 'map_client', (route) => false);

    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta nuevamente.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blancoCards,
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: negro, size: 24),
        title: const Text(
          'Completa tu verificación',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: const <Widget>[
          Image(
            height: 40.0,
            width: 90.0,
            image: AssetImage('assets/metax_logo.png'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verificación de identidad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Para proteger tu cuenta, selecciona una pregunta y escribe tu respuesta.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 18),

            // ✅ Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedQuestion,
                  hint: const Text('Selecciona una pregunta'),
                  items: questions.map((q) {
                    return DropdownMenuItem<String>(
                      value: q,
                      child: Text(
                        q,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: saving
                      ? null
                      : (v) => setState(() => selectedQuestion = v),
                ),
              ),
            ),
            if (questionError != null) ...[
              const SizedBox(height: 6),
              Text(questionError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 14),

            // ✅ Respuesta
            TextField(
              controller: answerController,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: 'Tu respuesta',
                errorText: answerError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
                    : const Text(
                  'Guardar y continuar',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';

Future<void> checkPhoneRoleBeforeOtp({
  required String cel10,
  required String targetRole, // "driver" | "client"
  required String action,     // "login" | "signup"
}) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'checkPhoneRole',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
    );

    final res = await callable.call({
      'cel10': cel10,
      'targetRole': targetRole,
      'action': action,
    });

    // ✅ parse seguro
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Respuesta inválida del servidor. Intenta nuevamente.');
    }

    final data = Map<String, dynamic>.from(raw as Map);

    final allowed = data['allowed'] == true;
    if (!allowed) {
      final msg = (data['message'] ?? 'No se puede usar este número.').toString();
      throw Exception(msg);
    }
  } on FirebaseFunctionsException catch (e) {
    // errores típicos: unavailable, deadline-exceeded, invalid-argument, internal...
    final code = e.code;
    final msg = e.message ?? 'No se pudo validar el número. Intenta nuevamente.';

    // Mensajes más humanos
    if (code == 'unavailable' || code == 'deadline-exceeded') {
      throw Exception('No pudimos validar el número por conexión. Intenta de nuevo.');
    }
    throw Exception(msg);
  } catch (_) {
    throw Exception('No se pudo validar el número. Intenta nuevamente.');
  }
}
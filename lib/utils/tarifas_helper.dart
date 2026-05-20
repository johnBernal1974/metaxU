double calcularRecargos({
  required DateTime fecha,
  required bool esAeropuerto,
  required bool esYellowWoman,
  required bool esFestivo,
}) {

  double totalRecargos = 0;

  /// 🌙 RECARGO NOCTURNO
  final hora = fecha.hour;

  final esNocturno = hora >= 19 || hora < 6;

  if (esNocturno) {
    totalRecargos += 1100;
  }

  /// 📅 DOMINGO O FESTIVO
  final esDomingo = fecha.weekday == DateTime.sunday;

  if (esDomingo || esFestivo) {
    totalRecargos += 1100;
  }

  /// ✈️ RECARGO AEROPUERTO
  if (esAeropuerto) {
    totalRecargos += 3000;
  }

  /// 💛 YELLOW WOMAN
  if (esYellowWoman) {
    totalRecargos += 4000;
  }

  return totalRecargos;
}
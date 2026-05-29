import 'package:intl/intl.dart';

/// Formateador de números para cantidades monetarias y generales.
/// Usa separadores de miles (coma) y 2 decimales.
///
/// Ejemplo: 1234567.89 → "1,234,567.89"
final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

/// Formatea un número como moneda con separadores de miles.
/// [value] es el número a formatear.
/// Retorna un String con formato: "1,234,567.89"
String formatCurrency(num value) {
  return _currencyFormat.format(value);
}

/// Formatea un número como cantidad con separadores de miles y 2 decimales.
/// Útil para cantidades que no son moneda (ej: metros, unidades).
String formatQuantity(num value) {
  return _currencyFormat.format(value);
}

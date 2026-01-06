import 'package:intl/intl.dart';

class CurrencyUtils {
  static final NumberFormat _mtNumberFormat = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _mtCompactFormat =
      NumberFormat.compact(locale: 'en_US');
  static final NumberFormat _mtNoDecimalsFormat =
      NumberFormat('#,##0', 'en_US');

  /// Formata valores monetários em MT no padrão:
  /// 2500 -> "2 500.00 MT"
  static String formatMt(num value) {
    final formatted = _mtNumberFormat.format(value);
    // Substitui separador de milhares por espaço: 2,500.00 -> 2 500.00
    return formatted.replaceAll(',', ' ') + ' MT';
  }

  /// Formata valores monetários sem o sufixo da moeda:
  /// 2500 -> "2 500.00"
  static String formatMtPlain(num value) {
    final formatted = _mtNumberFormat.format(value);
    return formatted.replaceAll(',', ' ');
  }

  /// Formata valores monetários em MT sem casas decimais:
  /// 2500 -> "2 500 MT"
  static String formatMtNoDecimals(num value) {
    final formatted = _mtNoDecimalsFormat.format(value);
    return formatted.replaceAll(',', ' ') + ' MT';
  }

  /// Formata apenas o número, sem casas decimais nem sufixo:
  /// 2500 -> "2 500"
  static String formatMtPlainNoDecimals(num value) {
    final formatted = _mtNoDecimalsFormat.format(value);
    return formatted.replaceAll(',', ' ');
  }

  /// Formata valores em MT de forma compacta para caber em espaços menores:
  /// 2 500 -> "2.5K MT", 12 000 -> "12K MT".
  static String formatMtCompact(num value) {
    final compact = _mtCompactFormat.format(value);
    return '$compact MT';
  }
}

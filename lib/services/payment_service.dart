import '../models/mpesa_number_model.dart';

class PaymentService {
  static final List<MpesaNumber> _numbers = [];

  static List<MpesaNumber> get numbers => _numbers;

  // ➕ Adicionar número
  static void addNumber(String number) {
    final isFirst = _numbers.isEmpty;

    _numbers.add(
      MpesaNumber(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        number: number,
        isPrimary: isFirst, // 👈 primeiro vira principal
      ),
    );
  }

  // ⭐ Definir principal
  static void setPrimary(String id) {
    for (var n in _numbers) {
      n.isPrimary = n.id == id;
    }
  }

  // 🗑️ Remover número
  static void remove(String id) {
    _numbers.removeWhere((n) => n.id == id);

    // garante que sempre exista um principal
    if (_numbers.isNotEmpty && !_numbers.any((n) => n.isPrimary)) {
      _numbers.first.isPrimary = true;
    }
  }

  // 🔑 Número principal (usado no checkout)
  static MpesaNumber? get primary {
    try {
      return _numbers.firstWhere((n) => n.isPrimary);
    } catch (_) {
      return null;
    }
  }
}

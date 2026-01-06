import 'package:shared_preferences/shared_preferences.dart';

/// Preferências locais relacionadas ao chat (ex: opção padrão de apagar mensagem).
class ChatPreferencesService {
  static const _deletePreferenceKey = 'chat_delete_preference'; // 'me' ou 'both'
  static const _hiddenPrefix = 'chat_hidden_'; // + chatId -> List<String> messageIds

  /// Obtém a preferência de deleção de mensagem.
  /// Retorna 'me', 'both' ou null (sem preferência salva).
  static Future<String?> getDeletePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_deletePreferenceKey);
    if (value == 'me' || value == 'both') {
      return value;
    }
    return null;
  }

  /// Define a preferência de deleção de mensagem.
  /// [value] deve ser 'me' (só para mim) ou 'both' (para os dois).
  static Future<void> setDeletePreference(String value) async {
    if (value != 'me' && value != 'both') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deletePreferenceKey, value);
  }

  /// Limpa a preferência salva.
  static Future<void> clearDeletePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deletePreferenceKey);
  }

  /// Retorna o conjunto de IDs de mensagens escondidas "só para mim"
  /// para um determinado chat. Persistido localmente no dispositivo.
  static Future<Set<String>> getHiddenMessagesForChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_hiddenPrefix$chatId') ?? const [];
    return list.toSet();
  }

  /// Marca uma mensagem como escondida "só para mim" neste dispositivo.
  static Future<void> hideMessageForChat(
    String chatId,
    String messageId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_hiddenPrefix$chatId';
    final list = prefs.getStringList(key) ?? <String>[];
    if (!list.contains(messageId)) {
      list.add(messageId);
      await prefs.setStringList(key, list);
    }
  }
}

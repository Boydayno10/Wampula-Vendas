import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatsPage extends StatefulWidget {
  final String? initialChatId;

  const ChatsPage({super.key, this.initialChatId});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage>
    with SingleTickerProviderStateMixin {
  bool _loadingChats = true;
  bool _loadingMessages = false;
  String? _error;
  List<Map<String, dynamic>> _chats = const [];
  List<Map<String, dynamic>> _messagesForSelectedChat = const [];
  Map<String, String> _userNames = const {}; // userId -> name/email
  String? _selectedChatId;
  String _search = '';
  final TextEditingController _composerController = TextEditingController();
  Map<String, dynamic>? _replyingToMessage;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _messagesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _loadingChats = true;
      _error = null;
    });

    final supabase = Supabase.instance.client;
    try {
      final data = await supabase
          .from('chats')
          .select()
          .order('created_at', ascending: false);

      final chats = (data as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      // Monta mapa de nomes a partir de profiles
      final userIds = <String>{};
      for (final c in chats) {
        final u1 = c['user1_id'];
        final u2 = c['user2_id'];
        if (u1 is String) userIds.add(u1);
        if (u2 is String) userIds.add(u2);
      }

      Map<String, String> namesMap = {};
      if (userIds.isNotEmpty) {
        final profilesData = await supabase
            .from('profiles')
            .select('id, name, email')
            .inFilter('id', userIds.toList());

        for (final row in profilesData as List) {
          final map = row as Map<String, dynamic>;
          final id = map['id'] as String;
          final name = (map['name'] as String?)?.trim();
          final email = (map['email'] as String?)?.trim();
          namesMap[id] = (name != null && name.isNotEmpty)
              ? name
              : (email ?? id.substring(0, 8));
        }
      }

      setState(() {
        _chats = chats;
        _userNames = namesMap;
        _loadingChats = false;
        String? selected = _selectedChatId;
        if (selected == null) {
          final initial = widget.initialChatId;
          if (initial != null &&
              chats.any((c) => c['id'] == initial)) {
            selected = initial;
          } else if (chats.isNotEmpty) {
            selected = chats.first['id'] as String?;
          }
        }
        _selectedChatId = selected;
      });

      if (_selectedChatId != null) {
        await _loadMessagesForChat(_selectedChatId!);
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar chats: $e';
        _loadingChats = false;
      });
    }
  }

  Future<void> _loadMessagesForChat(String chatId) async {
    setState(() {
      _loadingMessages = true;
      _error = null;
    });

    // Cancelar qualquer inscrição anterior antes de ouvir um novo chat
    await _messagesSub?.cancel();

    final supabase = Supabase.instance.client;
    try {
      final stream = supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      _messagesSub = stream.listen(
        (data) {
          if (!mounted) return;
          setState(() {
            _messagesForSelectedChat =
                data.cast<Map<String, dynamic>>();
            _loadingMessages = false;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Erro ao carregar mensagens: $e';
            _loadingMessages = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao configurar stream de mensagens: $e';
        _loadingMessages = false;
      });
    }
  }

  Future<void> _markMessageRead(Map<String, dynamic> message) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('chat_messages').update({
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', message['id']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar como lida: $e')),
      );
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar mensagem'),
        content: Text('Apagar esta mensagem definitivamente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      // Em vez de apagar definitivamente, marcamos como apagada,
      // para que os participantes vejam o aviso na conversa.
      await supabase.from('chat_messages').update({
        'message': 'Essa mensagem foi apagada pelo Admin.',
        'image_url': null,
      }).eq('id', message['id']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar mensagem: $e')),
      );
    }
  }

  Future<void> _deleteChat(Map<String, dynamic> chat) async {
    final chatId = chat['id'] as String?;
    if (chatId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar chat'),
        content: const Text(
          'Apagar este chat e todo o histórico de mensagens? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar chat'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = Supabase.instance.client;
    try {
      // Remove todas as mensagens do chat primeiro
      await supabase
          .from('chat_messages')
          .delete()
          .eq('chat_id', chatId);

      // Depois remove o registro do chat
      await supabase.from('chats').delete().eq('id', chatId);

      if (!mounted) return;

      setState(() {
        if (_selectedChatId == chatId) {
          _selectedChatId = null;
          _messagesForSelectedChat = const [];
          _messagesSub?.cancel();
        }
      });

      await _loadChats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar chat: $e')),
      );
    }
  }

  void _setReplyTo(Map<String, dynamic> message) {
    setState(() {
      _replyingToMessage = message;
    });
  }

  Future<void> _sendMessage() async {
    final chatId = _selectedChatId;
    final text = _composerController.text.trim();
    if (chatId == null || text.isEmpty) return;

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão expirada, faça login novamente.')),
      );
      return;
    }

    String? replyToMessageId;
    if (_replyingToMessage != null) {
      replyToMessageId = _replyingToMessage!['id'] as String?;
    }

    try {
      await supabase.from('chat_messages').insert({
        'chat_id': chatId,
        'sender_id': currentUser.id,
        'message': text,
        'is_admin_message': true,
        if (replyToMessageId != null)
          'reply_to_message_id': replyToMessageId,
      });

      _composerController.clear();
      setState(() {
        _replyingToMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar mensagem: $e')),
      );
    }
  }

  Future<void> _openAttachmentsMenu() async {
    final chatId = _selectedChatId;
    if (chatId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um chat antes de enviar anexos.')),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão expirada, faça login novamente.')),
      );
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Foto (URL)'),
                subtitle: const Text('Enviar uma imagem a partir de uma URL pública'),
                onTap: () => Navigator.pop(context, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Pedidos'),
                subtitle: const Text('Anexar informações de um pedido ao chat'),
                onTap: () => Navigator.pop(context, 'order'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    String? replyToMessageId;
    if (_replyingToMessage != null) {
      replyToMessageId = _replyingToMessage!['id'] as String?;
    }

    try {
      if (choice == 'photo') {
        final urlController = TextEditingController();
        final captionController = TextEditingController();

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enviar foto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL da imagem',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(
                    labelText: 'Legenda (opcional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enviar'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final imageUrl = urlController.text.trim();
          final caption = captionController.text.trim();
          if (imageUrl.isEmpty) return;

          await supabase.from('chat_messages').insert({
            'chat_id': chatId,
            'sender_id': currentUser.id,
            'message': caption,
            'image_url': imageUrl,
            'is_admin_message': true,
            if (replyToMessageId != null)
              'reply_to_message_id': replyToMessageId,
          });

          if (!mounted) return;
          setState(() {
            _replyingToMessage = null;
          });
        }
      } else if (choice == 'order') {
        // Buscar pedidos e permitir a seleção de um para enviar
        final ordersData = await supabase
            .from('orders')
            .select('id,total,status,created_at')
            .order('created_at', ascending: false);

        final orders = (ordersData as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

        if (orders.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum pedido encontrado para anexar.')),
          );
          return;
        }

        final selectedOrder = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Selecionar pedido'),
            content: SizedBox(
              width: 480,
              height: 360,
              child: ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final o = orders[index];
                  final id = o['id'] as String;
                  final total = (o['total'] as num?)?.toStringAsFixed(2) ?? '0.00';
                  final status = (o['status'] as String?) ?? '-';
                  final createdAt = (o['created_at'] as String?) ?? '';

                  return ListTile(
                    title: Text('Pedido ${id.substring(0, 8)}'),
                    subtitle: Text('Total: $total · Status: $status\n$createdAt'),
                    onTap: () => Navigator.pop(context, o),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );

        if (selectedOrder != null) {
          final id = selectedOrder['id'] as String;
          final total = (selectedOrder['total'] as num?)?.toStringAsFixed(2) ?? '0.00';
          final status = (selectedOrder['status'] as String?) ?? '-';

          final text = 'Detalhes do seu pedido:\n'
              'ID: $id\n'
              'Total: $total\n'
              'Status: $status';

          await supabase.from('chat_messages').insert({
            'chat_id': chatId,
            'sender_id': currentUser.id,
            'message': text,
            'is_admin_message': true,
            if (replyToMessageId != null)
              'reply_to_message_id': replyToMessageId,
          });

          if (!mounted) return;
          setState(() {
            _replyingToMessage = null;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar anexo: $e')),
      );
    }
  }

  String? _extractImageUrl(Map<String, dynamic> message) {
    final possibleKeys = ['image_url', 'imageUrl', 'url'];

    for (final key in possibleKeys) {
      final value = message[key];
      if (value is String && value.isNotEmpty) {
        if (key != 'url') return value;

        final type = message['type'] ??
            message['content_type'] ??
            message['kind'];
        if (type is String && type.toLowerCase().contains('image')) {
          return value;
        }
      }
    }

    final text = (message['message'] as String? ?? '').trim();
    final urlRegex = RegExp(
      r'(https?://\S+\.(?:png|jpe?g|gif|webp))',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    if (match != null) return match.group(0);

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalChats = _chats.length;
    final totalMessages = _messagesForSelectedChat.length;

    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 800;

    final query = _search.toLowerCase();
    final filteredChats = _chats.where((c) {
      final u1 = c['user1_id'] as String?;
      final u2 = c['user2_id'] as String?;
      final name1 = u1 != null ? _userNames[u1] ?? u1 : '';
      final name2 = u2 != null ? _userNames[u2] ?? u2 : '';
      final text = '$name1 $name2 ${c['id']}';
      return query.isEmpty || text.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Chip(label: Text('Chats: $totalChats')),
            Chip(label: Text('Mensagens deste chat: $totalMessages')),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar por participantes ou ID do chat',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _search = value;
            });
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: isWide
              ? Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: _buildChatsList(theme, filteredChats),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMessagesView(theme)),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 280,
                      child: _buildChatsList(theme, filteredChats),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _buildMessagesView(theme)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildChatsList(
    ThemeData theme,
    List<Map<String, dynamic>> chats,
  ) {
    if (_loadingChats) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (chats.isEmpty) {
      return const Center(child: Text('Nenhum chat encontrado.'));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: RefreshIndicator(
        onRefresh: _loadChats,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final c = chats[index];
            final id = c['id'] as String;
            final user1Id = c['user1_id'] as String?;
            final user2Id = c['user2_id'] as String?;
            final name1 =
                user1Id != null ? _userNames[user1Id] ?? user1Id : 'Usuário 1';
            final name2 =
                user2Id != null ? _userNames[user2Id] ?? user2Id : 'Usuário 2';
            final createdAt = (c['created_at'] as String?) ?? '';

            final selected = id == _selectedChatId;

            return ListTile(
              selected: selected,
              leading: CircleAvatar(
                child: Text(name1.isNotEmpty ? name1[0].toUpperCase() : '?'),
              ),
              title: Text('$name1  •  $name2'),
              subtitle: Text(
                'Chat ${id.substring(0, 8)}  ·  $createdAt',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.redAccent,
                tooltip: 'Apagar chat',
                onPressed: () => _deleteChat(c),
              ),
              onTap: () async {
                setState(() {
                  _selectedChatId = id;
                });
                await _loadMessagesForChat(id);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessagesView(ThemeData theme) {
    if (_selectedChatId == null) {
      return const Center(
        child: Text('Selecione um chat para ver as mensagens.'),
      );
    }

    if (_loadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_messagesForSelectedChat.isEmpty) {
      return const Center(child: Text('Nenhuma mensagem neste chat.'));
    }

    final colorScheme = theme.colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Mensagens do chat ${_selectedChatId!.substring(0, 8)}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messagesForSelectedChat.length,
              itemBuilder: (context, index) {
                final m = _messagesForSelectedChat[index];
                final senderId = m['sender_id'] as String?;
                final senderName = senderId != null
                    ? _userNames[senderId] ?? senderId
                    : 'Remetente';
                final message = (m['message'] as String? ?? '').trim();
                final imageUrl = _extractImageUrl(m);
                final createdAt = (m['created_at'] as String?) ?? '';
                final readAt = (m['read_at'] as String?) ?? '';

                final isRead = readAt.isNotEmpty;
                final isAdminMessage =
                    currentUserId != null && senderId == currentUserId;
                final displayName = isAdminMessage ? 'Admin-WV' : senderName;

                Map<String, dynamic>? repliedMessage;
                final replyToId = m['reply_to_message_id'] as String?;
                if (replyToId != null) {
                  try {
                    repliedMessage = _messagesForSelectedChat
                        .firstWhere((mm) => mm['id'] == replyToId);
                  } catch (_) {
                    repliedMessage = null;
                  }
                }

                return GestureDetector(
                  onLongPress: () => _setReplyTo(m),
                  onHorizontalDragUpdate: (details) {
                    if (details.delta.dx > 8) {
                      _setReplyTo(m);
                    }
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isRead
                            ? colorScheme.surfaceVariant.withOpacity(0.6)
                            : colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isAdminMessage
                                      ? Colors.red
                                      : theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                              Text(
                                createdAt,
                                style:
                                    theme.textTheme.bodySmall?.copyWith(
                                  color: theme
                                      .textTheme.bodySmall?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (repliedMessage != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant
                                    .withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (() {
                                      final replySenderId =
                                          repliedMessage!['sender_id']
                                              as String?;
                                      if (replySenderId == null) {
                                        return 'Mensagem';
                                      }
                                      return _userNames[replySenderId] ??
                                          replySenderId.substring(0, 8);
                                    })(),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (() {
                                      final text =
                                          (repliedMessage!['message']
                                                      as String? ??
                                                  '')
                                              .trim();
                                      final replyImageUrl =
                                          _extractImageUrl(repliedMessage!);
                                      if (text.isEmpty &&
                                          replyImageUrl != null) {
                                        return 'Imagem';
                                      }
                                      return text.length > 60
                                          ? '${text.substring(0, 60)}…'
                                          : text;
                                    })(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (imageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                  maxHeight: 260,
                                ),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: colorScheme.surface,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        'Não foi possível carregar a imagem',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(message),
                            ],
                          ] else ...[
                            Text(message),
                          ],
                          if (isAdminMessage) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Admin-WV',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Colors.red,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              if (isRead)
                                Text(
                                  'Lida em: $readAt',
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: theme
                                        .textTheme.bodySmall?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 18,
                                    ),
                                    tooltip: 'Marcar como lida',
                                    onPressed: () => _markMessageRead(m),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    tooltip: 'Apagar',
                                    onPressed: () => _deleteMessage(m),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          if (_replyingToMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: colorScheme.surfaceVariant.withOpacity(0.6),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (() {
                        final senderId =
                            _replyingToMessage!['sender_id'] as String?;
                        final senderName = senderId != null
                            ? (_userNames[senderId] ??
                                senderId.substring(0, 8))
                            : 'Mensagem';
                        final text =
                            (_replyingToMessage!['message'] as String? ?? '')
                                .trim();
                        final imageUrl = _extractImageUrl(_replyingToMessage!);
                        String snippet;
                        if (text.isEmpty && imageUrl != null) {
                          snippet = 'Imagem';
                        } else {
                          snippet = text.length > 60
                              ? '${text.substring(0, 60)}…'
                              : text;
                        }
                        return 'Respondendo a $senderName: "$snippet"';
                      })(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Cancelar resposta',
                    onPressed: () {
                      setState(() {
                        _replyingToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Padding
            (
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _composerController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Escrever mensagem...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Anexos (foto / pedidos)',
                  onPressed: _openAttachmentsMenu,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send),
                  tooltip: 'Enviar',
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


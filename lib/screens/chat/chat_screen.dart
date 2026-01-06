import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/chat_preferences_service.dart';
import '../profile/view_profile_screen.dart';
import '../seller/seller_store_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String publicationName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.publicationName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  ChatMessageModel? _replyingTo;
  int _lastMessageCount = 0;
  String? _swipeMessageId;
  double _swipeOffset = 0;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightMessageId;
  final List<String> _pendingImagePaths = [];
  final Set<String> _hiddenMessageIds = {};
  ChatMessageModel? _editingMessage;
  final Map<String, UserModel?> _userCache = {};
  final Set<String> _loadingProfiles = {};

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Ao abrir o chat, marca notificações desse chat como lidas
    NotificationService.markChatAsRead(widget.chatId);

    // Ao abrir o chat, marca mensagens recebidas como lidas
    ChatService.markMessagesAsRead(widget.chatId);

    // Carrega mensagens escondidas "só para mim" neste dispositivo
    ChatPreferencesService.getHiddenMessagesForChat(widget.chatId).then((
      hidden,
    ) {
      if (!mounted) return;
      setState(() {
        _hiddenMessageIds
          ..clear()
          ..addAll(hidden);
      });
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    if (_sending) return;

    final text = _controller.text.trim();
    final hasImages = _pendingImagePaths.isNotEmpty;

    if (text.isEmpty && !hasImages) return;

    setState(() => _sending = true);

    try {
      if (!hasImages) {
        // Edição de mensagem existente (apenas texto)
        if (_editingMessage != null) {
          await ChatService.editMessage(
            messageId: _editingMessage!.id,
            newText: text,
          );
        } else {
          await ChatService.sendMessage(
            chatId: widget.chatId,
            text: text,
            replyToMessageId: _replyingTo?.id,
          );
        }
      } else {
        final paths = List<String>.from(_pendingImagePaths);

        for (var i = 0; i < paths.length; i++) {
          final path = paths[i];
          final imageUrl = await ChatService.uploadChatImage(path);

          await ChatService.sendMessage(
            chatId: widget.chatId,
            text: i == 0 ? text : '',
            imageUrl: imageUrl,
            replyToMessageId: i == 0 ? _replyingTo?.id : null,
          );
        }
      }

      _controller.clear();
      setState(() {
        _replyingTo = null;
        _editingMessage = null;
        _pendingImagePaths.clear();
      });

      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      if (_pendingImagePaths.length >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Máximo de 3 imagens por mensagem.')),
          );
        }
        return;
      }

      setState(() {
        _pendingImagePaths.add(image.path);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _openAttachmentMenu() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Câmera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_outlined,
                  label: 'Foto',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _ensureUserProfileLoaded(String userId) {
    if (userId.isEmpty || _userCache.containsKey(userId)) return;
    if (_loadingProfiles.contains(userId)) return;

    _loadingProfiles.add(userId);
    AuthService.fetchUserProfileById(userId).then((user) {
      if (!mounted) return;
      setState(() {
        _userCache[userId] = user;
        _loadingProfiles.remove(userId);
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _loadingProfiles.remove(userId);
      });
    });
  }

  Future<void> _onAvatarTap(String userId) async {
    if (userId.isEmpty) return;

    final currentUserId = AuthService.currentUser.id;

    UserModel? user;
    if (userId == currentUserId) {
      user = AuthService.currentUser;
    } else {
      user = _userCache[userId] ?? await AuthService.fetchUserProfileById(userId);
    }

    if (!mounted || user == null) return;
    final UserModel safeUser = user;
    // Se for o próprio usuário, abre o Meu perfil normalmente
    if (userId == currentUserId) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewProfileScreen(user: safeUser),
        ),
      );
      return;
    }

    // Se for outro usuário e ele for vendedor, abre a loja dele
    if (user.isSeller) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerStoreScreen(
            sellerId: safeUser.id,
            storeName: safeUser.storeName,
          ),
        ),
      );
      return;
    }

    // Caso contrário, abre o perfil normal do usuário
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(user: safeUser),
      ),
    );
  }

  Widget _buildAvatar(String userId) {
    final currentUserId = AuthService.currentUser.id;
    final isMe = userId == currentUserId;

    Widget buildAvatarForUser(UserModel? user) {
      final hasImage = user?.profileImageUrl != null &&
          user!.profileImageUrl!.isNotEmpty &&
          user.profileImageUrl!.startsWith('http');

      String initials = '';
      if (user != null && user.name.isNotEmpty) {
        initials = user.name.trim().isNotEmpty
            ? user.name.trim()[0].toUpperCase()
            : '';
      }

      return GestureDetector(
        onTap: () => _onAvatarTap(userId),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.deepPurple.shade50,
          backgroundImage:
              hasImage ? NetworkImage(user!.profileImageUrl!) : null,
          child: !hasImage
              ? (initials.isNotEmpty
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.deepPurple,
                    ))
              : null,
        ),
      );
    }

    if (isMe) {
      return ValueListenableBuilder<UserModel>(
        valueListenable: AuthService.currentUserNotifier,
        builder: (context, currentUser, _) {
          return buildAvatarForUser(currentUser);
        },
      );
    }

    _ensureUserProfileLoaded(userId);
    final otherUser = _userCache[userId];
    return buildAvatarForUser(otherUser);
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _onMessageLongPress(ChatMessageModel m, bool isMe) {
    showModalBottomSheet(
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
              if (isMe &&
                  (m.imageUrl == null || m.imageUrl!.isEmpty) &&
                  m.message.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar mensagem'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = m;
                      _replyingTo = null;
                      _controller.text = m.message;
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Apagar mensagem'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteMessageDialog(m);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteMessageDialog(ChatMessageModel m) async {
    final currentUserId = AuthService.currentUser.id;
    final isMe = m.senderId == currentUserId;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text('Apagar só para mim'),
                  subtitle: const Text(
                    'A outra pessoa continuará a ver esta mensagem.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _hiddenMessageIds.add(m.id);
                    });
                    ChatPreferencesService.hideMessageForChat(
                      widget.chatId,
                      m.id,
                    );
                  },
                ),
                if (isMe)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Apagar para os dois',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Remove a mensagem para você e para a outra pessoa.',
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await ChatService.deleteMessageForBoth(
                        messageId: m.id,
                        imageUrl: m.imageUrl,
                      );
                      // Some imediatamente para este usuário também
                      setState(() {
                        _hiddenMessageIds.add(m.id);
                      });
                      ChatPreferencesService.hideMessageForChat(
                        widget.chatId,
                        m.id,
                      );
                    },
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.currentUser.id;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          widget.publicationName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: ChatService.messagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMessages = snapshot.data ?? [];

                // Filtra mensagens "apagadas só para mim" nesta sessão
                final messages = allMessages
                    .where((m) => !_hiddenMessageIds.contains(m.id))
                    .toList();

                // Auto-scroll estilo WhatsApp (sempre no final)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (messages.length != _lastMessageCount) {
                    _lastMessageCount = messages.length;
                    _scrollToBottom();
                    // Sempre que chegar mensagem nova enquanto a tela estiver aberta,
                    // marca as recebidas como lidas e zera notificações desse chat
                    ChatService.markMessagesAsRead(widget.chatId);
                    NotificationService.markChatAsRead(widget.chatId);
                  }
                });

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Comece a conversa enviando uma mensagem.'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m.senderId == currentUserId;
                    final isAdmin = m.isAdminMessage && !isMe;
                    final isDeletedByAdmin =
                        m.message == 'Essa mensagem foi apagada pelo Admin.';

                    // Key única para permitir scroll até esta mensagem
                    final messageKey = _messageKeys[m.id] ??= GlobalKey();

                    // Mensagem de reply (se existir)
                    final repliedMessage = m.replyToMessageId == null
                        ? null
                        : messages.firstWhere(
                            (msg) => msg.id == m.replyToMessageId,
                            orElse: () => m,
                          );

                    final hasReplyImage =
                        repliedMessage != null &&
                        repliedMessage.imageUrl != null &&
                        repliedMessage.imageUrl!.isNotEmpty;

                    final radius = BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe || isAdmin
                          ? const Radius.circular(18)
                          : const Radius.circular(6),
                      bottomRight: isMe || isAdmin
                          ? const Radius.circular(6)
                          : const Radius.circular(18),
                    );

                    final isSwipingThis =
                        !isMe && _swipeMessageId == m.id && _swipeOffset > 0;

                    final isHighlighted = _highlightMessageId == m.id;

                    Border? bubbleBorder;
                    if (isHighlighted) {
                      bubbleBorder = Border.all(
                        color: Colors.deepPurple,
                        width: 2,
                      );
                    } else if (!isMe) {
                      bubbleBorder = Border.all(color: Colors.grey.shade300);
                    } else {
                      bubbleBorder = null;
                    }

                    return Align(
                      key: messageKey,
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe && !isAdmin) ...[
                            _buildAvatar(m.senderId),
                            const SizedBox(width: 8),
                          ],
                          GestureDetector(
                            onHorizontalDragStart: (details) {
                              if (!isMe && !isDeletedByAdmin) {
                                setState(() {
                                  _swipeMessageId = m.id;
                                  _swipeOffset = 0;
                                });
                              }
                            },
                            onHorizontalDragUpdate: (details) {
                              if (!isMe &&
                                  !isDeletedByAdmin &&
                                  _swipeMessageId == m.id) {
                                setState(() {
                                  _swipeOffset =
                                      (_swipeOffset + details.delta.dx)
                                          .clamp(0, 80);
                                });
                              }
                            },
                            onHorizontalDragEnd: (_) {
                              if (!isMe &&
                                  !isDeletedByAdmin &&
                                  _swipeMessageId == m.id) {
                                final shouldReply = _swipeOffset > 30;
                                setState(() {
                                  if (shouldReply) {
                                    _replyingTo = m;
                                  }
                                  _swipeMessageId = null;
                                  _swipeOffset = 0;
                                });
                              }
                            },
                            onHorizontalDragCancel: () {
                              if (!isMe && _swipeMessageId == m.id) {
                                setState(() {
                                  _swipeMessageId = null;
                                  _swipeOffset = 0;
                                });
                              }
                            },
                            onLongPress: isDeletedByAdmin
                                ? null
                                : () => _onMessageLongPress(m, isMe),
                            child: Transform.translate(
                              offset: isSwipingThis
                                  ? Offset(_swipeOffset, 0)
                                  : Offset.zero,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF7C4DFF)
                                      : (isAdmin
                                          ? Colors.deepPurple.shade50
                                          : Colors.white),
                                  borderRadius: radius,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withOpacity(0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: bubbleBorder,
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                if (isAdmin) ...[
                                  Text(
                                    'Admin-WV',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (repliedMessage != null &&
                                    repliedMessage.id != m.id)
                                  GestureDetector(
                                    onTap: () {
                                      final key =
                                          _messageKeys[repliedMessage.id];
                                      final targetContext = key?.currentContext;
                                      if (targetContext != null) {
                                        setState(() {
                                          _highlightMessageId =
                                              repliedMessage.id;
                                        });
                                        Scrollable.ensureVisible(
                                          targetContext,
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          curve: Curves.easeInOut,
                                          alignment: 0.3,
                                        );

                                        Future.delayed(
                                          const Duration(milliseconds: 800),
                                          () {
                                            if (!mounted) return;
                                            if (_highlightMessageId ==
                                                repliedMessage.id) {
                                              setState(() {
                                                _highlightMessageId = null;
                                              });
                                            }
                                          },
                                        );
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border(
                                          left: BorderSide(
                                            color: isMe
                                                ? Colors.white70
                                                : Colors.deepPurple,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (hasReplyImage)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.network(
                                                repliedMessage.imageUrl!,
                                                width: 28,
                                                height: 28,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          if (hasReplyImage)
                                            const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              hasReplyImage &&
                                                      (repliedMessage.message
                                                          .trim()
                                                          .isEmpty)
                                                  ? 'A responder a: foto'
                                                  : 'A responder a: ${repliedMessage.message}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (m.imageUrl != null &&
                                    m.imageUrl!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        m.imageUrl!,
                                        width: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                if (m.message.isNotEmpty)
                                  Text(
                                    m.message,
                                    style: TextStyle(
                                      color: isDeletedByAdmin
                                          ? Colors.grey
                                          : (isMe
                                              ? Colors.white
                                              : Colors.black87),
                                      fontStyle: isDeletedByAdmin
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        m.readAt != null ? '✓✓' : '✓',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: m.readAt != null
                                              ? (isMe
                                                    ? Colors.white
                                                    : Colors.deepPurple)
                                              : (isMe
                                                    ? Colors.white70
                                                    : Colors.grey.shade500),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (isMe && !isAdmin) ...[
                            const SizedBox(width: 8),
                            _buildAvatar(m.senderId),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: _replyingTo == null && _editingMessage == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('reply-bar'),
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _editingMessage != null
                                            ? 'Editando mensagem...'
                                            : 'Respondendo...',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _editingMessage?.message ??
                                            _replyingTo?.message ??
                                            '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.deepPurple,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _replyingTo = null;
                                      _editingMessage = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                  ),
                  if (_pendingImagePaths.isNotEmpty)
                    Container(
                      height: 90,
                      margin: const EdgeInsets.only(bottom: 4),
                      alignment: Alignment.centerLeft,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pendingImagePaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final path = _pendingImagePaths[index];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _pendingImagePaths.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    hintText: 'Escreva uma mensagem...',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _sending ? null : _sendMessage,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.deepPurple,
                                  child: _sending
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.deepPurple),
                        onPressed: _openAttachmentMenu,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

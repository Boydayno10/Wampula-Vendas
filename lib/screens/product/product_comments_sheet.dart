import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/product_comment_model.dart';
import '../../models/user_model.dart';
import '../../services/product_comment_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/auth_service.dart';
import '../../utils/auth_helper.dart';
import '../profile/view_profile_screen.dart';
import '../seller/seller_store_screen.dart';

class ProductCommentsSheet extends StatefulWidget {
  final String productId;
  final bool isClientPublication;
  final String ownerId; // dono do produto/publicação (pode apagar tudo)

  const ProductCommentsSheet({
    super.key,
    required this.productId,
    required this.isClientPublication,
    required this.ownerId,
  });

  @override
  State<ProductCommentsSheet> createState() => _ProductCommentsSheetState();
}

class _ProductCommentsSheetState extends State<ProductCommentsSheet> {
  List<ProductCommentModel> _comments = [];
  Map<String, Map<String, dynamic>> _reactionsByCommentId = {};
  bool _loadingComments = true;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  ProductCommentModel? _replyingTo;
  String? _selectedImagePath;
  ProductCommentModel? _editingComment;
  final Set<String> _expandedRepliesForComment = <String>{};
  final Map<String, UserModel?> _userCache = {};
  final Set<String> _loadingProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loadingComments = true;
    });

    try {
      final comments =
          await ProductCommentService.getByProduct(widget.productId);
      final reactions = await ProductCommentService.getReactionsForComments(
        comments.map((c) => c.id).toList(),
      );

      if (!mounted) return;
      setState(() {
        _comments = comments;
        _reactionsByCommentId = reactions;
        _loadingComments = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingComments = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar comentários: $e')),
      );
    }
  }

  Future<void> _refreshComments() async {
    await _loadComments();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent,
      );
    });
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!AuthHelper.requireAuth(
      context,
      message: 'Faça login para comentar.',
    )) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Se estiver editando, apenas atualiza o comentário existente
      if (_editingComment != null) {
        String? imageUrl = _editingComment!.imageUrl;
        if (_selectedImagePath != null) {
          imageUrl = await ImageUploadService.uploadImage(
            _selectedImagePath!,
            folder: 'product-images',
          );
        }

        await ProductCommentService.updateComment(
          commentId: _editingComment!.id,
          text: text,
          imageUrl: imageUrl,
        );
      } else {
        // Novo comentário (topo ou resposta)
        String? imageUrl;
        if (_selectedImagePath != null) {
          imageUrl = await ImageUploadService.uploadImage(
            _selectedImagePath!,
            folder: 'product-images',
          );
        }

        await ProductCommentService.addComment(
          productId: widget.productId,
          text: text,
          rating: null,
          parentId: _replyingTo?.id,
          imageUrl: imageUrl,
        );
      }

      _controller.clear();
      _replyingTo = null;
      _selectedImagePath = null;
      _editingComment = null;
      await _refreshComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar comentário: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library,
                      color: Colors.deepPurple),
                  title: const Text('Galeria'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera,
                      color: Colors.deepPurple),
                  title: const Text('Câmera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.grey),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar imagem: $e')),
      );
    }
  }

  Future<void> _toggleReaction(ProductCommentModel comment, bool isLike) async {
    if (!AuthHelper.requireAuth(
      context,
      message: 'Faça login para reagir aos comentários.',
    )) {
      return;
    }

    try {
      await ProductCommentService.toggleReaction(
        commentId: comment.id,
        isLike: isLike,
      );
      await _refreshComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar reação: $e')),
      );
    }
  }

  Future<void> _deleteComment(ProductCommentModel comment) async {
    final currentUserId = AuthService.currentUser.id;
    final isOwner = widget.ownerId.isNotEmpty && widget.ownerId == currentUserId;
    final isAuthor = comment.userId == currentUserId;

    if (!isOwner && !isAuthor) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apagar comentário'),
          content: const Text('Tem certeza que deseja apagar este comentário?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ProductCommentService.deleteComment(comment.id);
      if (_replyingTo?.id == comment.id) {
        _replyingTo = null;
      }
      if (_editingComment?.id == comment.id) {
        _editingComment = null;
        _controller.clear();
        _selectedImagePath = null;
      }
      await _refreshComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar comentário: $e')),
      );
    }
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

    // Se for o próprio usuário, abre o Meu perfil
    if (userId == currentUserId) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewProfileScreen(user: safeUser),
        ),
      );
      return;
    }

    // Se for vendedor, abre a loja dele
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

    // Caso contrário, abre o perfil do usuário
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(user: safeUser),
      ),
    );
  }

  Widget _buildAvatar(String userId, String fallbackName) {
    final currentUserId = AuthService.currentUser.id;
    final bool isMe = userId == currentUserId;

    Widget buildAvatarForUser(UserModel? user) {
      final hasImage = user?.profileImageUrl != null &&
          user!.profileImageUrl!.isNotEmpty &&
          user.profileImageUrl!.startsWith('http');

      String initials = '';
      if (user != null && user.name.isNotEmpty) {
        initials = user.name.trim().isNotEmpty
            ? user.name.trim()[0].toUpperCase()
            : '';
      } else if (fallbackName.isNotEmpty) {
        initials = fallbackName.trim()[0].toUpperCase();
      }

      return GestureDetector(
        onTap: () => _onAvatarTap(userId),
        child: CircleAvatar(
          radius: 18,
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

  @override
  Widget build(BuildContext context) {
    const title = 'Comentários';

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Track handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _loadingComments
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCommentsList(),
            ),

            const Divider(height: 1),

            Padding(
              padding: MediaQuery.of(context).viewInsets.add(
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de contexto (respondendo ou editando), estilo "WhatsApp reply"
                  if (_replyingTo != null || _editingComment != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 36,
                            margin: const EdgeInsets.only(right: 8, top: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _editingComment != null
                                      ? 'Editando seu comentário'
                                      : (_replyingTo!.userName.isNotEmpty
                                          ? _replyingTo!.userName
                                          : 'Usuário'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _editingComment != null
                                      ? _editingComment!.text
                                      : _replyingTo!.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _replyingTo = null;
                                _editingComment = null;
                                _controller.clear();
                                _selectedImagePath = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  if (_selectedImagePath != null)
                    Container(
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_selectedImagePath!),
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
                                  _selectedImagePath = null;
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
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Escreva seu comentário...',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _isSending ? null : _sendComment,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.deepPurple,
                                  child: _isSending
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color>(
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
                        icon: const Icon(
                          Icons.add_a_photo_outlined,
                          color: Colors.deepPurple,
                        ),
                        onPressed: _pickImage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'Ainda não há comentários. Seja o primeiro!',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    // Organiza comentários em pais/filhos (respostas)
    final parents = _comments.where((c) => c.parentId == null).toList();
    final childrenByParent = <String, List<ProductCommentModel>>{};

    // Mapa para lookup rápido do pai (para mostrar "citado" estilo WhatsApp)
    final byId = <String, ProductCommentModel>{
      for (final c in _comments) c.id: c,
    };

    for (final c in _comments.where((c) => c.parentId != null)) {
      final parentId = c.parentId!;
      childrenByParent.putIfAbsent(parentId, () => []).add(c);
    }

    // Ordena pais por data (mais antigos primeiro) para que os últimos
    // comentários apareçam embaixo, como em conversas de chat
    parents.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final items = <_CommentWithIndent>[];

    void addWithChildren(ProductCommentModel c, int indent) {
      items.add(_CommentWithIndent(comment: c, indent: indent));
      final children = childrenByParent[c.id] ?? [];
      if (children.isEmpty) return;

      // Ordena respostas mais antigas primeiro
      children.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // A partir de 1 resposta já podemos ocultar, se não estiver expandido
      final hasReplies = children.isNotEmpty;
      final isExpanded = _expandedRepliesForComment.contains(c.id);

      if (hasReplies && !isExpanded) {
        // Não mostra respostas, apenas a barra "Mostrar respostas (X)"
        items.add(
          _CommentWithIndent(
            comment: c,
            indent: indent + 1,
            isToggleRow: true,
            hiddenRepliesCount: children.length,
            toggleParentId: c.id,
          ),
        );
        return;
      }

      // Mostra todas as respostas
      for (final child in children) {
        addWithChildren(child, indent + 1);
      }

      if (hasReplies) {
        // Ao final da lista de respostas, exibe botão para ocultar
        items.add(
          _CommentWithIndent(
            comment: c,
            indent: indent + 1,
            isToggleRow: true,
            hiddenRepliesCount: children.length,
            toggleParentId: c.id,
          ),
        );
      }
    }

    for (final parent in parents) {
      addWithChildren(parent, 0);
    }

    final currentUserId = AuthService.currentUser.id;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // Linha de "Mostrar respostas" / "Ocultar respostas"
        if (item.isToggleRow && item.toggleParentId != null) {
          final isExpanded =
              _expandedRepliesForComment.contains(item.toggleParentId!);
          final text = isExpanded
              ? 'Ocultar respostas'
              : 'Mostrar respostas (${item.hiddenRepliesCount})';

          return Padding(
            padding: EdgeInsets.only(
              left: 6.0 + item.indent * 24.0,
              top: 4,
              bottom: 4,
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedRepliesForComment.remove(item.toggleParentId!);
                  } else {
                    _expandedRepliesForComment.add(item.toggleParentId!);
                  }
                });
              },
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        final c = item.comment;
        final reaction = _reactionsByCommentId[c.id] ??
            {
              'likes': 0,
              'dislikes': 0,
              'myReaction': null,
            };

        final likes = reaction['likes'] as int;
        final dislikes = reaction['dislikes'] as int;
        final myReaction = reaction['myReaction'] as String?;

        final isOwner =
            widget.ownerId.isNotEmpty && widget.ownerId == currentUserId;
        final isAuthor = c.userId == currentUserId;

        // Se for resposta, pega o comentário pai para mostrar "quote" no topo
        final ProductCommentModel? parent =
          c.parentId != null ? byId[c.parentId!] : null;

        return Padding(
          padding: EdgeInsets.only(
            left: 6.0 + item.indent * 24.0,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(c.userId, c.userName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.userName.isNotEmpty
                                ? c.userName
                                : 'Usuário',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isOwner || isAuthor)
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                _showCommentActions(c, isOwner: isOwner, isAuthor: isAuthor),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Cabeçalho de comentário citado (resposta) estilo WhatsApp
                    if (parent != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 28,
                              margin: const EdgeInsets.only(right: 6, top: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parent.userName.isNotEmpty
                                        ? parent.userName
                                        : 'Usuário',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    parent.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (c.imageUrl != null && c.imageUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            c.imageUrl!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Text(
                      c.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatDate(c.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _replyingTo = c;
                              _editingComment = null;
                            });
                          },
                          icon: const Icon(Icons.reply, size: 16),
                          label: const Text(
                            'Responder',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.favorite,
                                size: 18,
                                color: myReaction == 'like'
                                    ? Colors.red
                                    : Colors.grey[500],
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _toggleReaction(c, true),
                            ),
                            if (likes > 0)
                              Text(
                                likes.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.thumb_down_alt_rounded,
                                size: 18,
                                color: myReaction == 'dislike'
                                    ? Colors.blueGrey
                                    : Colors.grey[500],
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _toggleReaction(c, false),
                            ),
                            if (dislikes > 0)
                              Text(
                                dislikes.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCommentActions(
    ProductCommentModel comment, {
    required bool isOwner,
    required bool isAuthor,
  }) async {
    // Autor pode editar e apagar; dono só pode apagar
    final canEdit = isAuthor;
    final canDelete = isOwner || isAuthor;
    if (!canEdit && !canDelete) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar comentário'),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Apagar comentário'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'edit' && canEdit) {
      setState(() {
        _editingComment = comment;
        _replyingTo = null;
        _controller.text = comment.text;
        _selectedImagePath = null; // mantém imagem atual até salvar
      });
    } else if (action == 'delete' && canDelete) {
      await _deleteComment(comment);
    }
  }

  String _formatDate(DateTime dt) {
    // Formato simples: dd/MM HH:mm
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _CommentWithIndent {
  final ProductCommentModel comment;
  final int indent;
  final bool isToggleRow;
  final int hiddenRepliesCount;
  final String? toggleParentId;

  _CommentWithIndent({
    required this.comment,
    required this.indent,
    this.isToggleRow = false,
    this.hiddenRepliesCount = 0,
    this.toggleParentId,
  });
}

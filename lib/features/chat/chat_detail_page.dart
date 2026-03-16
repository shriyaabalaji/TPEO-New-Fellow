import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/storage/storage_service.dart';
import '../../models/chat.dart';
import '../../models/provider_profile.dart';
import '../../models/user_profile.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  const ChatDetailPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String uid, FirestoreService fs) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await fs.sendMessage(
        chatId: widget.chatId,
        senderUid: uid,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  Future<void> _sendImage(
      String uid, FirestoreService fs, ImageSource source) async {
    final storage = ref.read(storageServiceProvider);
    if (storage == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;

    setState(() => _sending = true);
    try {
      final url =
          await storage.uploadChatImage(widget.chatId, File(picked.path));
      if (url != null) {
        await fs.sendMessage(
          chatId: widget.chatId,
          senderUid: uid,
          text: '',
          imageUrl: url,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showAttachMenu(String uid, FirestoreService fs) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo album'),
              onTap: () {
                Navigator.pop(ctx);
                _sendImage(uid, fs, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Open camera'),
              onTap: () {
                Navigator.pop(ctx);
                _sendImage(uid, fs, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Send a file'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return effectiveUser.when(
      data: (appUser) {
        if (appUser == null || fs == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Sign in to chat.')),
          );
        }
        return _buildChat(context, appUser.uid, fs);
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Error')),
      ),
    );
  }

  Widget _buildChat(BuildContext context, String uid, FirestoreService fs) {
    return StreamBuilder<List<ChatConversation>>(
      stream: fs.streamChatsForUser(uid),
      builder: (context, chatSnap) {
        final chats = chatSnap.data ?? [];
        final matches = chats.where((c) => c.chatId == widget.chatId);
        final chat = matches.isNotEmpty ? matches.first : null;
        final isConsumer = chat?.consumerUid == uid;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _ChatAppBar(
              chat: chat,
              isConsumer: isConsumer,
              fs: fs,
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: fs.streamMessages(widget.chatId),
                  builder: (context, msgSnap) {
                    final messages = msgSnap.data ?? [];
                    if (messages.isNotEmpty) _scrollToBottom();

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: (chat != null ? 1 : 0) + _itemCount(messages),
                      itemBuilder: (context, i) {
                        if (chat != null && i == 0) {
                          return _ProviderInfoCard(
                            chat: chat,
                            isConsumer: isConsumer,
                            fs: fs,
                          );
                        }
                        final adjustedIndex = i - (chat != null ? 1 : 0);
                        return _buildMessageItem(
                            context, messages, adjustedIndex, uid);
                      },
                    );
                  },
                ),
              ),
              if (_sending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(),
                  ),
                ),
              _MessageInput(
                controller: _controller,
                onSend: () => _send(uid, fs),
                onAttach: () => _showAttachMenu(uid, fs),
              ),
            ],
          ),
        );
      },
    );
  }

  int _itemCount(List<ChatMessage> messages) {
    if (messages.isEmpty) return 1; // "Say hello" placeholder
    int count = 0;
    String? lastDateKey;
    for (final msg in messages) {
      final dateKey = _dateKey(msg.createdAt);
      if (dateKey != lastDateKey) {
        count++; // date header
        lastDateKey = dateKey;
      }
      count++; // message
    }
    return count;
  }

  Widget _buildMessageItem(
      BuildContext context, List<ChatMessage> messages, int index, String uid) {
    if (messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Text(
            'Say hello!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
        ),
      );
    }

    int cursor = 0;
    String? lastDateKey;
    for (final msg in messages) {
      final dateKey = _dateKey(msg.createdAt);
      if (dateKey != lastDateKey) {
        if (cursor == index) {
          return _DateHeader(dateKey: dateKey);
        }
        cursor++;
        lastDateKey = dateKey;
      }
      if (cursor == index) {
        final isMine = msg.senderUid == uid;
        return _MessageBubble(message: msg, isMine: isMine);
      }
      cursor++;
    }
    return const SizedBox.shrink();
  }

  String _dateKey(DateTime? dt) {
    if (dt == null) return 'Unknown';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── App Bar ──────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar({
    required this.chat,
    required this.isConsumer,
    required this.fs,
  });

  final ChatConversation? chat;
  final bool isConsumer;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (chat != null) ...[
              _AppBarAvatar(
                  chat: chat!, isConsumer: isConsumer, fs: fs),
              const SizedBox(width: 10),
              Expanded(
                child: _AppBarName(
                    chat: chat!, isConsumer: isConsumer, fs: fs),
              ),
            ] else
              const Expanded(child: Text('Chat')),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 24),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarAvatar extends StatelessWidget {
  const _AppBarAvatar({
    required this.chat,
    required this.isConsumer,
    required this.fs,
  });

  final ChatConversation chat;
  final bool isConsumer;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    if (isConsumer) {
      return StreamBuilder<ProviderProfile?>(
        stream: fs.streamProviderProfile(chat.providerProfileId),
        builder: (context, provSnap) {
          final ownerUid = provSnap.data?.ownerUid;
          if (ownerUid == null || ownerUid.isEmpty) {
            return _avatar(context, null);
          }
          return StreamBuilder<UserProfile>(
            stream: fs.streamUserProfile(ownerUid),
            builder: (context, userSnap) =>
                _avatar(context, userSnap.data?.photoUrl),
          );
        },
      );
    }
    return StreamBuilder<UserProfile>(
      stream: fs.streamUserProfile(chat.consumerUid),
      builder: (context, snap) => _avatar(context, snap.data?.photoUrl),
    );
  }

  Widget _avatar(BuildContext context, String? photoUrl) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage:
          photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? const Icon(Icons.person, size: 20, color: Colors.white)
          : null,
    );
  }
}

class _AppBarName extends StatelessWidget {
  const _AppBarName({
    required this.chat,
    required this.isConsumer,
    required this.fs,
  });

  final ChatConversation chat;
  final bool isConsumer;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    if (isConsumer) {
      return StreamBuilder<ProviderProfile?>(
        stream: fs.streamProviderProfile(chat.providerProfileId),
        builder: (context, snap) => _nameColumn(
          context,
          snap.data?.businessName ?? 'Provider',
        ),
      );
    }
    return StreamBuilder<UserProfile>(
      stream: fs.streamUserProfile(chat.consumerUid),
      builder: (context, snap) => _nameColumn(
        context,
        snap.data?.displayName ?? 'Customer',
      ),
    );
  }

  Widget _nameColumn(BuildContext context, String name) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Active today',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

// ── Provider Info Card ───────────────────────────────────────────────────

class _ProviderInfoCard extends StatelessWidget {
  const _ProviderInfoCard({
    required this.chat,
    required this.isConsumer,
    required this.fs,
  });

  final ChatConversation chat;
  final bool isConsumer;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProviderProfile?>(
      stream: fs.streamProviderProfile(chat.providerProfileId),
      builder: (context, provSnap) {
        final provider = provSnap.data;
        if (provider == null) return const SizedBox(height: 16);

        final ownerUid = provider.ownerUid;
        return StreamBuilder<UserProfile>(
          stream: ownerUid.isNotEmpty
              ? fs.streamUserProfile(ownerUid)
              : const Stream.empty(),
          builder: (context, userSnap) {
            final ownerName = userSnap.data?.displayName ?? '';
            final displayName = ownerName.isNotEmpty
                ? _shortenName(ownerName)
                : provider.businessName;
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Column(
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.ratingAvg.toStringAsFixed(1)} (${provider.reviewCount})',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _shortenName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) return fullName;
    return '${parts.first} ${parts.last[0]}.';
  }
}

// ── Date Header ─────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          dateKey,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Message Bubble ──────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.isImage) _buildImage(context),
                  if (message.text.isNotEmpty) _buildTextBubble(context),
                  if (message.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        _formatTime(message.createdAt!),
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFFF5F5F5) : const Color(0xFFF0F0F0),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      child: Text(
        message.text,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          message.imageUrl!,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 200,
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: 200,
            height: 200,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }
}

// ── Message Input ───────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAttach,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
              ),
              child: Icon(Icons.add, size: 20, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
              ),
              child: Icon(Icons.send, size: 18, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

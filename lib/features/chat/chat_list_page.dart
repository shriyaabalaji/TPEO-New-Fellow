import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/chat.dart';
import '../auth/effective_user_provider.dart';
import '../profile/provider_account_controller.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null) {
            return const Center(child: Text('Sign in to see messages.'));
          }
          if (appUser.isDemo) {
            return _buildEmptyState(context);
          }
          final fs = ref.watch(firestoreServiceProvider);
          if (fs == null) {
            return const Center(child: Text('Connecting...'));
          }
          return _ChatList(uid: appUser.uid, fs: fs);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation by booking a service or contacting a provider.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.uid, required this.fs});

  final String uid;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatConversation>>(
      stream: fs.streamChatsForUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation by booking a service or contacting a provider.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
          itemBuilder: (context, i) =>
              _ChatTile(chat: chats[i], currentUid: uid, fs: fs),
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.currentUid,
    required this.fs,
  });

  final ChatConversation chat;
  final String currentUid;
  final FirestoreService fs;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$hour:$m $period';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isConsumer = chat.consumerUid == currentUid;

    return FutureBuilder<_ChatDisplayInfo>(
      future: _resolveDisplayInfo(isConsumer),
      builder: (context, snap) {
        final info = snap.data ??
            _ChatDisplayInfo(name: 'Loading...', photoUrl: null);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            backgroundImage:
                info.photoUrl != null ? NetworkImage(info.photoUrl!) : null,
            child: info.photoUrl == null
                ? Text(
                    info.name.isNotEmpty
                        ? info.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  info.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatDate(chat.lastMessageAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          onTap: () => context.push('/chat/${chat.chatId}'),
        );
      },
    );
  }

  Future<_ChatDisplayInfo> _resolveDisplayInfo(bool isConsumer) async {
    if (isConsumer) {
      final providerSnap = await fs.streamProviderProfile(chat.providerProfileId).first;
      return _ChatDisplayInfo(
        name: providerSnap?.businessName ?? 'Provider',
        photoUrl: providerSnap?.bannerUrl,
      );
    } else {
      final userSnap = await fs.streamUserProfile(chat.consumerUid).first;
      return _ChatDisplayInfo(
        name: userSnap.displayName.isNotEmpty ? userSnap.displayName : 'Customer',
        photoUrl: userSnap.photoUrl,
      );
    }
  }
}

class _ChatDisplayInfo {
  final String name;
  final String? photoUrl;
  _ChatDisplayInfo({required this.name, this.photoUrl});
}

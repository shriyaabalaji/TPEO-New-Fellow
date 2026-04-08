import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/subpage_app_bar.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

String _formatRelativeReviewDate(DateTime? t) {
  if (t == null) return '';
  final diff = DateTime.now().difference(t);
  if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'Just now';
}

class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildSubpageAppBar(context, title: 'Your Reviews'),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo || fs == null) {
            return const Center(
              child: Text(
                'Sign in to see reviews you have submitted.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
            );
          }
          return StreamBuilder(
            stream: fs.streamAppointmentsByConsumer(appUser.uid),
            builder: (context, snap) {
              final reviewed = (snap.data ?? [])
                  .where((a) => (a.reviewRating ?? 0) >= 1)
                  .toList()
                ..sort((a, b) => (b.reviewedAt ?? DateTime(1970))
                    .compareTo(a.reviewedAt ?? DateTime(1970)));
              if (reviewed.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Reviews you submit after appointments will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reviewed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final a = reviewed[i];
                  final comment = (a.reviewComment ?? '').trim();
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.serviceName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ...List.generate(
                              a.reviewRating ?? 0,
                              (_) => const Icon(Icons.star, size: 14, color: Colors.black),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatRelativeReviewDate(a.reviewedAt),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            comment,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  final String chatId;
  final String consumerUid;
  final String providerProfileId;
  final List<String> participantUids;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderUid;
  final DateTime? createdAt;

  ChatConversation({
    required this.chatId,
    required this.consumerUid,
    required this.providerProfileId,
    required this.participantUids,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderUid,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'chatId': chatId,
        'consumerUid': consumerUid,
        'providerProfileId': providerProfileId,
        'participantUids': participantUids,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt ?? FieldValue.serverTimestamp(),
        'lastSenderUid': lastSenderUid,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };

  factory ChatConversation.fromMap(Map<String, dynamic> m) {
    DateTime? parseTimestamp(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return ChatConversation(
      chatId: m['chatId'] as String? ?? '',
      consumerUid: m['consumerUid'] as String? ?? '',
      providerProfileId: m['providerProfileId'] as String? ?? '',
      participantUids: (m['participantUids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lastMessage: m['lastMessage'] as String? ?? '',
      lastMessageAt: parseTimestamp(m['lastMessageAt']),
      lastSenderUid: m['lastSenderUid'] as String?,
      createdAt: parseTimestamp(m['createdAt']),
    );
  }
}

class ChatMessage {
  final String messageId;
  final String senderUid;
  final String text;
  final String? imageUrl;
  final DateTime? createdAt;

  ChatMessage({
    required this.messageId,
    required this.senderUid,
    required this.text,
    this.imageUrl,
    this.createdAt,
  });

  bool get isImage => imageUrl != null && imageUrl!.isNotEmpty;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'messageId': messageId,
      'senderUid': senderUid,
      'text': text,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
    if (imageUrl != null) map['imageUrl'] = imageUrl;
    return map;
  }

  factory ChatMessage.fromMap(Map<String, dynamic> m) {
    DateTime? parseTimestamp(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return ChatMessage(
      messageId: m['messageId'] as String? ?? '',
      senderUid: m['senderUid'] as String? ?? '',
      text: m['text'] as String? ?? '',
      imageUrl: m['imageUrl'] as String?,
      createdAt: parseTimestamp(m['createdAt']),
    );
  }
}

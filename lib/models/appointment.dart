import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  const Appointment({
    required this.appointmentId,
    required this.consumerUid,
    required this.providerProfileId,
    this.serviceId,
    required this.serviceName,
    required this.slotLabel,
    this.price,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.reviewRating,
    this.reviewComment,
    this.reviewedAt,
    this.reviewerDisplayName,
  });

  final String appointmentId;
  final String consumerUid;
  final String providerProfileId;
  final String? serviceId;
  final String serviceName;
  final String slotLabel;
  final String? price;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? reviewRating;
  final String? reviewComment;
  final DateTime? reviewedAt;
  final String? reviewerDisplayName;

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  Map<String, dynamic> toMap() => {
        'appointmentId': appointmentId,
        'consumerUid': consumerUid,
        'providerProfileId': providerProfileId,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'slotLabel': slotLabel,
        'price': price,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'reviewRating': reviewRating,
        'reviewComment': reviewComment,
        'reviewedAt': reviewedAt,
        'reviewerDisplayName': reviewerDisplayName,
      };

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
        appointmentId: m['appointmentId'] as String? ?? '',
        consumerUid: m['consumerUid'] as String? ?? '',
        providerProfileId: m['providerProfileId'] as String? ?? '',
        serviceId: m['serviceId'] as String?,
        serviceName: m['serviceName'] as String? ?? '',
        slotLabel: m['slotLabel'] as String? ?? '',
        price: m['price'] as String?,
        status: m['status'] as String? ?? 'pending',
        createdAt: _ts(m['createdAt']),
        updatedAt: _ts(m['updatedAt']),
        reviewRating: (m['reviewRating'] as num?)?.toInt(),
        reviewComment: m['reviewComment'] as String?,
        reviewedAt: _ts(m['reviewedAt']),
        reviewerDisplayName: m['reviewerDisplayName'] as String?,
      );
}

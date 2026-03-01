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
        createdAt: m['createdAt'] is DateTime ? m['createdAt'] as DateTime : null,
        updatedAt: m['updatedAt'] is DateTime ? m['updatedAt'] as DateTime : null,
      );
}

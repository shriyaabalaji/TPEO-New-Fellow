class ProviderProfile {
  final String providerProfileId;
  final String ownerUid;
  final String businessName;
  final List<String> tags;
  final Map<String, dynamic>? contact;
  final Map<String, dynamic>? location;
  final double ratingAvg;
  final int reviewCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProviderProfile({
    required this.providerProfileId,
    required this.ownerUid,
    required this.businessName,
    this.tags = const [],
    this.contact,
    this.location,
    this.ratingAvg = 0,
    this.reviewCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'providerProfileId': providerProfileId,
        'ownerUid': ownerUid,
        'businessName': businessName,
        'tags': tags,
        'contact': contact ?? {},
        'location': location ?? {},
        'ratingAvg': ratingAvg,
        'reviewCount': reviewCount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ProviderProfile.fromMap(Map<String, dynamic> m) => ProviderProfile(
        providerProfileId: m['providerProfileId'] as String,
        ownerUid: m['ownerUid'] as String,
        businessName: m['businessName'] as String? ?? '',
        tags: (m['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        contact: m['contact'] as Map<String, dynamic>?,
        location: m['location'] as Map<String, dynamic>?,
        ratingAvg: (m['ratingAvg'] as num?)?.toDouble() ?? 0,
        reviewCount: (m['reviewCount'] as int?) ?? 0,
        createdAt: m['createdAt'] is DateTime ? m['createdAt'] as DateTime : null,
        updatedAt: m['updatedAt'] is DateTime ? m['updatedAt'] as DateTime : null,
      );
}

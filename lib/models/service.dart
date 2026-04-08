class Service {
  const Service({
    required this.serviceId,
    required this.providerProfileId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.bannerUrl,
    this.description,
    this.pricingDescription,
    this.galleryUrls,
    this.ratingAvg = 0,
    this.reviewCount = 0,
  });

  final String serviceId;
  final String providerProfileId;
  final String name;
  final String price;
  final int durationMinutes;
  final String? bannerUrl;
  final String? description;
  final String? pricingDescription;
  final List<String>? galleryUrls;
  final double ratingAvg;
  final int reviewCount;

  Map<String, dynamic> toMap() => {
        'serviceId': serviceId,
        'providerProfileId': providerProfileId,
        'name': name,
        'price': price,
        'durationMinutes': durationMinutes,
        'bannerUrl': bannerUrl,
        'description': description,
        'pricingDescription': pricingDescription,
        'galleryUrls': galleryUrls,
        'ratingAvg': ratingAvg,
        'reviewCount': reviewCount,
      };

  factory Service.fromMap(Map<String, dynamic> m) => Service(
        serviceId: m['serviceId'] as String? ?? '',
        providerProfileId: m['providerProfileId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        price: m['price'] as String? ?? '',
        durationMinutes: m['durationMinutes'] as int? ?? 0,
        bannerUrl: m['bannerUrl'] as String?,
        description: m['description'] as String?,
        pricingDescription: m['pricingDescription'] as String?,
        galleryUrls: (m['galleryUrls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        ratingAvg: (m['ratingAvg'] as num?)?.toDouble() ?? 0,
        reviewCount: (m['reviewCount'] as int?) ?? 0,
      );
}

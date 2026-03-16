class Service {
  const Service({
    required this.serviceId,
    required this.providerProfileId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.bannerUrl,
  });

  final String serviceId;
  final String providerProfileId;
  final String name;
  final String price;
  final int durationMinutes;
  final String? bannerUrl;

  Map<String, dynamic> toMap() => {
        'serviceId': serviceId,
        'providerProfileId': providerProfileId,
        'name': name,
        'price': price,
        'durationMinutes': durationMinutes,
        'bannerUrl': bannerUrl,
      };

  factory Service.fromMap(Map<String, dynamic> m) => Service(
        serviceId: m['serviceId'] as String? ?? '',
        providerProfileId: m['providerProfileId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        price: m['price'] as String? ?? '',
        durationMinutes: m['durationMinutes'] as int? ?? 0,
        bannerUrl: m['bannerUrl'] as String?,
      );
}

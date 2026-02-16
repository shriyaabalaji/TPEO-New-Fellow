class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? activeProviderProfileId;
  final List<String>? providerProfileIds;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
    this.activeProviderProfileId,
    this.providerProfileIds,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'activeProviderProfileId': activeProviderProfileId,
        'providerProfileIds': providerProfileIds ?? [],
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: m['uid'] as String,
        displayName: m['displayName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        photoUrl: m['photoUrl'] as String?,
        createdAt: m['createdAt'] is DateTime ? m['createdAt'] as DateTime : null,
        updatedAt: m['updatedAt'] is DateTime ? m['updatedAt'] as DateTime : null,
        activeProviderProfileId: m['activeProviderProfileId'] as String?,
        providerProfileIds: (m['providerProfileIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      );
}

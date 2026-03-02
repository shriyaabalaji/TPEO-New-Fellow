class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? username;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? activeProviderProfileId;
  final List<String>? providerProfileIds;
  final List<String>? favoriteProviderIds;
  /// From onboarding: 'provider', 'customer', or 'both'. Used to default view mode.
  final String? onboardingRole;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.username,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
    this.activeProviderProfileId,
    this.providerProfileIds,
    this.favoriteProviderIds,
    this.onboardingRole,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'username': username,
        'photoUrl': photoUrl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'activeProviderProfileId': activeProviderProfileId,
        'providerProfileIds': providerProfileIds ?? [],
        'favoriteProviderIds': favoriteProviderIds ?? [],
        'onboardingRole': onboardingRole,
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: m['uid'] as String,
        displayName: m['displayName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        username: m['username'] as String?,
        photoUrl: m['photoUrl'] as String?,
        createdAt: m['createdAt'] is DateTime ? m['createdAt'] as DateTime : null,
        updatedAt: m['updatedAt'] is DateTime ? m['updatedAt'] as DateTime : null,
        activeProviderProfileId: m['activeProviderProfileId'] as String?,
        providerProfileIds: (m['providerProfileIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
        favoriteProviderIds: (m['favoriteProviderIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
        onboardingRole: m['onboardingRole'] as String?,
      );
}

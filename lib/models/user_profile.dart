import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Personal Google account used only for Calendar API (optional; sign-in stays Firebase email/password).
  final String? calendarGoogleEmail;
  final DateTime? calendarConnectedAt;

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
    this.calendarGoogleEmail,
    this.calendarConnectedAt,
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
        'calendarGoogleEmail': calendarGoogleEmail,
        'calendarConnectedAt': calendarConnectedAt,
      };

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: m['uid'] as String,
        displayName: m['displayName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        username: m['username'] as String?,
        photoUrl: m['photoUrl'] as String?,
        createdAt: _ts(m['createdAt']),
        updatedAt: _ts(m['updatedAt']),
        activeProviderProfileId: m['activeProviderProfileId'] as String?,
        providerProfileIds: (m['providerProfileIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
        favoriteProviderIds: (m['favoriteProviderIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
        onboardingRole: m['onboardingRole'] as String?,
        calendarGoogleEmail: m['calendarGoogleEmail'] as String?,
        calendarConnectedAt: _ts(m['calendarConnectedAt']),
      );
}

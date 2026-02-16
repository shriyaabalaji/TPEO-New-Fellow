import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../models/provider_profile.dart';
import 'paths.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> upsertUserProfile(fb.User user) async {
    final ref = _db.collection(FSPaths.users).doc(user.uid);
  final now = FieldValue.serverTimestamp();
    final doc = await ref.get();
    final data = {
      'uid': user.uid,
      'displayName': user.displayName ?? '',
      'photoUrl': user.photoURL,
      'email': user.email ?? '',
      'updatedAt': now,
    };
    if (!doc.exists) {
      data['createdAt'] = now;
      data['providerProfileIds'] = [];
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<String> createProviderProfile({required String ownerUid, required String businessName, List<String>? tags}) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc();
    final now = FieldValue.serverTimestamp();
    final model = ProviderProfile(
      providerProfileId: ref.id,
      ownerUid: ownerUid,
      businessName: businessName,
      tags: tags ?? [],
      ratingAvg: 0,
      reviewCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.set(model.toMap());

    // update user doc: append providerProfileIds and set active if null
    final userRef = _db.collection(FSPaths.users).doc(ownerUid);
    final userDoc = await userRef.get();
    if (userDoc.exists) {
      final existing = userDoc.data();
      final active = existing?['activeProviderProfileId'];
      final updates = {
        'providerProfileIds': FieldValue.arrayUnion([ref.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (active == null) updates['activeProviderProfileId'] = ref.id;
      await userRef.update(updates);
    } else {
      await userRef.set({
        'uid': ownerUid,
        'providerProfileIds': [ref.id],
        'activeProviderProfileId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return ref.id;
  }

  Future<void> setActiveProviderProfile({required String uid, required String providerProfileId}) async {
    final userRef = _db.collection(FSPaths.users).doc(uid);
    final doc = await _db.collection(FSPaths.providerProfiles).doc(providerProfileId).get();
    if (!doc.exists) throw Exception('Provider profile not found');
    final ownerUid = doc.data()?['ownerUid'] as String?;
    if (ownerUid != uid) throw Exception('Not owner');
    await userRef.update({'activeProviderProfileId': providerProfileId, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<UserProfile> streamUserProfile(String uid) {
    return _db.collection(FSPaths.users).doc(uid).snapshots().map((s) => UserProfile.fromMap(s.data()!));
  }

  Stream<List<ProviderProfile>> streamProviderProfilesByOwner(String ownerUid) {
    return _db.collection(FSPaths.providerProfiles).where('ownerUid', isEqualTo: ownerUid).snapshots().map((q) =>
        q.docs.map((d) => ProviderProfile.fromMap(d.data())).toList());
  }

  Stream<ProviderProfile?> streamProviderProfile(String providerId) {
    return _db.collection(FSPaths.providerProfiles).doc(providerId).snapshots().map((s) {
      if (!s.exists) return null;
      return ProviderProfile.fromMap(s.data()!);
    });
  }
}

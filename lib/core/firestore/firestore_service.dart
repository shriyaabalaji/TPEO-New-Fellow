import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../../models/availability_slot.dart';
import '../../models/appointment.dart';
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

  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? username,
    String? photoUrl,
    String? onboardingRole,
  }) async {
    final ref = _db.collection(FSPaths.users).doc(uid);
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (displayName != null) updates['displayName'] = displayName;
    if (username != null) updates['username'] = username;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (onboardingRole != null) updates['onboardingRole'] = onboardingRole;
    if (updates.length == 1) return;
    await ref.set(updates, SetOptions(merge: true));
  }

  Future<String> createProviderProfile({required String ownerUid, required String businessName, List<String>? tags}) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc();
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
      final updates = <String, dynamic>{
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

  Future<void> updateProviderProfile({
    required String providerProfileId,
    required String ownerUid,
    String? businessName,
    List<String>? tags,
    Map<String, dynamic>? contact,
    Map<String, dynamic>? location,
  }) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc(providerProfileId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Provider profile not found');
    if (doc.data()?['ownerUid'] != ownerUid) throw Exception('Not owner');
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (businessName != null) updates['businessName'] = businessName;
    if (tags != null) updates['tags'] = tags;
    if (contact != null) updates['contact'] = contact;
    if (location != null) updates['location'] = location;
    if (updates.length == 1) return;
    await ref.update(updates);
  }

  Future<void> deleteProviderProfile({required String providerProfileId, required String ownerUid}) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc(providerProfileId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Provider profile not found');
    if (doc.data()?['ownerUid'] != ownerUid) throw Exception('Not owner');
    await ref.delete();
    final userRef = _db.collection(FSPaths.users).doc(ownerUid);
    final userDoc = await userRef.get();
    final data = userDoc.data();
    final ids = List<String>.from((data?['providerProfileIds'] as List<dynamic>?)?.map((e) => e as String) ?? []);
    ids.remove(providerProfileId);
    final activeId = data?['activeProviderProfileId'] as String?;
    final updates = <String, dynamic>{
      'providerProfileIds': ids,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (activeId == providerProfileId) {
      updates['activeProviderProfileId'] = ids.isEmpty ? FieldValue.delete() : ids.first;
    }
    await userRef.update(updates);
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

  Stream<List<ProviderProfile>> streamAllProviderProfiles() {
    return _db.collection(FSPaths.providerProfiles).snapshots().map((q) =>
        q.docs.map((d) => ProviderProfile.fromMap(d.data())).toList());
  }

  Stream<List<Service>> streamServices(String providerProfileId) {
    return _db
        .collection(FSPaths.providerProfiles)
        .doc(providerProfileId)
        .collection(FSPaths.services)
        .snapshots()
        .map((q) => q.docs.map((d) => Service.fromMap({...d.data(), 'serviceId': d.id})).toList());
  }

  Future<void> addService({
    required String providerProfileId,
    required String name,
    required String price,
    required int durationMinutes,
  }) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc(providerProfileId).collection(FSPaths.services).doc();
    final s = Service(
      serviceId: ref.id,
      providerProfileId: providerProfileId,
      name: name,
      price: price,
      durationMinutes: durationMinutes,
    );
    await ref.set(s.toMap());
  }

  Future<void> updateService({
    required String providerProfileId,
    required String serviceId,
    required String name,
    required String price,
    required int durationMinutes,
  }) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc(providerProfileId).collection(FSPaths.services).doc(serviceId);
    await ref.update({'name': name, 'price': price, 'durationMinutes': durationMinutes});
  }

  Future<void> deleteService({required String providerProfileId, required String serviceId}) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc(providerProfileId).collection(FSPaths.services).doc(serviceId);
    await ref.delete();
  }

  static const _availabilityDocId = 'schedule';

  Stream<List<AvailabilitySlot>> streamAvailability(String providerProfileId) {
    return _db
        .collection(FSPaths.providerProfiles)
        .doc(providerProfileId)
        .collection(FSPaths.availability)
        .doc(_availabilityDocId)
        .snapshots()
        .map((s) {
      if (!s.exists) return <AvailabilitySlot>[];
      final data = s.data();
      final list = data?['slots'] as List<dynamic>?;
      if (list == null) return <AvailabilitySlot>[];
      return list.map((e) => AvailabilitySlot.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<void> setAvailability(String providerProfileId, List<AvailabilitySlot> slots) async {
    final ref = _db
        .collection(FSPaths.providerProfiles)
        .doc(providerProfileId)
        .collection(FSPaths.availability)
        .doc(_availabilityDocId);
    await ref.set({'slots': slots.map((s) => s.toMap()).toList()});
  }

  Future<void> createAppointment({
    required String consumerUid,
    required String providerProfileId,
    String? serviceId,
    required String serviceName,
    required String slotLabel,
    String? price,
  }) async {
    final ref = _db.collection(FSPaths.appointments).doc();
    final a = Appointment(
      appointmentId: ref.id,
      consumerUid: consumerUid,
      providerProfileId: providerProfileId,
      serviceId: serviceId,
      serviceName: serviceName,
      slotLabel: slotLabel,
      price: price,
      status: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.set(a.toMap());
  }

  Stream<List<Appointment>> streamAppointmentsByConsumer(String consumerUid) {
    return _db
        .collection(FSPaths.appointments)
        .where('consumerUid', isEqualTo: consumerUid)
        .snapshots()
        .map((q) => q.docs.map((d) => Appointment.fromMap({...d.data(), 'appointmentId': d.id})).toList());
  }

  Stream<List<Appointment>> streamAppointmentsByProviderProfile(String providerProfileId) {
    return _db
        .collection(FSPaths.appointments)
        .where('providerProfileId', isEqualTo: providerProfileId)
        .snapshots()
        .map((q) => q.docs.map((d) => Appointment.fromMap({...d.data(), 'appointmentId': d.id})).toList());
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await _db.collection(FSPaths.appointments).doc(appointmentId).update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> addFavorite(String uid, String providerProfileId) async {
    await _db.collection(FSPaths.users).doc(uid).set({
      'favoriteProviderIds': FieldValue.arrayUnion([providerProfileId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFavorite(String uid, String providerProfileId) async {
    final ref = _db.collection(FSPaths.users).doc(uid);
    final doc = await ref.get();
    final list = List<String>.from((doc.data()?['favoriteProviderIds'] as List<dynamic>?)?.map((e) => e as String) ?? []);
    list.remove(providerProfileId);
    await ref.set({'favoriteProviderIds': list, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}

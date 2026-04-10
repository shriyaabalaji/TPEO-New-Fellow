import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../models/provider_profile.dart';
import '../../models/service.dart';
import '../../models/availability_slot.dart';
import '../../models/appointment.dart';
import '../../models/team_member.dart';
import '../../models/chat.dart';
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

  /// Stores the personal Google account used for Calendar (optional; Firebase auth unchanged).
  Future<void> setCalendarGoogleConnection({
    required String uid,
    required String googleEmail,
  }) async {
    await _db.collection(FSPaths.users).doc(uid).set({
      'calendarGoogleEmail': googleEmail,
      'calendarConnectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearCalendarGoogleConnection(String uid) async {
    await _db.collection(FSPaths.users).doc(uid).set({
      'calendarGoogleEmail': FieldValue.delete(),
      'calendarConnectedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Creates the single business (provider profile) for a service provider.
  /// Each service provider may only have one business; throws if they already have one.
  Future<String> createProviderProfile({required String ownerUid, required String businessName, List<String>? tags}) async {
    final existing = await _db.collection(FSPaths.providerProfiles).where('ownerUid', isEqualTo: ownerUid).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw StateError('A service provider may only have one business. Edit your existing business instead.');
    }
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
    String? bannerUrl,
    List<String>? galleryUrls,
    String? about,
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
    if (bannerUrl != null) updates['bannerUrl'] = bannerUrl;
    if (galleryUrls != null) updates['galleryUrls'] = galleryUrls;
    if (about != null) updates['about'] = about;
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

  Future<String> addService({
    required String providerProfileId,
    required String name,
    required String price,
    required int durationMinutes,
    String? bannerUrl,
    String? description,
    String? pricingDescription,
    List<String>? galleryUrls,
  }) async {
    final ref = _db.collection(FSPaths.providerProfiles).doc(providerProfileId).collection(FSPaths.services).doc();
    final s = Service(
      serviceId: ref.id,
      providerProfileId: providerProfileId,
      name: name,
      price: price,
      durationMinutes: durationMinutes,
      bannerUrl: bannerUrl,
      description: description,
      pricingDescription: pricingDescription,
      galleryUrls: galleryUrls,
    );
    await ref.set(s.toMap());
    return ref.id;
  }

  Future<void> updateService({
    required String providerProfileId,
    required String serviceId,
    required String name,
    required String price,
    required int durationMinutes,
    String? bannerUrl,
    String? description,
    String? pricingDescription,
    List<String>? galleryUrls,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'price': price,
      'durationMinutes': durationMinutes,
    };
    if (bannerUrl != null) updates['bannerUrl'] = bannerUrl;
    updates['description'] = description ?? '';
    updates['pricingDescription'] = pricingDescription ?? '';
    updates['galleryUrls'] = galleryUrls ?? <String>[];
    final ref = _db.collection(FSPaths.providerProfiles).doc(providerProfileId).collection(FSPaths.services).doc(serviceId);
    await ref.update(updates);
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
    String? notes,
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
      notes: notes,
      status: 'requested',
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

  /// Update appointment fields (for provider editing before confirm). Only provided fields are updated.
  Future<void> updateAppointment({
    required String appointmentId,
    String? serviceName,
    String? slotLabel,
    String? price,
  }) async {
    final ref = _db.collection(FSPaths.appointments).doc(appointmentId);
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (serviceName != null) updates['serviceName'] = serviceName;
    if (slotLabel != null) updates['slotLabel'] = slotLabel;
    if (price != null) updates['price'] = price;
    if (updates.length == 1) return;
    await ref.update(updates);
  }

  /// One review per appointment; updates provider and service aggregate ratings.
  /// Only allowed when the appointment status is [completed].
  Future<void> submitConsumerReview({
    required String appointmentId,
    required String consumerUid,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be 1–5');
    }
    await _db.runTransaction((txn) async {
      final appRef = _db.collection(FSPaths.appointments).doc(appointmentId);
      final userRef = _db.collection(FSPaths.users).doc(consumerUid);

      final appSnap = await txn.get(appRef);
      if (!appSnap.exists) {
        throw StateError('Appointment not found');
      }
      final data = appSnap.data()!;
      if (data['consumerUid'] != consumerUid) {
        throw StateError('Not your appointment');
      }
      if (data['reviewRating'] != null) {
        throw StateError('You already left feedback for this appointment');
      }
      final status = data['status'] as String? ?? '';
      if (status != 'completed') {
        throw StateError('Feedback is only available for completed appointments');
      }

      final providerProfileId = data['providerProfileId'] as String? ?? '';
      if (providerProfileId.isEmpty) {
        throw StateError('Invalid appointment');
      }
      final serviceId = data['serviceId'] as String?;

      final userSnap = await txn.get(userRef);
      final reviewerName =
          (userSnap.data()?['displayName'] as String?)?.trim().isNotEmpty == true
              ? (userSnap.data()!['displayName'] as String).trim()
              : 'Customer';

      final provRef = _db.collection(FSPaths.providerProfiles).doc(providerProfileId);
      final provSnap = await txn.get(provRef);
      if (!provSnap.exists) {
        throw StateError('Provider not found');
      }
      final provD = provSnap.data()!;
      final oldAvg = (provD['ratingAvg'] as num?)?.toDouble() ?? 0;
      final oldCount = (provD['reviewCount'] as int?) ?? 0;
      final newCount = oldCount + 1;
      final newAvg = (oldAvg * oldCount + rating) / newCount;

      DocumentSnapshot<Map<String, dynamic>>? svcSnap;
      if (serviceId != null && serviceId.isNotEmpty) {
        final svcRef = provRef.collection(FSPaths.services).doc(serviceId);
        svcSnap = await txn.get(svcRef);
      }

      txn.update(provRef, {
        'ratingAvg': newAvg,
        'reviewCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (svcSnap != null && svcSnap.exists) {
        final sD = svcSnap.data()!;
        final sOldAvg = (sD['ratingAvg'] as num?)?.toDouble() ?? 0;
        final sOldCount = (sD['reviewCount'] as int?) ?? 0;
        final sNewCount = sOldCount + 1;
        final sNewAvg = (sOldAvg * sOldCount + rating) / sNewCount;
        txn.update(svcSnap.reference, {
          'ratingAvg': sNewAvg,
          'reviewCount': sNewCount,
        });
      }

      txn.update(appRef, {
        'reviewRating': rating,
        'reviewComment': comment ?? '',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewerDisplayName': reviewerName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addFavorite(String uid, String providerProfileId) async {
    await _db.collection(FSPaths.users).doc(uid).set({
      'favoriteProviderIds': FieldValue.arrayUnion([providerProfileId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<TeamMember>> streamTeamMembers(String providerProfileId) {
    return _db
        .collection(FSPaths.providerProfiles)
        .doc(providerProfileId)
        .collection(FSPaths.teamMembers)
        .snapshots()
        .map((q) => q.docs
            .map((d) => TeamMember.fromMap({...d.data(), 'teamMemberId': d.id}))
            .toList());
  }

  Future<String> addTeamMember({
    required String providerProfileId,
    required String displayName,
    String? email,
    String? role,
  }) async {
    final ref = _db
        .collection(FSPaths.providerProfiles)
        .doc(providerProfileId)
        .collection(FSPaths.teamMembers)
        .doc();
    final m = TeamMember(
      teamMemberId: ref.id,
      providerProfileId: providerProfileId,
      displayName: displayName,
      email: email,
      role: role,
    );
    await ref.set(m.toMap());
    return ref.id;
  }

  Future<void> updateTeamMember({
    required String providerProfileId,
    required String teamMemberId,
    String? displayName,
    String? email,
    String? role,
  }) async {
    final ref = _db
        .collection(FSPaths.providerProfiles)
        .doc(providerProfileId)
        .collection(FSPaths.teamMembers)
        .doc(teamMemberId);
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (email != null) updates['email'] = email;
    if (role != null) updates['role'] = role;
    if (updates.isEmpty) return;
    await ref.update(updates);
  }

  Future<void> deleteTeamMember({
    required String providerProfileId,
    required String teamMemberId,
  }) async {
    await _db
        .collection(FSPaths.providerProfiles)
        .doc(providerProfileId)
        .collection(FSPaths.teamMembers)
        .doc(teamMemberId)
        .delete();
  }

  Future<void> removeFavorite(String uid, String providerProfileId) async {
    final ref = _db.collection(FSPaths.users).doc(uid);
    final doc = await ref.get();
    final list = List<String>.from((doc.data()?['favoriteProviderIds'] as List<dynamic>?)?.map((e) => e as String) ?? []);
    list.remove(providerProfileId);
    await ref.set({'favoriteProviderIds': list, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  // ── Chat ──────────────────────────────────────────────────────────────

  /// Find or create a 1-on-1 chat between a consumer and a provider profile.
  Future<String> getOrCreateChat({
    required String consumerUid,
    required String providerProfileId,
    required String providerOwnerUid,
  }) async {
    final existing = await _db
        .collection(FSPaths.chats)
        .where('consumerUid', isEqualTo: consumerUid)
        .where('providerProfileId', isEqualTo: providerProfileId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final ref = _db.collection(FSPaths.chats).doc();
    final chat = ChatConversation(
      chatId: ref.id,
      consumerUid: consumerUid,
      providerProfileId: providerProfileId,
      participantUids: [consumerUid, providerOwnerUid],
      lastMessage: '',
      createdAt: DateTime.now(),
    );
    await ref.set(chat.toMap());
    return ref.id;
  }

  /// Stream all chats where the given uid is a participant, ordered by last message.
  Stream<List<ChatConversation>> streamChatsForUser(String uid) {
    return _db
        .collection(FSPaths.chats)
        .where('participantUids', arrayContains: uid)
        .snapshots()
        .map((q) {
      final list = q.docs
          .map((d) => ChatConversation.fromMap({...d.data(), 'chatId': d.id}))
          .toList();
      list.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Stream messages for a chat, newest last.
  Stream<List<ChatMessage>> streamMessages(String chatId) {
    return _db
        .collection(FSPaths.chats)
        .doc(chatId)
        .collection(FSPaths.messages)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((q) => q.docs
            .map((d) => ChatMessage.fromMap({...d.data(), 'messageId': d.id}))
            .toList());
  }

  /// Send a message and update the conversation's lastMessage fields.
  Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    required String text,
    String? imageUrl,
  }) async {
    final msgRef = _db
        .collection(FSPaths.chats)
        .doc(chatId)
        .collection(FSPaths.messages)
        .doc();
    final msg = ChatMessage(
      messageId: msgRef.id,
      senderUid: senderUid,
      text: text,
      imageUrl: imageUrl,
    );
    final preview = imageUrl != null && text.isEmpty ? '📷 Photo' : text;
    final batch = _db.batch();
    batch.set(msgRef, msg.toMap());
    batch.update(_db.collection(FSPaths.chats).doc(chatId), {
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderUid': senderUid,
    });
    await batch.commit();
  }
}

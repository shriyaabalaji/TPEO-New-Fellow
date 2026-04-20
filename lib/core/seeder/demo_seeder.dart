import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import '../firestore/paths.dart';

class DemoSeeder {
  static final _db = FirebaseFirestore.instance;

  static const _seedMarker = 'seed_bevo_booked_v1';

  static Future<bool> isSeeded() async {
    final snap = await _db
        .collection(FSPaths.providerProfiles)
        .where('seedMarker', isEqualTo: _seedMarker)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> seed() async {
    if (await isSeeded()) return;

    final batch = _db.batch();

    // ── Business 1: Longhorn Portraits ──────────────────────────────────────
    final p1Ref = _db.collection(FSPaths.providerProfiles).doc();
    batch.set(p1Ref, {
      'providerProfileId': p1Ref.id,
      'ownerUid': 'seed_owner_portraits',
      'businessName': 'Longhorn Portraits',
      'tags': ['Photography'],
      'ratingAvg': 4.9,
      'reviewCount': 31,
      'seedMarker': _seedMarker,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final svc in [
      {'name': 'Portrait Session', 'price': r'$75', 'duration': 60, 'desc': 'Professional portrait session on or near campus.'},
      {'name': 'Event Photography', 'price': r'$150', 'duration': 120, 'desc': 'Full coverage for your event — graduation, org meetings, and more.'},
      {'name': 'Headshot Session', 'price': r'$50', 'duration': 45, 'desc': 'Clean, polished headshots for LinkedIn or your resume.'},
    ]) {
      final sRef = p1Ref.collection(FSPaths.services).doc();
      batch.set(sRef, {
        'serviceId': sRef.id,
        'providerProfileId': p1Ref.id,
        'name': svc['name'],
        'price': svc['price'],
        'durationMinutes': svc['duration'],
        'description': svc['desc'],
        'ratingAvg': 4.9,
        'reviewCount': 31,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ── Business 2: Hook 'Em Tutoring ────────────────────────────────────────
    final p2Ref = _db.collection(FSPaths.providerProfiles).doc();
    batch.set(p2Ref, {
      'providerProfileId': p2Ref.id,
      'ownerUid': 'seed_owner_tutoring',
      'businessName': "Hook 'Em Tutoring",
      'tags': ['Tutoring', 'Academic'],
      'ratingAvg': 4.8,
      'reviewCount': 47,
      'seedMarker': _seedMarker,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final svc in [
      {'name': '1-on-1 Tutoring', 'price': r'$30', 'duration': 60, 'desc': 'Personalized tutoring for any UT course.'},
      {'name': 'Exam Prep Session', 'price': r'$35', 'duration': 90, 'desc': 'Focused exam prep — practice problems, review, and strategy.'},
      {'name': 'Group Session (up to 4)', 'price': r'$15', 'duration': 60, 'desc': 'Split the cost with friends and study together.'},
    ]) {
      final sRef = p2Ref.collection(FSPaths.services).doc();
      batch.set(sRef, {
        'serviceId': sRef.id,
        'providerProfileId': p2Ref.id,
        'name': svc['name'],
        'price': svc['price'],
        'durationMinutes': svc['duration'],
        'description': svc['desc'],
        'ratingAvg': 4.8,
        'reviewCount': 47,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  static const _imageMap = [
    _SeedImage(
      asset: 'assets/seed_images/1.png',
      businessName: "Hook 'Em Tutoring",
      serviceName: 'Group Session (up to 4)',
    ),
    _SeedImage(
      asset: 'assets/seed_images/2.png',
      businessName: 'Longhorn Portraits',
      serviceName: 'Portrait Session',
    ),
    _SeedImage(
      asset: 'assets/seed_images/3.png',
      businessName: "Hook 'Em Tutoring",
      serviceName: '1-on-1 Tutoring',
    ),
    _SeedImage(
      asset: 'assets/seed_images/4.png',
      businessName: "Hook 'Em Tutoring",
      serviceName: 'Exam Prep Session',
    ),
    _SeedImage(
      asset: 'assets/seed_images/5.png',
      businessName: 'Longhorn Portraits',
      serviceName: 'Event Photography',
    ),
    _SeedImage(
      asset: 'assets/seed_images/6.png',
      businessName: 'Longhorn Portraits',
      serviceName: 'Headshot Session',
    ),
  ];

  static Future<void> uploadSeedImages() async {
    final storage = FirebaseStorage.instance;

    for (final entry in _imageMap) {
      // Find the provider
      final provSnap = await _db
          .collection(FSPaths.providerProfiles)
          .where('seedMarker', isEqualTo: _seedMarker)
          .where('businessName', isEqualTo: entry.businessName)
          .limit(1)
          .get();
      if (provSnap.docs.isEmpty) continue;

      // Find the service
      final svcSnap = await _db
          .collection(FSPaths.providerProfiles)
          .doc(provSnap.docs.first.id)
          .collection(FSPaths.services)
          .where('name', isEqualTo: entry.serviceName)
          .limit(1)
          .get();
      if (svcSnap.docs.isEmpty) continue;

      // Upload asset to Firebase Storage
      final bytes = await rootBundle.load(entry.asset);
      final ext = entry.asset.split('.').last;

      final ref = storage.ref(
          'seed_images/${entry.businessName}_${entry.serviceName}.$ext'
              .replaceAll(' ', '_'));
      await ref.putData(
        bytes.buffer.asUint8List(),
        SettableMetadata(contentType: 'image/$ext'),
      );
      final url = await ref.getDownloadURL();

      // Write bannerUrl to Firestore
      await svcSnap.docs.first.reference.update({'bannerUrl': url});
    }
  }
}

class _SeedImage {
  const _SeedImage({
    required this.asset,
    required this.businessName,
    required this.serviceName,
  });
  final String asset;
  final String businessName;
  final String serviceName;
}

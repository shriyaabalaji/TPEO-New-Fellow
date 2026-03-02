import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase_init.dart';
import '../firestore/paths.dart';

/// Uploads images to Firebase Storage and returns download URLs.
/// Paths: users/{uid}/avatar.jpg, providerProfiles/{id}/banner.jpg, providerProfiles/{id}/gallery/{name}.jpg
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool get isAvailable => firebaseInitialized;

  /// Upload user profile photo. Returns download URL or null if not initialized.
  Future<String?> uploadUserAvatar(String uid, File file) async {
    if (!isAvailable) return null;
    final ref = _storage.ref().child(FSPaths.users).child(uid).child('avatar.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Upload provider banner. Returns download URL or null.
  Future<String?> uploadProviderBanner(String providerProfileId, File file) async {
    if (!isAvailable) return null;
    final ref = _storage.ref().child(FSPaths.providerProfiles).child(providerProfileId).child('banner.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Upload one gallery image. Returns download URL or null.
  Future<String?> uploadProviderGalleryImage(String providerProfileId, File file, {String? name}) async {
    if (!isAvailable) return null;
    final fileName = name ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(FSPaths.providerProfiles).child(providerProfileId).child('gallery').child(fileName);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}

final storageServiceProvider = Provider<StorageService?>((ref) {
  return firebaseInitialized ? StorageService() : null;
});

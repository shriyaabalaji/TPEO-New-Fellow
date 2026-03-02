import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase_init.dart';
import '../../core/firestore/firestore_service.dart';
import '../../models/provider_profile.dart';
import '../auth/effective_user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Only available when Firebase has been initialized (e.g. after Firebase.initializeApp() in main).
final firestoreServiceProvider = Provider<FirestoreService?>((ref) {
  return firebaseInitialized ? FirestoreService() : null;
});

/// Current user's provider profiles (empty if not signed in, demo, or no Firebase).
/// Used by shell to show provider nav (Appointments, Availability, Profile) when viewing as provider.
final currentUserProviderProfilesProvider = StreamProvider<List<ProviderProfile>>((ref) {
  final user = ref.watch(effectiveUserProvider).valueOrNull;
  final fs = ref.watch(firestoreServiceProvider);
  if (user == null || user.isDemo || fs == null) return Stream.value([]);
  return fs.streamProviderProfilesByOwner(user.uid);
});

class ProviderAccountController {
  final FirestoreService _fs;
  final fb.User? _user;
  ProviderAccountController(this._fs, this._user);

  Future<void> createProvider(String businessName, List<String> tags) async {
    if (_user == null) throw Exception('Not signed in');
    final id = await _fs.createProviderProfile(ownerUid: _user!.uid, businessName: businessName, tags: tags);
    // set active
    await _fs.setActiveProviderProfile(uid: _user!.uid, providerProfileId: id);
  }
}

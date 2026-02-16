import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/firestore/paths.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

final firestoreServiceProvider = Provider((ref) => FirestoreService());

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

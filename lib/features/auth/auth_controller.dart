import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/firebase_init.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

final authServiceProvider = Provider<AuthService?>((ref) => firebaseInitialized ? AuthService() : null);
final authStateProvider = StreamProvider<fb.User?>((ref) {
  if (!firebaseInitialized) return Stream.value(null);
  final svc = ref.watch(authServiceProvider);
  if (svc == null) return Stream.value(null);
  return svc.authStateChanges();
});

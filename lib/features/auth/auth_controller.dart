import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

final authServiceProvider = Provider((ref) => AuthService());
final authStateProvider = StreamProvider<fb.User?>((ref) {
  final svc = ref.watch(authServiceProvider);
  return svc.authStateChanges();
});

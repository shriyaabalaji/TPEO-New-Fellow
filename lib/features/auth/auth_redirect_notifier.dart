import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import 'effective_user_provider.dart';

/// Notifier used by GoRouter's [refreshListenable] so redirect runs when
/// auth state or demo mode changes. Frontend-only; no Firebase config.
class AuthRedirectNotifier extends ChangeNotifier {
  bool _hasFirebaseUser = false;
  bool _authLoading = true;
  bool _demoMode = false;

  bool get hasFirebaseUser => _hasFirebaseUser;
  bool get authLoading => _authLoading;
  bool get demoMode => _demoMode;
  bool get isAuthenticated => _hasFirebaseUser || _demoMode;
  bool get shouldRedirectToLogin => !_authLoading && !isAuthenticated;

  void update({
    bool? hasFirebaseUser,
    bool? authLoading,
    bool? demoMode,
  }) {
    var changed = false;
    if (hasFirebaseUser != null && _hasFirebaseUser != hasFirebaseUser) {
      _hasFirebaseUser = hasFirebaseUser;
      changed = true;
    }
    if (authLoading != null && _authLoading != authLoading) {
      _authLoading = authLoading;
      changed = true;
    }
    if (demoMode != null && _demoMode != demoMode) {
      _demoMode = demoMode;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}

final authRedirectNotifierProvider = Provider<AuthRedirectNotifier>((ref) {
  final notifier = AuthRedirectNotifier();
  ref.listen(authStateProvider, (_, asyncUser) {
    notifier.update(
      hasFirebaseUser: asyncUser.valueOrNull != null,
      authLoading: asyncUser.isLoading,
    );
  });
  ref.listen(demoModeProvider, (_, demoMode) {
    notifier.update(demoMode: demoMode);
  });
  return notifier;
});

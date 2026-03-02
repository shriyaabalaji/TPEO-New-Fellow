import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'auth_controller.dart';

const String _keyDemoMode = 'utserve_demo_mode';
const String _keyDemoDisplayName = 'utserve_demo_display_name';
const String _keyDemoEmail = 'utserve_demo_email';
const String demoUid = 'demo_local';

/// Represents the current user: either signed in via Firebase or demo (local).
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.isDemo,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isDemo;

  static AppUser fromFirebaseUser(fb.User u) {
    return AppUser(
      uid: u.uid,
      displayName: u.displayName ?? u.email ?? 'User',
      email: u.email ?? '',
      photoUrl: u.photoURL,
      isDemo: false,
    );
  }
}

/// Whether the app is in demo mode (Skip demo was used).
class DemoModeNotifier extends StateNotifier<bool> {
  DemoModeNotifier() : super(false) {
    _load();
  }

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _load() async {
    final prefs = await _prefs();
    state = prefs.getBool(_keyDemoMode) ?? false;
  }

  Future<void> enterDemo() async {
    final prefs = await _prefs();
    await prefs.setBool(_keyDemoMode, true);
    await prefs.setString(_keyDemoDisplayName, 'Demo User');
    await prefs.setString(_keyDemoEmail, 'demo@utexas.edu');
    state = true;
  }

  Future<void> exitDemo() async {
    final prefs = await _prefs();
    await prefs.remove(_keyDemoMode);
    await prefs.remove(_keyDemoDisplayName);
    await prefs.remove(_keyDemoEmail);
    state = false;
  }
}

final demoModeProvider = StateNotifierProvider<DemoModeNotifier, bool>((ref) => DemoModeNotifier());

/// Current user: Firebase user if signed in, otherwise demo user if demo mode is on.
final effectiveUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState != null) {
    return AppUser.fromFirebaseUser(authState);
  }
  final isDemo = ref.watch(demoModeProvider);
  if (!isDemo) return null;
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString(_keyDemoDisplayName) ?? 'Demo User';
  final email = prefs.getString(_keyDemoEmail) ?? 'demo@utexas.edu';
  return AppUser(uid: demoUid, displayName: name, email: email, photoUrl: null, isDemo: true);
});

// Demo-mode-only: simple appointment for Appointments page
class DemoAppointment {
  const DemoAppointment({required this.id, required this.title, required this.subtitle, this.status = 'confirmed'});
  final String id;
  final String title;
  final String subtitle;
  final String status;
}

const String _keyDemoAppointments = 'utserve_demo_appointments';
const String _demoAppointmentsSeparator = '|||';

class DemoAppointmentsNotifier extends StateNotifier<List<DemoAppointment>> {
  DemoAppointmentsNotifier() : super([]) {
    _load();
  }

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_keyDemoAppointments);
    if (raw == null || raw.isEmpty) {
      state = [
        const DemoAppointment(id: 'd1', title: 'Demo appointment 1', subtitle: 'Nail art · Tomorrow 2pm'),
        const DemoAppointment(id: 'd2', title: 'Demo appointment 2', subtitle: 'Haircut · Next week'),
      ];
      await _save();
      return;
    }
    final parts = raw.split(_demoAppointmentsSeparator);
    state = [];
    for (var i = 0; i + 3 <= parts.length; i += 4) {
      state = [...state, DemoAppointment(id: parts[i], title: parts[i + 1], subtitle: parts[i + 2], status: parts[i + 3])];
    }
  }

  Future<void> _save() async {
    final prefs = await _prefs();
    final buf = state.map((a) => '${a.id}$_demoAppointmentsSeparator${a.title}$_demoAppointmentsSeparator${a.subtitle}$_demoAppointmentsSeparator${a.status}').join(_demoAppointmentsSeparator);
    await prefs.setString(_keyDemoAppointments, buf);
  }

  Future<void> add(DemoAppointment a) async {
    state = [...state, a];
    await _save();
  }
}

final demoAppointmentsProvider = StateNotifierProvider<DemoAppointmentsNotifier, List<DemoAppointment>>((ref) => DemoAppointmentsNotifier());

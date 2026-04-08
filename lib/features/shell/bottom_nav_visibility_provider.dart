import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls whether the floating bottom nav is shown in [MainShell].
final bottomNavVisibleProvider = StateProvider<bool>((ref) => true);

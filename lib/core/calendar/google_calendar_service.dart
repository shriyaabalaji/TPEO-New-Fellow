import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;

import '../../utils/slot_label_parser.dart';

/// Optional Google Calendar via [GoogleSignIn] — separate from Firebase email/password.
///
/// Uses `google_sign_in` v7 ([GoogleSignIn.instance]). Call [initialize] once at startup
/// or rely on lazy init in [signInAndAuthorize] / [insertBookingEvent].
///
/// **iOS:** Add `CFBundleURLTypes` with your OAuth client’s `REVERSED_CLIENT_ID` from
/// Google Cloud Console, and enable the Google Calendar API for the project.
class GoogleCalendarService {
  static const scopes = <String>[
    'https://www.googleapis.com/auth/calendar.events',
  ];

  bool _initialized = false;

  /// Must complete before other Google Sign-In calls. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize();
    _initialized = true;
  }

  Future<void> _ensureInit() async {
    await initialize();
  }

  /// Interactive sign-in + Calendar scope. Use when user taps Connect in settings.
  Future<GoogleSignInAccount> signInAndAuthorize() async {
    await _ensureInit();
    final account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    await account.authorizationClient.authorizeScopes(scopes);
    return account;
  }

  Future<void> disconnect() async {
    await _ensureInit();
    await GoogleSignIn.instance.disconnect();
  }

  Future<GoogleSignInAccount> _accountForCalendar({required bool allowInteractiveAuth}) async {
    await _ensureInit();
    final lightweight = GoogleSignIn.instance.attemptLightweightAuthentication();
    GoogleSignInAccount? account;
    if (lightweight != null) {
      account = await lightweight;
    }
    if (account == null) {
      if (!allowInteractiveAuth) {
        throw StateError(
          'Google Calendar session expired. Open Account → Connect Google Calendar again.',
        );
      }
      account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    }
    return account;
  }

  Future<gapis.AuthClient> _authorizedClient(GoogleSignInAccount account) async {
    final authz = await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    return authz.authClient(scopes: scopes);
  }

  /// Creates an event on the user’s primary calendar. Uses [slotLabel] for time when parseable.
  Future<void> insertBookingEvent({
    required String summary,
    required String slotLabel,
    String? description,
    int durationMinutes = 30,
  }) async {
    final account = await _accountForCalendar(allowInteractiveAuth: true);
    final client = await _authorizedClient(account);
    try {
      final api = cal.CalendarApi(client);
      final range = parseSlotLabelToRange(slotLabel, durationMinutes: durationMinutes);
      final start = range?.start ?? DateTime.now();
      final end = range?.end ?? start.add(Duration(minutes: durationMinutes));
      final body = <String>[
        if (description != null && description.isNotEmpty) description,
        'Time: $slotLabel',
      ].join('\n\n');
      final event = cal.Event()
        ..summary = summary
        ..description = body.isEmpty ? slotLabel : body
        ..start = cal.EventDateTime(dateTime: start.toUtc())
        ..end = cal.EventDateTime(dateTime: end.toUtc());
      await api.events.insert(event, 'primary');
    } finally {
      client.close();
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/firebase_init.dart';
import 'core/notifications/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseInitialized = true;
  } catch (e) {
    firebaseInitialized = false;
    if (kDebugMode) {
      debugPrint('Firebase not configured: $e');
      debugPrint('Run: flutterfire configure');
    }
  }
  runApp(const ProviderScope(child: MyApp()));
}

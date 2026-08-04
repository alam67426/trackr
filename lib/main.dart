import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/local_intelligence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalIntelligenceService.instance.warmUp();
  try {
    await NotificationService.instance.init();
  } catch (error) {
    // Notifications are optional at launch; never leave the app on the splash
    // screen if the device cannot initialise the notification plugin.
    debugPrint('Notification initialisation failed: $error');
  }
  runApp(const ProviderScope(child: TrackrApp()));
}

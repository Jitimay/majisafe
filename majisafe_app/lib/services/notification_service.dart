import 'package:flutter/foundation.dart';

/// Placeholder for FCM/local notifications (not wired in MVP).
class NotificationService {
  /// No-op init for future push registration.
  Future<void> init() async {
    if (kDebugMode) {
      debugPrint('NotificationService: init (stub)');
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] to re-run redirect when a stream emits (e.g. auth state).
class GoRouterRefreshStream extends ChangeNotifier {
  /// Subscribes to [stream] and calls [notifyListeners] on each event.
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

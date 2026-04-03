import 'package:flutter/material.dart';

/// Root messenger so SnackBars survive route changes (e.g. register → home).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

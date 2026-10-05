import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/admob_ad_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget: ad setup must never delay or break app startup.
  unawaited(AdMobAdService.instance.initialize());
  runApp(const MediaMintApp());
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/window.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:window_manager/window_manager.dart';

import 'app/my_app.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Hide the default big window on startup
  WindowOptions windowOptions = const WindowOptions(
    size: Size(596, 768),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setMinimumSize(const Size(360, 520));
    await windowManager.hide();
  });

  if (Platform.isMacOS) {
    await Window.setEffect(effect: WindowEffect.acrylic);
  } else if (Platform.isWindows) {
    // Tabbed is the modern Windows 11 Mica material.
    // You can also try WindowEffect.acrylic or WindowEffect.mica
    await Window.setEffect(
      effect: WindowEffect.tabbed,
      color: Colors.transparent,
    );
  }

  runApp(const ByteBuddyApp());
}

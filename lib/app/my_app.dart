import 'package:bb/app/provider/companion_provider.dart';
import 'package:bb/app/provider/hardware_monitor_provider.dart';
import 'package:bb/app/view/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ByteBuddyApp extends StatelessWidget {
  const ByteBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HardwareMonitorProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => CompanionProvider(
            context.read<HardwareMonitorProvider>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'ByteBuddy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.transparent,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF79F2C4),
            secondary: Color(0xFFFFC857),
            surface: Color(0xFF101418),
          ),
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

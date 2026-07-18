import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/state_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateService()),
      ],
      child: const OurCommitteeApp(),
    ),
  );
}

class OurCommitteeApp extends StatelessWidget {
  const OurCommitteeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Our Committee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

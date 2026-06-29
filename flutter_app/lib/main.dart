import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app/colors.dart';
import 'app/home_page.dart';
import 'data/dashboard_snapshot.dart';
import 'views/onboarding_view.dart';

void main() {
  runApp(const TrafficOperatorApp());
}

class TrafficOperatorApp extends StatefulWidget {
  const TrafficOperatorApp({super.key});

  @override
  State<TrafficOperatorApp> createState() => _TrafficOperatorAppState();
}

class _TrafficOperatorAppState extends State<TrafficOperatorApp> {
  // GlobalKey for the root ScaffoldMessenger. Wired into MaterialApp so that
  // SnackBars and dialogs from anywhere in the tree resolve correctly (web,
  // mobile, and desktop). Earlier this key was attached as Scaffold.key,
  // which silently failed at runtime because Scaffold does not host a
  // ScaffoldMessenger element.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final home = TrafficHomePage(messengerKey: _messengerKey);
    final gate = OnboardingGate(home: home);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'IoT Traffic Light',
        theme: const CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.accent,
          scaffoldBackgroundColor: AppColors.background,
          barBackgroundColor: AppColors.surface,
        ),
        home: gate,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      title: 'IoT Traffic Light',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.foreground,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.glass,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.accent.withValues(alpha: 0.16),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.muted,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.glass,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        textTheme: Typography.whiteMountainView.apply(
          bodyColor: AppColors.foreground,
          displayColor: AppColors.foreground,
        ),
      ),
      home: gate,
    );
  }
}



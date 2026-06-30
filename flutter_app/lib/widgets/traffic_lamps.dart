import 'package:flutter/material.dart';

import '../app/colors.dart';

class TrafficLampStack extends StatelessWidget {
  const TrafficLampStack(
      {required this.activeColor, this.large = true, super.key});

  final String activeColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 96.0 : 30.0;
    final gap = large ? 12.0 : 4.0;
    return Container(
      width: large ? 180 : 58,
      padding: EdgeInsets.all(large ? 20 : 7),
      decoration: BoxDecoration(
        color: const Color(0xDD111111),
        borderRadius: BorderRadius.circular(large ? 28 : 12),
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignalLamp(color: 'RED', active: activeColor == 'RED', size: size),
          SizedBox(height: gap),
          SignalLamp(
              color: 'YELLOW', active: activeColor == 'YELLOW', size: size),
          SizedBox(height: gap),
          SignalLamp(
              color: 'GREEN', active: activeColor == 'GREEN', size: size),
        ],
      ),
    );
  }
}

class SignalLamp extends StatelessWidget {
  const SignalLamp({
    required this.color,
    required this.active,
    required this.size,
    super.key,
  });

  final String color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = switch (color) {
      'RED' => AppColors.danger,
      'YELLOW' => AppColors.warn,
      'GREEN' => AppColors.success,
      _ => AppColors.muted,
    };
    final glow = switch (color) {
      'RED' => AppColors.redGlow,
      'YELLOW' => AppColors.yellowGlow,
      'GREEN' => AppColors.greenGlow,
      _ => null,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? base : const Color(0xFF1A1A1A),
        border: Border.all(
          color: active ? base : AppColors.surface2,
          width: 2,
        ),
        boxShadow: active && glow != null
            ? [
                BoxShadow(
                  color: glow,
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : const [],
      ),
    );
  }
}

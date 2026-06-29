import 'package:flutter/material.dart';

import '../app/colors.dart';

class TrafficLampStack extends StatelessWidget {
  const TrafficLampStack({required this.activeColor, this.large = true, super.key});

  final String activeColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 96.0 : 42.0;
    return Container(
      width: large ? 180 : 76,
      padding: EdgeInsets.all(large ? 20 : 10),
      decoration: BoxDecoration(
        color: const Color(0xDD111111),
        borderRadius: BorderRadius.circular(large ? 28 : 14),
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignalLamp(color: 'RED', active: activeColor == 'RED', size: size),
          SizedBox(height: large ? 12 : 6),
          SignalLamp(
              color: 'YELLOW', active: activeColor == 'YELLOW', size: size),
          SizedBox(height: large ? 12 : 6),
          SignalLamp(color: 'GREEN', active: activeColor == 'GREEN', size: size),
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
        boxShadow: active
            ? [
                BoxShadow(
                  color: base.withValues(alpha: 0.42),
                  blurRadius: size * 0.34,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
    );
  }
}


class ModeChip extends StatelessWidget {
  const ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.glass,
      side: BorderSide(
        color: active ? AppColors.accent : AppColors.glassBorder,
      ),
      labelStyle: TextStyle(
        color: active ? Colors.white : AppColors.foreground2,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}


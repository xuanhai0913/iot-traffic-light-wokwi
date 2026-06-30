import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/colors.dart';

const String _kOnboardingKey = 'onboarding_seen_v1';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({required this.home, super.key});

  final Widget home;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _seen = prefs.getBool(_kOnboardingKey) ?? false;
    });
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
    if (!mounted) return;
    setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      return const _SplashScreen();
    }
    if (_seen == false) {
      return OnboardingScreen(
        onSkip: _complete,
        onStart: _complete,
      );
    }
    return widget.home;
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.background,
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.onSkip,
    required this.onStart,
    super.key,
  });

  final VoidCallback onSkip;
  final VoidCallback onStart;

  static const _modes = <_ModeSpec>[
    _ModeSpec(
      glyph: '↻',
      iconColor: AppColors.success,
      iconBg: Color(0x3334C759),
      name: 'AUTO',
      desc: 'Chu kỳ tự động lần lượt qua pha Bắc-Nam xanh/vàng rồi '
          'Đông-Tây xanh/vàng. Thời gian lấy từ chu kỳ đang kích hoạt '
          'trên backend.',
      tag: 'MẶC ĐỊNH',
      tagColor: AppColors.success,
      tagBg: Color(0x2634C759),
    ),
    _ModeSpec(
      glyph: '🌙',
      iconColor: AppColors.foreground2,
      iconBg: Color(0x33636666),
      name: 'NIGHT',
      desc: 'Chế độ ban đêm: đèn vàng nhấp nháy liên tục. Giảm năng lượng, '
          'cảnh báo phương tiện giảm tốc qua ngã tư.',
    ),
    _ModeSpec(
      glyph: '⬆',
      iconColor: AppColors.accent,
      iconBg: Color(0x330071E3),
      name: 'PRIORITY_NS',
      desc: 'Giữ XANH cho hướng Bắc-Nam và ĐỎ cho hướng Đông-Tây '
          'cho tới khi người vận hành chuyển sang chế độ khác.',
    ),
    _ModeSpec(
      glyph: '➡',
      iconColor: AppColors.accent,
      iconBg: Color(0x330071E3),
      name: 'PRIORITY_EW',
      desc: 'Giữ XANH cho hướng Đông-Tây và ĐỎ cho hướng Bắc-Nam '
          'cho tới khi người vận hành chuyển sang chế độ khác.',
    ),
    _ModeSpec(
      glyph: '⚠',
      iconColor: AppColors.danger,
      iconBg: Color(0x33FF3B30),
      name: 'EMERGENCY',
      desc: 'Tất cả các hướng giữ ĐỎ cho tới khi người vận hành '
          'chuyển về AUTO hoặc NIGHT.',
      tag: 'KHẨN CẤP',
      tagColor: AppColors.danger,
      tagBg: Color(0x26FF3B30),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppColors.space5,
                AppColors.space6,
                AppColors.space5,
                AppColors.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chế độ hoạt động',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppColors.space2),
                  Text(
                    'TrafficLight-IoT có 5 chế độ điều khiển đèn giao thông',
                    style: TextStyle(
                      color: AppColors.foreground2,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppColors.space5,
                  vertical: AppColors.space2,
                ),
                itemCount: _modes.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppColors.space3),
                itemBuilder: (_, i) => _OnboardingModeCard(mode: _modes[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppColors.space5,
                AppColors.space3,
                AppColors.space5,
                AppColors.space4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSkip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground2,
                        side: const BorderSide(color: AppColors.glassBorder),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppColors.space4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusMd),
                        ),
                      ),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: AppColors.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: onStart,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppColors.space4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Bắt đầu',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingModeCard extends StatelessWidget {
  const _OnboardingModeCard({required this.mode});

  final _ModeSpec mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppColors.space4),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mode.iconBg,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: Text(
              mode.glyph,
              style: TextStyle(
                color: mode.iconColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppColors.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      mode.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (mode.tag != null) ...[
                      const SizedBox(width: AppColors.space2),
                      _Tag(
                        text: mode.tag!,
                        color: mode.tagColor!,
                        bg: mode.tagBg!,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppColors.space2),
                Text(
                  mode.desc,
                  style: const TextStyle(
                    color: AppColors.foreground2,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, required this.bg});

  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ModeSpec {
  const _ModeSpec({
    required this.glyph,
    required this.iconColor,
    required this.iconBg,
    required this.name,
    required this.desc,
    this.tag,
    this.tagColor,
    this.tagBg,
  });

  final String glyph;
  final Color iconColor;
  final Color iconBg;
  final String name;
  final String desc;
  final String? tag;
  final Color? tagColor;
  final Color? tagBg;
}

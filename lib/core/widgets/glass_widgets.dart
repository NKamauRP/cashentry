import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MistyBackground extends StatelessWidget {
  const MistyBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF252A30), Color(0xFF191D21)]
                  : const [Color(0xFFF1F3F6), Color(0xFFDDE3E7)],
            ),
          ),
        ),
        Positioned(
          left: -70,
          top: -60,
          child: _GlowOrb(color: AppColors.teal.withValues(alpha: 0.23), size: 220),
        ),
        Positioned(
          right: -90,
          bottom: 40,
          child: _GlowOrb(color: Colors.cyanAccent.withValues(alpha: 0.1), size: 260),
        ),
        child,
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.onTap,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final borderColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.65);

    final bgColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.45);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: AppColors.teal.withValues(alpha: 0.24),
              blurRadius: 22,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: bgColor,
            child: InkWell(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: borderColor),
                ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlowNavItem extends StatelessWidget {
  const GlowNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : Theme.of(context).colorScheme.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.32),
                  blurRadius: 12,
                ),
              ]
            : null,
        color: active ? AppColors.teal.withValues(alpha: 0.16) : Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

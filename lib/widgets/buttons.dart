import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary cyan call-to-action.
class CyanButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const CyanButton(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cyanBright, AppColors.cyanDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(label,
                style: AppText.chakra(size: 15, weight: FontWeight.w700, color: AppColors.ink, spacing: 1.5)),
          ),
        ),
      ),
    );
  }
}

/// Outlined / ghost button.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool expand;
  const GhostButton(this.label,
      {super.key, this.onTap, this.color = AppColors.textSoft, this.icon, this.expand = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expand ? double.infinity : null,
      height: 52,
      decoration: BoxDecoration(
        color: color == AppColors.textSoft ? Colors.white.withOpacity(0.06) : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color == AppColors.textSoft ? Colors.white.withOpacity(0.14) : color.withOpacity(0.55)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 8)],
                Text(label, style: AppText.chakra(size: 13, weight: FontWeight.w600, color: color, spacing: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

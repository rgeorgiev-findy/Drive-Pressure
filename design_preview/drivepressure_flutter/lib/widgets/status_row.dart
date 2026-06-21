import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Faux status row mirroring the comps. Remove to use the real system bar.
class StatusRow extends StatelessWidget {
  const StatusRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('9:41', style: AppText.mono(size: 14, color: AppColors.text)),
          Text('100%', style: AppText.mono(size: 12, color: AppColors.dim)),
        ],
      ),
    );
  }
}

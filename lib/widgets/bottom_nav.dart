import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const AppBottomNav({super.key, required this.current, required this.onTap});

  static const List<(IconData, String)> _items = [
    (Icons.home_filled, 'HOME'),
    (Icons.notifications_none_rounded, 'ALERTS'),
    (Icons.tune_rounded, 'LIMITS'),
    (Icons.settings_rounded, 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 12, bottom: 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _items.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_items[i].$1, size: 22, color: i == current ? AppColors.cyan : AppColors.muted),
                  const SizedBox(height: 5),
                  Text(_items[i].$2,
                      style: AppText.mono(size: 9, color: i == current ? AppColors.cyan : AppColors.muted, spacing: 0.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

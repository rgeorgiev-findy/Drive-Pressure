import 'package:flutter/material.dart';

/// Empty status row — system status bar is shown by the OS itself.
class StatusRow extends StatelessWidget {
  const StatusRow({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

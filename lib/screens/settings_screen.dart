import 'dart:async';
import 'package:flutter/material.dart';
import '../services/vehicle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/glass.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Vehicle> _vehicles = [];
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _reload();
    _sub = VehicleService.instance.changes.listen((_) => _reload());
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _vehicles = VehicleService.instance.vehicles);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cars = _vehicles.where((v) => v.type == VehicleType.car).toList();
    final trailers =
        _vehicles.where((v) => v.type.isTrailer).toList();

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FLEET CONFIG',
                      style: AppText.mono(
                          size: 10, color: AppColors.dimmer, spacing: 2)),
                  const SizedBox(height: 2),
                  Text('Settings',
                      style: AppText.chakra(size: 24, color: AppColors.text)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  // ── Cars section ───────────────────────────────────────────
                  _sectionHeader(
                    icon: Icons.directions_car_rounded,
                    label: 'CARS',
                    color: AppColors.cyan,
                    onAdd: _addCarDialog,
                  ),
                  if (cars.isEmpty)
                    _emptyHint('No cars added yet')
                  else
                    ...cars.map((v) => _vehicleTile(v)),

                  const SizedBox(height: 24),

                  // ── Trailers section ───────────────────────────────────────
                  _sectionHeader(
                    icon: Icons.rv_hookup_rounded,
                    label: 'TRAILERS',
                    color: AppColors.amber,
                    onAdd: _addTrailerDialog,
                  ),
                  if (trailers.isEmpty)
                    _emptyHint('No trailers added yet')
                  else
                    ...trailers.map((v) => _vehicleTile(v)),

                  const SizedBox(height: 24),

                  // ── Info row ───────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.muted.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Text('Select active vehicle on the Home tab',
                          style: AppText.mono(
                              size: 11, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: AppText.mono(size: 10, color: color, spacing: 2)),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withOpacity(0.10),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text('ADD',
                      style: AppText.mono(size: 10, color: color, spacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vehicle tile ──────────────────────────────────────────────────────────

  Widget _vehicleTile(Vehicle vehicle) {
    final isTrailer = vehicle.type.isTrailer;
    final color = isTrailer ? AppColors.amber : AppColors.cyan;
    final icon =
        isTrailer ? Icons.rv_hookup_rounded : Icons.directions_car_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        blur: false,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withOpacity(0.12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.name,
                      style:
                          AppText.chakra(size: 15, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(vehicle.type.label,
                      style: AppText.mono(
                          size: 10, color: AppColors.dimmer, spacing: 0.5)),
                ],
              ),
            ),
            // Wheel count badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Text(
                '${vehicle.type.positions.length}W',
                style: AppText.mono(
                    size: 10, color: AppColors.dimmer, spacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            // Delete button
            GestureDetector(
              onTap: () => _confirmDelete(vehicle),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.red.withOpacity(0.08),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: AppColors.redText.withOpacity(0.7), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.03),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Center(
            child: Text(text,
                style: AppText.mono(size: 11, color: AppColors.muted)),
          ),
        ),
      );

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _addCarDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: 'Add Car',
        icon: Icons.directions_car_rounded,
        iconColor: AppColors.cyan,
        content: _nameField(nameCtrl, 'e.g. My Truck'),
        actions: [
          _dialogBtn('Cancel', AppColors.dimmer,
              () => Navigator.pop(ctx)),
          _dialogBtn('ADD', AppColors.cyan, () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            await VehicleService.instance
                .addVehicle(name, VehicleType.car);
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }

  void _addTrailerDialog() {
    final nameCtrl = TextEditingController();
    VehicleType selectedType = VehicleType.trailer2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _StyledDialog(
          title: 'Add Trailer',
          icon: Icons.rv_hookup_rounded,
          iconColor: AppColors.amber,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _nameField(nameCtrl, 'e.g. Box Trailer'),
              const SizedBox(height: 16),
              Text('Wheel count',
                  style: AppText.mono(
                      size: 10, color: AppColors.dimmer, spacing: 1)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _typeChip('2 wheels', VehicleType.trailer2,
                      selectedType, AppColors.amber, (t) {
                    setDialogState(() => selectedType = t);
                  }),
                  const SizedBox(width: 10),
                  _typeChip('4 wheels', VehicleType.trailer4,
                      selectedType, AppColors.amber, (t) {
                    setDialogState(() => selectedType = t);
                  }),
                ],
              ),
            ],
          ),
          actions: [
            _dialogBtn('Cancel', AppColors.dimmer,
                () => Navigator.pop(ctx)),
            _dialogBtn('ADD', AppColors.amber, () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await VehicleService.instance
                  .addVehicle(name, selectedType);
              if (ctx.mounted) Navigator.pop(ctx);
            }),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: 'Delete Vehicle',
        icon: Icons.delete_outline_rounded,
        iconColor: AppColors.redText,
        content: Text(
          'Remove "${vehicle.name}"? All paired sensors for this vehicle will be forgotten.',
          style: AppText.mono(size: 12, color: AppColors.dim),
        ),
        actions: [
          _dialogBtn('Cancel', AppColors.dimmer,
              () => Navigator.pop(ctx)),
          _dialogBtn('DELETE', AppColors.redText, () async {
            await VehicleService.instance.removeVehicle(vehicle.id);
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }

  // ── Small widget helpers ──────────────────────────────────────────────────

  Widget _nameField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      autofocus: true,
      style: AppText.chakra(size: 15, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.mono(size: 13, color: AppColors.muted),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.cyan)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.cyan, width: 2)),
      ),
    );
  }

  Widget _typeChip(
    String label,
    VehicleType type,
    VehicleType selected,
    Color color,
    ValueChanged<VehicleType> onSelect,
  ) {
    final active = type == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? color.withOpacity(0.14) : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: active ? color.withOpacity(0.5) : Colors.white.withOpacity(0.10),
            ),
          ),
          child: Center(
            child: Text(label,
                style: AppText.mono(
                    size: 11,
                    color: active ? color : AppColors.dimmer,
                    spacing: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _dialogBtn(String label, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(label, style: AppText.chakra(size: 13, color: color)),
    );
  }
}

// ── Shared styled dialog ──────────────────────────────────────────────────────

class _StyledDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;
  final List<Widget> actions;

  const _StyledDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withOpacity(0.14),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: AppText.chakra(size: 17, color: AppColors.text)),
        ],
      ),
      content: content,
      actions: actions,
    );
  }
}

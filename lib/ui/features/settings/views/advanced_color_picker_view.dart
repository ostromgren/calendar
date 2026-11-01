import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import '../../../../providers.dart';

class AdvancedColorPickerView extends ConsumerStatefulWidget {
  const AdvancedColorPickerView({super.key});

  @override
  ConsumerState<AdvancedColorPickerView> createState() =>
      _AdvancedColorPickerViewState();
}

class _AdvancedColorPickerViewState
    extends ConsumerState<AdvancedColorPickerView> {
  late HSVColor _selectedColor;
  late final TextEditingController _hexController;

  Color get _color => _selectedColor.toColor();

  @override
  void initState() {
    super.initState();
    _selectedColor = HSVColor.fromColor(
      ref.read(themeViewModelProvider).customThemeColor,
    );
    _hexController = TextEditingController(text: _hexValue(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateColor(HSVColor color) {
    setState(() {
      _selectedColor = color;
      _hexController.value = TextEditingValue(
        text: _hexValue(color.toColor()),
        selection: TextSelection.collapsed(
          offset: _hexValue(color.toColor()).length,
        ),
      );
    });
  }

  void _updateHex(String value) {
    final normalized = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) return;
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed == null) return;
    setState(() {
      _selectedColor = HSVColor.fromColor(Color(parsed));
    });
  }

  String _hexValue(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.advancedColor)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.advancedColorDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: _HueRing(
                hue: _selectedColor.hue,
                selectedColor: _color,
                onHueChanged: (hue) => _updateColor(
                  _selectedColor
                      .withHue(hue)
                      .withSaturation(
                        _selectedColor.saturation < 0.8
                            ? 0.8
                            : _selectedColor.saturation,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.colorBrightness,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            key: const ValueKey('custom-color-brightness'),
            value: _selectedColor.value,
            min: 0,
            max: 1,
            divisions: 40,
            activeColor: _color,
            onChanged: (value) => _updateColor(_selectedColor.withValue(value)),
          ),
          TextField(
            key: const ValueKey('custom-color-hex'),
            controller: _hexController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.colorHex,
              prefixIcon: Icon(Icons.tag, color: _color),
              border: const OutlineInputBorder(),
            ),
            onChanged: _updateHex,
          ),
          const SizedBox(height: 20),
          _ColorPreview(color: _color),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('apply-custom-color'),
            onPressed: () {
              ref.read(themeViewModelProvider).setCustomThemeColor(_color);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check),
            label: Text(l10n.applyColor),
          ),
        ],
      ),
    );
  }
}

class _HueRing extends StatelessWidget {
  const _HueRing({
    required this.hue,
    required this.selectedColor,
    required this.onHueChanged,
  });

  final double hue;
  final Color selectedColor;
  final ValueChanged<double> onHueChanged;

  void _handlePosition(Offset position, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final offset = position - center;
    if (offset.distance < size.width * 0.27 ||
        offset.distance > size.width * 0.52) {
      return;
    }
    final radians = math.atan2(offset.dy, offset.dx);
    final degrees = (radians * 180 / math.pi + 90 + 360) % 360;
    onHueChanged(degrees);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        key: const ValueKey('custom-color-hue-ring'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _handlePosition(details.localPosition, size),
        onPanStart: (details) => _handlePosition(details.localPosition, size),
        onPanUpdate: (details) => _handlePosition(details.localPosition, size),
        child: CustomPaint(
          painter: _HueRingPainter(
            hue: hue,
            centerColor: HSVColor.fromAHSV(1, hue, 0.8, 1).toColor(),
            surfaceColor: Theme.of(context).colorScheme.surface,
            outlineColor: Theme.of(context).colorScheme.outlineVariant,
          ),
          child: Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectedColor,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HSVColor.fromAHSV(
                      1,
                      hue,
                      0.8,
                      1,
                    ).toColor().withAlpha(80),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _HueRingPainter extends CustomPainter {
  const _HueRingPainter({
    required this.hue,
    required this.centerColor,
    required this.surfaceColor,
    required this.outlineColor,
  });

  final double hue;
  final Color centerColor;
  final Color surfaceColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final ringWidth = radius * 0.19;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - ringWidth / 2,
    );
    final colors = List<Color>.generate(
      13,
      (index) => HSVColor.fromAHSV(1, index * 30, 0.92, 1).toColor(),
    );
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: colors,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;
    canvas.drawCircle(center, radius - ringWidth / 2, paint);

    canvas.drawCircle(
      center,
      radius - ringWidth,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final radians = (hue - 90) * math.pi / 180;
    final markerCenter = Offset(
      center.dx + math.cos(radians) * (radius - ringWidth / 2),
      center.dy + math.sin(radians) * (radius - ringWidth / 2),
    );
    canvas.drawCircle(
      markerCenter,
      ringWidth * 0.42,
      Paint()
        ..color = centerColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      markerCenter,
      ringWidth * 0.42,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) =>
      hue != oldDelegate.hue ||
      centerColor != oldDelegate.centerColor ||
      surfaceColor != oldDelegate.surfaceColor ||
      outlineColor != oldDelegate.outlineColor;
}

class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Theme.of(context).brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.livePreview,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey('custom-color-preview-button'),
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  child: const Text('Button'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

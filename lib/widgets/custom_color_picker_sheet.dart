import 'package:flutter/material.dart';

class CustomColorPickerSheet extends StatefulWidget {
  final Color? initialColor;
  final Function(Color) onColorSelected;

  const CustomColorPickerSheet({
    super.key,
    this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<CustomColorPickerSheet> createState() => _CustomColorPickerSheetState();
}

class _CustomColorPickerSheetState extends State<CustomColorPickerSheet> {
  late Color _currentColor;
  double _hue = 0;
  double _saturation = 0.7;
  double _lightness = 0.6;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor ?? Colors.blue;
    final hsvColor = HSVColor.fromColor(_currentColor);
    _hue = hsvColor.hue;
    _saturation = hsvColor.saturation;
    _lightness = hsvColor.value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '自定义颜色',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _currentColor.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSliderRow(
            '色相',
            _hue,
            0,
            360,
            (value) => setState(() {
              _hue = value;
              _updateColor();
            }),
            isHueSlider: true,
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            '饱和度',
            _saturation * 100,
            0,
            100,
            (value) => setState(() {
              _saturation = value / 100;
              _updateColor();
            }),
            displayValue: '${(_saturation * 100).toInt()}%',
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            '亮度',
            _lightness * 100,
            0,
            100,
            (value) => setState(() {
              _lightness = value / 100;
              _updateColor();
            }),
            displayValue: '${(_lightness * 100).toInt()}%',
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${_currentColor.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onColorSelected(_currentColor);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(0, 122, 89, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateColor() {
    setState(() {
      _currentColor = _hslToColor(_hue, _saturation, _lightness);
    });
  }

  Color _hslToColor(double h, double s, double l) {
    final r = _hueToRgb((h / 360) + (1.0 / 3.0), s, l);
    final g = _hueToRgb((h / 360), s, l);
    final b = _hueToRgb((h / 360) - (1.0 / 3.0), s, l);

    return Color.fromRGBO(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      1.0,
    );
  }

  double _hueToRgb(double t1, double t2, double hue) {
    double h = hue;
    if (h < 0) h += 1;
    if (h > 1) h -= 1;

    if (h < (1.0 / 6.0)) return t2 + (t1 - t2) * 6.0 * h;
    if (h < (1.0 / 2.0)) return t1;
    if (h < (2.0 / 3.0)) return t2 + (t1 - t2) * ((2.0 / 3.0) - h) * 6.0;

    return t2;
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged, {
    bool isHueSlider = false,
    String? displayValue,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: isHueSlider ? null : _currentColor,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            displayValue ?? value.toInt().toString(),
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

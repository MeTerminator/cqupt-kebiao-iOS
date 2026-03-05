import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ColorExtensions {
  static Color dynamicCourseColor({required int index, required int total}) {
    if (total <= 0) return Colors.blue;
    
    final safeIndex = index.abs() % total;
    const step = 7;
    final steppedIndex = (safeIndex * step) % total;
    final hue = steppedIndex / total;
    
    return HSVColor.fromAHSV(1.0, hue * 360, 0.7, 0.6).toColor();
  }

  static Color dynamicCourseColorSimple(int index) {
    const goldenRatio = 0.618033988749895;
    final hue = (index * goldenRatio) % 1.0;
    return HSVColor.fromAHSV(1.0, hue * 360, 0.65, 0.75).toColor();
  }
}

extension DateTimeExtension on DateTime {
  String formatToSchedule() {
    return DateFormat('yyyy/M/d').format(this);
  }
}

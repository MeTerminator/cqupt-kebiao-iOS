import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 课程预设颜色列表
/// 采用黄金分割角分配色相，确保颜色分布均匀且鲜艳
class CourseColors {
  CourseColors._();

  /// 预设颜色列表 (固定生成 20 个区分度高的颜色)
  static List<Color> get presetColors {
    return List.generate(20, (index) {
      return dynamicCourseColor(index: index, total: 20);
    });
  }

  /// 根据索引获取动态课程颜色
  /// 使用黄金比例共轭算法，让相邻颜色的色相差距最大化
  static Color dynamicCourseColor({required int index, required int total}) {
    // 1. 使用黄金角 (137.5 度) 避免颜色过于聚集
    // 即使课程很多，它也能保证相邻的两门课颜色差异感最强
    final hue = (index * 137.5) % 360;

    // 2. 强制设置 高饱和度 和 中等亮度
    // 这是避开“棕色/灰色/深色”陷阱的最优参数组合
    const saturation = 0.65;
    const lightness = 0.40;

    // 使用 Flutter 原生 HSLColor 类，由引擎计算 RGB，保证色彩纯度
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  /// 查找最接近的颜色索引（用于 UI 匹配）
  static int findClosestColorIndex(Color color) {
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < presetColors.length; i++) {
      final distance = _colorDistance(color, presetColors[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  /// 计算两个颜色之间的欧氏距离 (RGB 空间)
  static double _colorDistance(Color c1, Color c2) {
    final dr = (c1.red - c2.red).toDouble();
    final dg = (c1.green - c2.green).toDouble();
    final db = (c1.blue - c2.blue).toDouble();

    // 增加颜色差距权重
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  /// Hex 颜色字符串转 Color
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

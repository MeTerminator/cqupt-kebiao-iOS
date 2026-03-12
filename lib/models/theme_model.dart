import 'package:flutter/material.dart';

class ThemeSettings {
  final String id;
  final String name;

  // 背景设置
  final BackgroundType backgroundType; // solid 或 image
  final String? backgroundColorHex; // 纯色背景颜色
  final String? backgroundImagePath; // 背景图路径

  // 字体颜色设置
  final String? headerTextColorHex; // 顶部字体颜色
  final String? timelineTextColorHex; // 时间轴字体颜色
  final String? courseBlockTextColorHex; // 课程块字体颜色

  // 课程块描边设置
  final String? courseBlockBorderColorHex; // 描边颜色
  final double courseBlockBorderWidth; // 描边粗细

  // 课程块不透明度
  final double courseBlockOpacity; // 不透明度 (0.0 - 1.0)

  // Header 设置
  final double headerOpacity; // Header 不透明度 (0.0 - 1.0)
  final bool headerBlurEffect; // 是否启用毛玻璃效果
  final String? headerBackgroundColorHex; // 导航栏背景颜色
  final double headerBackgroundOpacity; // 导航栏背景不透明度 (0.0 - 1.0)

  ThemeSettings({
    required this.id,
    required this.name,
    this.backgroundType = BackgroundType.solid,
    this.backgroundColorHex,
    this.backgroundImagePath,
    this.headerTextColorHex,
    this.timelineTextColorHex,
    this.courseBlockTextColorHex,
    this.courseBlockBorderColorHex,
    this.courseBlockBorderWidth = 0.0,
    this.courseBlockOpacity = 1.0,
    this.headerOpacity = 1.0,
    this.headerBlurEffect = false,
    this.headerBackgroundColorHex,
    this.headerBackgroundOpacity = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'background_type': backgroundType.name,
    'background_color_hex': backgroundColorHex,
    'background_image_path': backgroundImagePath,
    'header_text_color_hex': headerTextColorHex,
    'timeline_text_color_hex': timelineTextColorHex,
    'course_block_text_color_hex': courseBlockTextColorHex,
    'course_block_border_color_hex': courseBlockBorderColorHex,
    'course_block_border_width': courseBlockBorderWidth,
    'course_block_opacity': courseBlockOpacity,
    'header_opacity': headerOpacity,
    'header_blur_effect': headerBlurEffect,
    'header_background_color_hex': headerBackgroundColorHex,
    'header_background_opacity': headerBackgroundOpacity,
  };

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    return ThemeSettings(
      id: json['id'] ?? 'default',
      name: json['name'] ?? '默认主题',
      backgroundType: BackgroundType.values.firstWhere(
        (e) => e.name == json['background_type'],
        orElse: () => BackgroundType.solid,
      ),
      backgroundColorHex: json['background_color_hex'] as String?,
      backgroundImagePath: json['background_image_path'] as String?,
      headerTextColorHex: json['header_text_color_hex'] as String?,
      timelineTextColorHex: json['timeline_text_color_hex'] as String?,
      courseBlockTextColorHex: json['course_block_text_color_hex'] as String?,
      courseBlockBorderColorHex:
          json['course_block_border_color_hex'] as String?,
      courseBlockBorderWidth: (json['course_block_border_width'] ?? 0.0)
          .toDouble(),
      courseBlockOpacity: (json['course_block_opacity'] ?? 1.0).toDouble(),
      headerOpacity: (json['header_opacity'] ?? 1.0).toDouble(),
      headerBlurEffect: json['header_blur_effect'] as bool? ?? false,
      headerBackgroundColorHex: json['header_background_color_hex'] as String?,
      headerBackgroundOpacity: (json['header_background_opacity'] ?? 1.0)
          .toDouble(),
    );
  }

  ThemeSettings copyWith({
    String? id,
    String? name,
    BackgroundType? backgroundType,
    String? backgroundColorHex,
    String? backgroundImagePath,
    String? headerTextColorHex,
    String? timelineTextColorHex,
    String? courseBlockTextColorHex,
    String? courseBlockBorderColorHex,
    double? courseBlockBorderWidth,
    double? courseBlockOpacity,
    double? headerOpacity,
    bool? headerBlurEffect,
    String? headerBackgroundColorHex,
    double? headerBackgroundOpacity,
  }) {
    return ThemeSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      headerTextColorHex: headerTextColorHex ?? this.headerTextColorHex,
      timelineTextColorHex: timelineTextColorHex ?? this.timelineTextColorHex,
      courseBlockTextColorHex:
          courseBlockTextColorHex ?? this.courseBlockTextColorHex,
      courseBlockBorderColorHex:
          courseBlockBorderColorHex ?? this.courseBlockBorderColorHex,
      courseBlockBorderWidth:
          courseBlockBorderWidth ?? this.courseBlockBorderWidth,
      courseBlockOpacity: courseBlockOpacity ?? this.courseBlockOpacity,
      headerOpacity: headerOpacity ?? this.headerOpacity,
      headerBlurEffect: headerBlurEffect ?? this.headerBlurEffect,
      headerBackgroundColorHex:
          headerBackgroundColorHex ?? this.headerBackgroundColorHex,
      headerBackgroundOpacity:
          headerBackgroundOpacity ?? this.headerBackgroundOpacity,
    );
  }

  static ThemeSettings defaultTheme() {
    return ThemeSettings(
      id: 'default',
      name: '默认主题',
      backgroundType: BackgroundType.solid,
      backgroundColorHex: null,
      headerTextColorHex: null,
      timelineTextColorHex: null,
      courseBlockTextColorHex: null,
      courseBlockBorderColorHex: null,
      courseBlockBorderWidth: 0.0,
      courseBlockOpacity: 1.0,
    );
  }
}

enum BackgroundType { solid, image }

/// 工具类：主题颜色转换
class ThemeColorUtils {
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

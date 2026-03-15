import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../view_models/schedule_view_model.dart';

class WidgetService {
  static const String appGroupId = 'group.top.met6.cquptscheduleios';

  // iOS 配置（使用 widget 的 kind 值）
  static const String iOSWidgetKind = 'CourseWidget';
  static const String upcomingCourseWidgetKind = 'UpcomingCourseWidget';
  static const String todayCourseWidgetKind = 'TodayCourseWidget';
  static const String lockScreenWidgetKind = 'LockScreenWidget';

  // Android 配置（对应 AndroidManifest.xml 中 Receiver 的类名）
  static const String androidUpcomingReceiver = 'UpcomingWidgetReceiver';
  static const String androidTodayReceiver = 'TodayWidgetReceiver';

  static Future<void> syncToWidget(ScheduleViewModel vm) async {
    if (vm.scheduleData == null) return;

    try {
      // iOS 必须设置 AppGroupId
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }

      final Map<String, dynamic> exportData = {
        'week_1_monday': vm.scheduleData!.week1Monday,
        'instances': [
          ...vm.scheduleData!.instances.map((e) => e.toJson()),
          ...vm.customCourses
              .expand((e) => e.toInstances())
              .map((e) => e.toJson()),
        ],
      };

      // 统一保存数据
      await HomeWidget.saveWidgetData(
        'full_schedule_json',
        jsonEncode(exportData),
      );

      // 平台差异化更新
      if (Platform.isIOS) {
        // iOS 更新所有 widget（通过更新 bundle 来触发所有 widget 刷新）
        // home_widget 包在 iOS 上会通过 bundle ID 触发整个 widget extension 的刷新
        await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
        // 额外调用确保所有 widget 都刷新
        await HomeWidget.updateWidget(iOSName: upcomingCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: todayCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: lockScreenWidgetKind);
      } else if (Platform.isAndroid) {
        // Android 更新所有相关的 Receiver
        await HomeWidget.updateWidget(androidName: androidUpcomingReceiver);
        await HomeWidget.updateWidget(androidName: androidTodayReceiver);
      }
    } catch (e) {
      debugPrint("Widget Sync Error: $e");
    }
  }
}

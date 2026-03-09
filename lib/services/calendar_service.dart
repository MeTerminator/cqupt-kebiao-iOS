import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart' show Color, debugPrint;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_model.dart';
import 'package:collection/collection.dart';
import 'dart:io';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  final String _targetAccountName = '重邮课表';

  Future<bool> requestPermissions() async {
    PermissionStatus status = await Permission.calendarFullAccess.request();
    if (!status.isGranted) {
      final result = await _deviceCalendarPlugin.requestPermissions();
      return result.isSuccess && result.data == true;
    }
    return status.isGranted;
  }

  Future<bool> hasPermissions() async {
    return await Permission.calendarFullAccess.isGranted;
  }

  /// 获取或创建日历
  Future<Calendar?> getOrCreateCalendar(String calendarName) async {
    final finalName = calendarName.trim().isEmpty
        ? '重邮课表'
        : calendarName.trim();

    if (!(await hasPermissions())) {
      if (!(await requestPermissions())) return null;
    }

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();

    // 1. 尝试复用
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      final existing = calendarsResult.data!.firstWhereOrNull(
        (c) => c.name == finalName,
      );
      if (existing != null) return existing;
    }

    // 2. 尝试创建
    debugPrint('正在尝试创建日历: $finalName');
    var result = await _deviceCalendarPlugin.createCalendar(
      finalName,
      calendarColor: const Color(0xFF3498DB),
      localAccountName: Platform.isIOS ? null : _targetAccountName,
    );

    if (result.isSuccess && result.data != null) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final retryResult = await _deviceCalendarPlugin.retrieveCalendars();
      return retryResult.data?.firstWhereOrNull((c) => c.id == result.data);
    } else {
      debugPrint('日历创建失败: ${result.errors.map((e) => e.errorMessage)}');
      return null; // 这里必须返回 null 终止同步，防止无限重试
    }
  }

  /// 极速清空旧事件
  Future<void> deleteOldEvents(String calendarId) async {
    final now = DateTime.now();
    // 清理范围扩大，确保覆盖整个学期
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final twoYearsLater = now.add(const Duration(days: 730));

    final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(startDate: oneYearAgo, endDate: twoYearsLater),
    );

    if (eventsResult.isSuccess &&
        eventsResult.data != null &&
        eventsResult.data!.isNotEmpty) {
      final futures = eventsResult.data!
          .where((e) => e.eventId != null)
          .map(
            (e) => _deviceCalendarPlugin.deleteEvent(calendarId, e.eventId!),
          );

      try {
        await Future.wait(futures);
        debugPrint('成功清空 ${futures.length} 个历史事件');
      } catch (e) {
        debugPrint('批量清理历史事件时遇到异常: $e');
      }
    }
  }

  /// 同步课表核心方法
  Future<bool> syncCourses({
    required List<CourseInstance> instances,
    required String startDateStr,
    String calendarName = '重邮课表',
    int? firstAlertMinutes = 30,
    int? secondAlertMinutes = 10,
  }) async {
    final calendar = await getOrCreateCalendar(calendarName);
    if (calendar == null || calendar.id == null) return false;

    // 清空旧日程
    await deleteOldEvents(calendar.id!);

    final firstMonday = DateTime.parse(startDateStr.substring(0, 10));

    // 循环中引入极其短暂的延迟，防止系统数据库写入过载
    for (int i = 0; i < instances.length; i++) {
      final instance = instances[i];
      final startDt = _calculateEventStart(instance, firstMonday);
      final endDt = _calculateEventEnd(instance, firstMonday);

      final event = Event(
        calendar.id,
        title: _buildEventTitle(instance),
        location: _buildEventLocation(instance),
        description: _buildEventDescription(instance),
        start: tz.TZDateTime.from(startDt, tz.local),
        end: tz.TZDateTime.from(endDt, tz.local),
      );

      event.reminders = [
        if (firstAlertMinutes != null && firstAlertMinutes > 0)
          Reminder(minutes: firstAlertMinutes),
        if (secondAlertMinutes != null &&
            secondAlertMinutes > 0 &&
            secondAlertMinutes != firstAlertMinutes)
          Reminder(minutes: secondAlertMinutes),
      ];

      // 处理可能为 null 的返回值
      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);

      // 1. 检查 result 是否为空，2. 再检查操作是否成功
      if (result == null || !result.isSuccess) {
        final errorMsg =
            result?.errors.map((e) => e.errorMessage).join(', ') ?? '未知错误';
        debugPrint('第 $i 个事件插入失败: $errorMsg');
      }

      // 每插入 10 个课表，稍微停顿一下以减轻系统负担
      if (i % 10 == 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    debugPrint('同步完成，共处理 ${instances.length} 个课表事件');
    return true;
  }

  // --- 工具方法保持原样 ---
  String _buildEventTitle(CourseInstance instance) => instance.type == "自定义行程"
      ? '【自定义】${instance.course}'
      : (instance.type == "常规" || instance.type == "考试"
            ? instance.course
            : '${instance.course} (${instance.type})');
  String _buildEventLocation(CourseInstance instance) =>
      (instance.type == "考试" || instance.type == "冲突")
      ? instance.location
      : (_getTeacher(instance).isNotEmpty
            ? '${instance.location} ${_getTeacher(instance)}'
            : instance.location);

  String _buildEventDescription(CourseInstance instance) {
    final teacher = _getTeacher(instance);
    final periodsStr = instance.periods.join(',');
    List<String> notes = [];
    if (instance.type == "考试") {
      final parts = instance.location.split(' ');
      notes.addAll([
        "地点: ${parts.isNotEmpty ? parts[0] : instance.location}",
        "座位号: ${parts.length > 1 ? parts[1] : '未分配'}",
      ]);
      if (teacher.isNotEmpty) notes.add("教师: $teacher");
    } else if (instance.type != "冲突") {
      notes.addAll(["地点: ${instance.location}"]);
      if (teacher.isNotEmpty) notes.add("教师: $teacher");
    }
    notes.add("类型: ${instance.type}");
    notes.add("节次: $periodsStr");
    if (instance.description != null &&
        instance.description!.isNotEmpty &&
        instance.type != "冲突") {
      notes.add("备注: ${instance.description!.replaceAll(r'\n', '\n')}");
    }
    return notes.join('\n');
  }

  String _getTeacher(CourseInstance instance) =>
      (instance.teacher == null ||
          instance.teacher == "无" ||
          instance.teacher == "未知")
      ? ""
      : instance.teacher!;
  DateTime _calculateEventStart(
    CourseInstance instance,
    DateTime firstMonday,
  ) => _combineDateAndTime(
    firstMonday.add(
      Duration(days: (instance.week - 1) * 7 + (instance.day - 1)),
    ),
    instance.startTime,
  );
  DateTime _calculateEventEnd(CourseInstance instance, DateTime firstMonday) =>
      _combineDateAndTime(
        firstMonday.add(
          Duration(days: (instance.week - 1) * 7 + (instance.day - 1)),
        ),
        instance.endTime,
      );
  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    final p = timeStr.split(':').map(int.parse).toList();
    return DateTime(date.year, date.month, date.day, p[0], p[1]);
  }
}

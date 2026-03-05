import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart' show Color;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_model.dart';
import 'dart:io';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  /// 请求权限：兼容 iOS 17+
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

  /// 获取或创建指定名称的日历
  Future<Calendar?> getOrCreateCalendar(String calendarName) async {
    final finalName = calendarName.trim().isEmpty ? '重邮课表' : calendarName.trim();
    
    // 检查权限
    if (!(await hasPermissions())) {
      if (!(await requestPermissions())) return null;
    }

    // 1. 查找现有日历
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      for (var c in calendarsResult.data!) {
        if (c.name == finalName) return c;
      }
    }

    // 2. 创建新日历 (对齐 Swift 的 saveCalendar)
    var result = await _deviceCalendarPlugin.createCalendar(
      finalName,
      calendarColor: const Color(0xFF3498DB),
      localAccountName: Platform.isIOS ? null : 'CQUPT_Account', 
    );

    if (result.isSuccess && result.data != null) {
      final calendarsNow = await _deviceCalendarPlugin.retrieveCalendars();
      return calendarsNow.data?.firstWhere((c) => c.id == result.data);
    }
    return null;
  }

  /// 清空旧事件
  Future<void> deleteOldEvents(String calendarId) async {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final twoYearsLater = now.add(const Duration(days: 730));

    final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(startDate: oneYearAgo, endDate: twoYearsLater),
    );

    if (eventsResult.isSuccess && eventsResult.data != null) {
      for (final event in eventsResult.data!) {
        if (event.eventId != null) {
          await _deviceCalendarPlugin.deleteEvent(calendarId, event.eventId);
        }
      }
    }
  }

  Future<bool> syncCourses({
    required List<CourseInstance> instances,
    required String startDateStr,
    String calendarName = '重邮课表',
    int? firstAlertMinutes = 30, 
    int? secondAlertMinutes = 10,
  }) async {
    final calendar = await getOrCreateCalendar(calendarName);
    if (calendar == null || calendar.id == null) return false;

    await deleteOldEvents(calendar.id!);

    final firstMonday = DateTime.parse(startDateStr.substring(0, 10));

    for (final instance in instances) {
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

      // 提醒设置
      final reminders = <Reminder>[];
      if (firstAlertMinutes != null && firstAlertMinutes > 0) {
        reminders.add(Reminder(minutes: firstAlertMinutes));
      }
      if (secondAlertMinutes != null && secondAlertMinutes > 0 && secondAlertMinutes != firstAlertMinutes) {
        reminders.add(Reminder(minutes: secondAlertMinutes));
      }
      event.reminders = reminders;

      await _deviceCalendarPlugin.createOrUpdateEvent(event);
    }
    return true;
  }

  // --- 逻辑对齐工具方法 ---

  String _buildEventTitle(CourseInstance instance) {
    if (instance.type == "自定义行程") return '【自定义】${instance.course}';
    if (instance.type == "常规" || instance.type == "考试") return instance.course;
    return '${instance.course} (${instance.type})';
  }

  String _buildEventLocation(CourseInstance instance) {
    final teacher = _getTeacher(instance);
    if (instance.type == "考试" || instance.type == "冲突") return instance.location;
    return teacher.isNotEmpty ? '${instance.location} $teacher' : instance.location;
  }

  String _buildEventDescription(CourseInstance instance) {
    final teacher = _getTeacher(instance);
    final periodsStr = instance.periods.join(',');
    List<String> notes = [];

    if (instance.type == "考试") {
      final parts = instance.location.split(' ');
      notes.add("地点: ${parts.isNotEmpty ? parts[0] : instance.location}");
      notes.add("座位号: ${parts.length > 1 ? parts[1] : '未分配'}");
      if (teacher.isNotEmpty) notes.add("教师: $teacher");
      notes.add("类型: ${instance.type}");
      notes.add("节次: $periodsStr");
    } else if (instance.type == "冲突") {
      if (instance.description?.isNotEmpty ?? false) {
        notes.add(instance.description!.replaceAll(r'\n', '\n'));
      }
    } else {
      notes.add("地点: ${instance.location}");
      if (teacher.isNotEmpty) notes.add("教师: $teacher");
      notes.add("类型: ${instance.type}");
      notes.add("节次: $periodsStr");
    }

    if (instance.description != null && instance.description!.isNotEmpty && instance.type != "冲突") {
      notes.add("备注: ${instance.description!.replaceAll(r'\n', '\n')}");
    }
    return notes.join('\n');
  }

  String _getTeacher(CourseInstance instance) {
    final t = instance.teacher ?? "";
    return (t.isEmpty || t == "无" || t == "未知") ? "" : t;
  }

  DateTime _calculateEventStart(CourseInstance instance, DateTime firstMonday) {
    final date = firstMonday.add(Duration(days: (instance.week - 1) * 7 + (instance.day - 1)));
    return _combineDateAndTime(date, instance.startTime);
  }

  DateTime _calculateEventEnd(CourseInstance instance, DateTime firstMonday) {
    final date = firstMonday.add(Duration(days: (instance.week - 1) * 7 + (instance.day - 1)));
    return _combineDateAndTime(date, instance.endTime);
  }

  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    final p = timeStr.split(':').map(int.parse).toList();
    return DateTime(date.year, date.month, date.day, p[0], p[1]);
  }
}
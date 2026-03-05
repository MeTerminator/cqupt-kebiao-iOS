import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart' show Color, debugPrint;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_model.dart';
import 'dart:io'; // 用于判断平台

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  static const Map<String, int?> alertOptions = {
    '无': null, '5分钟': 5, '10分钟': 10, '15分钟': 15, '30分钟': 30, '1小时': 60, '2小时': 120,
  };

  /// 请求权限：增加了对 iOS 17 的特别处理
  Future<bool> requestPermissions() async {
    // 优先使用 permission_handler 请求
    PermissionStatus status = await Permission.calendarFullAccess.request();
    
    // 如果失败，尝试使用插件自带的方法作为兜底（有些版本插件内置了请求逻辑）
    if (!status.isGranted) {
      final result = await _deviceCalendarPlugin.requestPermissions();
      return result.isSuccess && result.data == true;
    }
    
    return status.isGranted;
  }

  Future<bool> hasPermissions() async {
    return await Permission.calendarFullAccess.isGranted;
  }

  Future<List<Calendar>> getCalendars() async {
    // 这里的逻辑：如果没权限，直接请求
    if (!(await hasPermissions())) {
      bool granted = await requestPermissions();
      if (!granted) return [];
    }

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      return calendarsResult.data!;
    } else {
      debugPrint("获取日历列表失败");
      return [];
    }
  }

  Future<Calendar?> getOrCreateCalendar(String calendarName) async {
    final finalName = calendarName.trim().isEmpty ? '重邮课表' : calendarName.trim();
    
    // 1. 获取最新列表
    final calendars = await getCalendars();
    if (calendars.isEmpty) {
      debugPrint("权限可能已获得，但无法找到任何日历账户（请检查系统日历账户是否开启）");
    }

    for (var c in calendars) {
      if (c.name == finalName) return c;
    }
    
    try {
      // 2. 尝试创建
      // 注意：iOS 上 localAccountName 有时会导致失败，如果不成功可以尝试传 null
      var result = await _deviceCalendarPlugin.createCalendar(
        finalName,
        calendarColor: const Color(0xFF3498DB),
        localAccountName: Platform.isIOS ? null : 'CQUPT_Account', 
      );

      if (result.isSuccess && result.data != null) {
        final calendarsNow = await _deviceCalendarPlugin.retrieveCalendars();
        return calendarsNow.data?.firstWhere((c) => c.id == result.data);
      } else {
        debugPrint("创建日历失败");
        return null;
      }
    } catch (e) {
      debugPrint("日历操作异常: $e");
      return null;
    }
  }

  // ... deleteOldEvents, _toTZDateTime 等方法保持不变 ...

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

    final firstMonday = _parseDate(startDateStr);

    for (final instance in instances) {
      final startDt = _calculateEventStart(instance, firstMonday);
      final endDt = _calculateEventEnd(instance, firstMonday);

      final event = Event(
        calendar.id,
        title: _buildEventTitle(instance),
        description: _buildEventDescription(instance),
        location: _buildEventLocation(instance),
        start: tz.TZDateTime.from(startDt, tz.local),
        end: tz.TZDateTime.from(endDt, tz.local),
      );

      final reminders = <Reminder>[];
      if (firstAlertMinutes != null) reminders.add(Reminder(minutes: firstAlertMinutes));
      if (secondAlertMinutes != null && secondAlertMinutes != firstAlertMinutes) {
        reminders.add(Reminder(minutes: secondAlertMinutes));
      }
      if (reminders.isNotEmpty) event.reminders = reminders;

      await _deviceCalendarPlugin.createOrUpdateEvent(event);
    }
    return true;
  }

  String _buildEventTitle(CourseInstance instance) {
    if (instance.type == '自定义行程') return '【自定义】${instance.course}';
    if (instance.type == '考试') return '【考试】${instance.course}';
    return instance.course;
  }

  String _buildEventLocation(CourseInstance instance) {
    final teacher = instance.teacher ?? '';
    final hasTeacher = teacher.isNotEmpty && teacher != '无' && teacher != '未知';
    return hasTeacher ? '${instance.location} ($teacher)' : instance.location;
  }

  String _buildEventDescription(CourseInstance instance) {
    final lines = <String>[];
    lines.add('地点: ${instance.location}');
    if (instance.teacher != null && instance.teacher != '未知') lines.add('教师: ${instance.teacher}');
    lines.add('类型: ${instance.type}');
    lines.add('节次: 第 ${instance.periods.join(',')} 节');
    if (instance.description != null && instance.description!.isNotEmpty) lines.add('备注: ${instance.description}');
    return lines.join('\n');
  }

  DateTime _calculateEventStart(CourseInstance instance, DateTime firstMonday) {
    final daysOffset = (instance.week - 1) * 7 + (instance.day - 1);
    final baseDate = firstMonday.add(Duration(days: daysOffset));
    return _combineDateAndTime(baseDate, instance.startTime);
  }

  DateTime _calculateEventEnd(CourseInstance instance, DateTime firstMonday) {
    final daysOffset = (instance.week - 1) * 7 + (instance.day - 1);
    final baseDate = firstMonday.add(Duration(days: daysOffset));
    return _combineDateAndTime(baseDate, instance.endTime);
  }

  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return date;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  DateTime _parseDate(String dateStr) {
    try { return DateTime.parse(dateStr); } catch (e) { return DateTime.now(); }
  }
}
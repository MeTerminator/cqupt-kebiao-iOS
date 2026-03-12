import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/schedule_model.dart';
import '../services/widget_service.dart';

class ScheduleViewModel extends ChangeNotifier {
  ScheduleResponse? scheduleData;
  List<CustomCourse> customCourses = [];
  bool isLoading = false;
  int selectedWeek = 1;
  String currentId = "";
  Map<String, int> courseColorMap = {}; // 课程颜色索引映射
  Map<String, String> courseCustomColorMap = {}; // 课程自定义颜色 Hex 映射

  String toastMessage = "";
  bool showToast = false;

  DateTime? firstMondayDate;
  Timer? _refreshTimer;

  // 标志位：是否需要动画跳转到指定周
  bool shouldAnimateToWeek = false;

  static const String kCustomCoursesKey = "cloud_custom_courses";
  static const String kSavedIdKey = "saved_id";
  static const String kCourseColorMapKey = "course_color_map";
  static const String kCourseCustomColorMapKey = "course_custom_color_map";

  ScheduleViewModel() {
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => refreshData(silent: true),
    );
    loadCustomCourses();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get isCurrentWeekReal {
    final real = calculateCurrentRealWeek();
    final expected = real <= 0 ? 0 : (real > 20 ? 20 : real);
    return selectedWeek == expected;
  }

  int get currentDayOfWeek {
    final weekday = DateTime.now().weekday;
    return weekday;
  }

  bool isToday(int week, int day) {
    return week == calculateCurrentRealWeek() && day == currentDayOfWeek;
  }

  bool isCourseOngoing(CourseInstance course) {
    if (!isToday(course.week, course.day)) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startMinutes = _timeToMinutes(course.startTime);
    final endMinutes = _timeToMinutes(course.endTime);

    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }

  bool isCourseUpcoming(CourseInstance course) {
    if (!isToday(course.week, course.day)) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startMinutes = _timeToMinutes(course.startTime);

    return currentMinutes < startMinutes;
  }

  bool isTomorrowCourse(CourseInstance course) {
    final tomorrowWeek = calculateCurrentRealWeek();
    final tomorrowDay = currentDayOfWeek + 1;
    if (tomorrowDay > 7) return false;

    return course.week == tomorrowWeek && course.day == tomorrowDay;
  }

  double getCourseProgress(CourseInstance course) {
    if (!isCourseOngoing(course)) return 0.0;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startMinutes = _timeToMinutes(course.startTime);
    final endMinutes = _timeToMinutes(course.endTime);

    final totalDuration = endMinutes - startMinutes;
    final elapsed = currentMinutes - startMinutes;

    return (elapsed / totalDuration).clamp(0.0, 1.0);
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  bool hasTodayOngoingCourse(int week) {
    final todayCourses = allCourses(week).where((c) => isToday(c.week, c.day));
    return todayCourses.any((c) => isCourseOngoing(c));
  }

  bool hasTodayUpcomingCourse(int week) {
    final todayCourses = allCourses(week).where((c) => isToday(c.week, c.day));
    return todayCourses.any((c) => isCourseUpcoming(c));
  }

  CourseInstance? getNextUpcomingCourse(int week) {
    final currentWeek = calculateCurrentRealWeek();
    final currentDay = currentDayOfWeek;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final allUpcomingCourses = allCourses(week).where((c) {
      if (c.week < currentWeek) return false;
      if (c.week > currentWeek) return true;

      if (c.day < currentDay) return false;
      if (c.day > currentDay) return true;

      final startMinutes = _timeToMinutes(c.startTime);
      return startMinutes > currentMinutes;
    }).toList();

    if (allUpcomingCourses.isEmpty) return null;

    allUpcomingCourses.sort((a, b) {
      final weekCompare = a.week.compareTo(b.week);
      if (weekCompare != 0) return weekCompare;

      final dayCompare = a.day.compareTo(b.day);
      if (dayCompare != 0) return dayCompare;

      final aMinutes = _timeToMinutes(a.startTime);
      final bMinutes = _timeToMinutes(b.startTime);
      return aMinutes.compareTo(bMinutes);
    });

    return allUpcomingCourses.first;
  }

  CourseInstance? getNextUpcomingCourseGlobal() {
    final now = DateTime.now();
    final currentRealWeek = calculateCurrentRealWeek();
    final currentDay = now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;

    final int nowAbsoluteMinutes = (currentDay - 1) * 1440 + currentMinutes;

    CourseInstance? bestCourse;
    int minDiff = 999999;

    for (int w = currentRealWeek; w <= currentRealWeek + 1; w++) {
      if (w <= 0 || w > 20) continue;

      final courses = allCourses(w);
      for (var c in courses) {
        final int courseStartMinutes = _timeToMinutes(c.startTime);
        final int weekOffset = (w - currentRealWeek) * 10080;
        final int courseAbsoluteMinutes =
            weekOffset + (c.day - 1) * 1440 + courseStartMinutes;

        final diff = courseAbsoluteMinutes - nowAbsoluteMinutes;

        if (diff > 0 && diff < minDiff) {
          minDiff = diff;
          bestCourse = c;
        }
      }
    }

    return bestCourse;
  }

  bool hasAnyCourseOngoing() {
    final realWeek = calculateCurrentRealWeek();
    if (realWeek <= 0 || realWeek > 20) return false;
    return allCourses(realWeek).any((c) => isCourseOngoing(c));
  }

  Future<void> startup(String studentId) async {
    currentId = studentId;
    await loadColorMap();
    await loadFromCache(isInitial: true);
    await WidgetService.syncToWidget(this);
    refreshData(silent: true);
  }

  void generateColorMap() {
    final instances = scheduleData?.instances;
    if (instances == null) return;

    final names =
        instances
            .where((e) => !e.type.contains("考试"))
            .map((e) => e.course)
            .toSet()
            .toList()
          ..sort();

    courseColorMap.clear();

    // 核心：使用黄金比例分配色相，范围 0-360
    for (int i = 0; i < names.length; i++) {
      // 137.5 是黄金分割角，能最大化地分散颜色
      double hue = (i * 137.5) % 360;
      courseColorMap[names[i]] = hue.toInt();
    }

    notifyListeners();
    _saveColorMap();
  }

  void updateCourseColor(String courseName, int colorIndex) {
    courseColorMap[courseName] = colorIndex;
    notifyListeners();
    _saveColorMap();
  }

  void updateCourseCustomColor(String courseName, String? customColorHex) {
    if (customColorHex != null) {
      courseCustomColorMap[courseName] = customColorHex;
    } else {
      courseCustomColorMap.remove(courseName);
    }
    notifyListeners();
    _saveCustomColorMap();
  }

  /// 清空所有课程颜色映射
  void clearAllColorMaps() {
    courseColorMap.clear();
    courseCustomColorMap.clear();
    notifyListeners();
    _saveColorMap();
    _saveCustomColorMap();
  }

  Future<void> _saveColorMap() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(courseColorMap);
    await prefs.setString(kCourseColorMapKey, data);
  }

  Future<void> _saveCustomColorMap() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(courseCustomColorMap);
    await prefs.setString(kCourseCustomColorMapKey, data);
  }

  Future<void> loadColorMap() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(kCourseColorMapKey);
    if (data != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(data);
      courseColorMap = jsonMap.map((key, value) => MapEntry(key, value as int));
      notifyListeners();
    }

    // 加载自定义颜色映射
    final String? customData = prefs.getString(kCourseCustomColorMapKey);
    if (customData != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(customData);
      courseCustomColorMap = jsonMap.map(
        (key, value) => MapEntry(key, value as String),
      );
      notifyListeners();
    }
  }

  List<String> getAllCourseNames() {
    final instances = scheduleData?.instances;
    if (instances == null) return [];

    return instances
        .where((e) => !e.type.contains("考试"))
        .map((e) => e.course)
        .toSet()
        .toList()
      ..sort();
  }

  List<MapEntry<String, int>> getAllCourseColors() {
    final names = getAllCourseNames();
    final customColors = customCourses.map((e) => e.colorIndex).toSet();

    final allColors = <int>{};
    for (var entry in courseColorMap.entries) {
      allColors.add(entry.value);
    }
    allColors.addAll(customColors);

    return names.map((name) {
      final colorIndex = courseColorMap[name] ?? 0;
      return MapEntry(name, colorIndex);
    }).toList();
  }

  Future<void> refreshData({bool silent = false}) async {
    if (currentId.isEmpty) return;

    if (!silent) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final url = Uri.parse(
        "https://cqupt.ishub.top/api/curriculum/$currentId/curriculum.json",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = ScheduleResponse.fromJson(jsonDecode(response.body));
        scheduleData = decoded;
        await _saveToCache(response.body);
        generateColorMap();
        parseStartDate(autoJump: false);
        if (!silent) {
          triggerToast("课表已同步");
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    } finally {
      await WidgetService.syncToWidget(this);
      if (!silent) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<File> get _cacheFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/schedule_cache.json');
  }

  Future<void> _saveToCache(String jsonStr) async {
    final file = await _cacheFile;
    await file.writeAsString(jsonStr);
  }

  Future<void> loadFromCache({bool isInitial = false}) async {
    try {
      final file = await _cacheFile;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        scheduleData = ScheduleResponse.fromJson(jsonDecode(jsonStr));
        generateColorMap();
        parseStartDate(autoJump: isInitial);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
  }

  void parseStartDate({bool autoJump = false}) {
    if (scheduleData == null) return;
    try {
      String dateStr = scheduleData!.week1Monday;
      DateTime date;

      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        final altFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
        date = altFormat.parse(dateStr);
      }

      firstMondayDate = DateTime(date.year, date.month, date.day);

      if (autoJump) {
        final real = calculateCurrentRealWeek();
        selectedWeek = real.clamp(0, 20);
        // 初始加载时不使用动画
        shouldAnimateToWeek = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Date parse error: $e");
    }
  }

  int calculateCurrentRealWeek() {
    if (firstMondayDate == null) return 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysDiff = today.difference(firstMondayDate!).inDays;

    if (daysDiff < 0) {
      if (daysDiff >= -7) return 0;
      return -1;
    }
    return (daysDiff ~/ 7) + 1;
  }

  void triggerToast(String msg) {
    toastMessage = msg;
    showToast = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      showToast = false;
      notifyListeners();
    });
  }

  Future<void> addCustomCourse(CustomCourse course) async {
    customCourses.add(course);
    await saveCustomCourses();
    await WidgetService.syncToWidget(this);
    triggerToast("行程已添加");
  }

  Future<void> updateCustomCourse(CustomCourse course) async {
    final index = customCourses.indexWhere((e) => e.id == course.id);
    if (index != -1) {
      customCourses[index] = course;
      await saveCustomCourses();
      await WidgetService.syncToWidget(this);
      triggerToast("行程已更新");
    }
  }

  void deleteCustomCourseAt(int index) {
    if (index < 0 || index >= customCourses.length) return;
    customCourses.removeAt(index);
    saveCustomCourses();
    notifyListeners();
  }

  void deleteCustomCourseById(String id) {
    final index = customCourses.indexWhere((e) => e.id == id);
    if (index != -1) {
      customCourses.removeAt(index);
      saveCustomCourses();
      notifyListeners();
    }
  }

  Future<void> clearAllCustomCourses() async {
    customCourses.clear();
    await saveCustomCourses();
    await WidgetService.syncToWidget(this);
    triggerToast("自定义行程已清空");
  }

  Future<void> saveCustomCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      customCourses.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(kCustomCoursesKey, data);
    await WidgetService.syncToWidget(this);
  }

  Future<void> loadCustomCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(kCustomCoursesKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      customCourses = jsonList.map((e) => CustomCourse.fromJson(e)).toList();
      notifyListeners();
    }
    await WidgetService.syncToWidget(this);
  }

  List<CourseInstance> allCourses(int week) {
    final apiList =
        scheduleData?.instances.where((e) => e.week == week).toList() ?? [];
    final customList = customCourses
        .expand((e) => e.toInstances())
        .where((e) => e.week == week)
        .toList();
    return [...apiList, ...customList];
  }

  String calculateDate(int week, int day) {
    if (scheduleData == null) return "未知日期";

    final startStr = scheduleData!.week1Monday.substring(0, 10);
    DateTime startDate;
    try {
      startDate = DateTime.parse(startStr);
    } catch (e) {
      return "未知日期";
    }

    final offset = (week - 1) * 7 + (day - 1);
    final targetDate = startDate.add(Duration(days: offset));

    return DateFormat('yyyy年M月d日').format(targetDate);
  }

  String durationWeeks(CourseInstance course) {
    final allInstances = [
      ...?scheduleData?.instances,
      ...customCourses.map((e) => e.toInstance()),
    ];

    final relatedCourses = allInstances
        .where((e) => e.course == course.course)
        .toList();
    final weeks = relatedCourses.map((e) => e.week).toList();

    if (weeks.isEmpty) return "第 ${course.week} 周";

    final minWeek = weeks.reduce((a, b) => a < b ? a : b);
    final maxWeek = weeks.reduce((a, b) => a > b ? a : b);

    return minWeek == maxWeek ? "第 $minWeek 周" : "$minWeek - $maxWeek 周";
  }
}

class DateFormat {
  final String pattern;
  DateFormat(this.pattern);

  String format(DateTime date) {
    String result = pattern;
    result = result.replaceAll('yyyy', date.year.toString());
    result = result.replaceAll('MM', date.month.toString().padLeft(2, '0'));
    result = result.replaceAll('M', date.month.toString());
    result = result.replaceAll('dd', date.day.toString().padLeft(2, '0'));
    result = result.replaceAll('d', date.day.toString());
    return result;
  }

  DateTime parse(String input) {
    if (pattern == "yyyy-MM-dd'T'HH:mm:ss") {
      return DateTime.parse(input);
    }
    return DateTime.parse(input);
  }
}

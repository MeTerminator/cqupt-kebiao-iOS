import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../view_models/schedule_view_model.dart';

class WidgetService {
  static const String appGroupId = 'group.top.met6.cquptscheduleios'; 
  static const String iOSWidgetName = 'CourseWidget';

  static Future<void> syncToWidget(ScheduleViewModel vm) async {
    if (vm.scheduleData == null) return;

    try {
      await HomeWidget.setAppGroupId(appGroupId);

      final Map<String, dynamic> exportData = {
        'week_1_monday': vm.scheduleData!.week1Monday,
        'instances': [
          ...vm.scheduleData!.instances.map((e) => e.toJson()),
          ...vm.customCourses.expand((e) => e.toInstances()).map((e) => e.toJson()),
        ]
      };

      await HomeWidget.saveWidgetData('full_schedule_json', jsonEncode(exportData));
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        androidName: 'UpcomingWidgetProvider',
        );
    } catch (e) {
      // debugPrint("Widget Sync Error: $e");
    }
  }
}
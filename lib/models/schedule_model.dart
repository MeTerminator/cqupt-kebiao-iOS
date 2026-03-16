class ScheduleResponse {
  final String studentId;
  final String studentName;
  final String academicYear;
  final String semester;
  final String week1Monday;
  final List<CourseInstance> instances;

  ScheduleResponse({
    required this.studentId,
    required this.studentName,
    required this.academicYear,
    required this.semester,
    required this.week1Monday,
    required this.instances,
  });

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'student_name': studentName,
    'academic_year': academicYear,
    'semester': semester,
    'week_1_monday': week1Monday,
    'instances': instances.map((e) => e.toJson()).toList(),
  };

  factory ScheduleResponse.fromJson(Map<String, dynamic> json) {
    return ScheduleResponse(
      studentId: json['student_id'] ?? "",
      studentName: json['student_name'] ?? "",
      academicYear: json['academic_year'] ?? "",
      semester: json['semester'] ?? "",
      week1Monday: json['week_1_monday'] ?? DateTime.now().toIso8601String(),
      instances:
          (json['instances'] as List?)
              ?.map((e) => CourseInstance.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class CourseInstance {
  final String id; // 唯一 ID
  final String course;
  final String? teacher;
  final int week;
  final String? weekStr;
  final int day;
  final List<int> periods;
  final String startTime;
  final String endTime;
  final String location;
  final String type;
  final String? courseType;
  final String? credit;
  final String? description;
  final int? colorIndex;
  final String? customColorHex; // 自定义颜色的 Hex 值

  CourseInstance({
    required this.id,
    required this.course,
    this.teacher,
    required this.week,
    this.weekStr,
    required this.day,
    required this.periods,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.type,
    this.courseType,
    this.credit,
    this.description,
    this.colorIndex,
    this.customColorHex,
  });

  factory CourseInstance.fromJson(Map<String, dynamic> json) {
    List<int> periodsList = [];
    if (json['periods'] is List) {
      periodsList = List<int>.from(json['periods']);
    }

    // 核心修改：计算唯一 ID
    // 逻辑：课程名_周次_星期_第一节课序号
    final String courseName = json['course'] ?? "unknown";
    final int w = json['week'] is int
        ? json['week']
        : int.tryParse(json['week'].toString()) ?? 1;
    final int d = json['day'] is int
        ? json['day']
        : int.tryParse(json['day'].toString()) ?? 1;
    final int firstPeriod = periodsList.isNotEmpty ? periodsList.first : 0;

    // 生成 ID: 例如 "高等数学_1_1_1"
    final String uniqueId = "${courseName}_${w}_${d}_$firstPeriod";

    return CourseInstance(
      id: json['id'] ?? uniqueId,
      course: courseName,
      teacher: json['teacher'],
      week: w,
      weekStr: json['week_str'] ?? json['weekStr'],
      day: d,
      periods: periodsList,
      startTime: json['start_time'] ?? json['startTime'] ?? "08:00",
      endTime: json['end_time'] ?? json['endTime'] ?? "08:45",
      location: json['location'] ?? "",
      type: json['type'] ?? "常规",
      courseType: json['course_type'] ?? json['courseType'],
      credit: json['credit'],
      description: json['description'],
      colorIndex: json['colorIndex'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'course': course,
    'teacher': teacher,
    'week': week,
    'week_str': weekStr,
    'day': day,
    'periods': periods,
    'start_time': startTime,
    'end_time': endTime,
    'location': location,
    'type': type,
    'course_type': courseType,
    'credit': credit,
    'description': description,
    'colorIndex': colorIndex,
  };
}

class CustomCourse {
  final String id;
  final String title;
  final String location;
  final String description;
  final int colorIndex;
  final String? customColorHex; // 自定义颜色的 Hex 值，如果为 null 则使用 colorIndex
  final List<int> weeks;
  final int day;
  final int startPeriod;
  final int endPeriod;

  CustomCourse({
    required this.id,
    required this.title,
    required this.location,
    required this.description,
    required this.colorIndex,
    this.customColorHex,
    required this.weeks,
    required this.day,
    required this.startPeriod,
    required this.endPeriod,
  });

  factory CustomCourse.fromJson(Map<String, dynamic> json) {
    List<int> weeksList = [];
    if (json['weeks'] is List) {
      weeksList = List<int>.from(json['weeks']);
    } else if (json['week'] is int) {
      weeksList = [json['week']];
    }

    return CustomCourse(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? "",
      location: json['location'] ?? "",
      description: json['description'] ?? "",
      colorIndex: json['colorIndex'] ?? 0,
      customColorHex: json['customColorHex'] as String?,
      weeks: weeksList.isEmpty ? [1] : weeksList,
      day: json['day'] ?? 1,
      startPeriod: json['startPeriod'] ?? 1,
      endPeriod: json['endPeriod'] ?? 2,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'location': location,
    'description': description,
    'colorIndex': colorIndex,
    'customColorHex': customColorHex,
    'weeks': weeks,
    'day': day,
    'startPeriod': startPeriod,
    'endPeriod': endPeriod,
  };

  List<CourseInstance> toInstances() {
    final periods = List.generate(
      endPeriod - startPeriod + 1,
      (i) => startPeriod + i,
    );
    final startT = timeTable[startPeriod]?['begin'] ?? '08:00';
    final endT = timeTable[endPeriod]?['end'] ?? '08:45';

    // 自定义课程也需要遵循 唯一 ID 规则
    return weeks
        .map(
          (w) => CourseInstance(
            id: '${id}_${w}_${day}_$startPeriod',
            course: title,
            teacher: "",
            week: w,
            day: day,
            periods: periods,
            startTime: startT,
            endTime: endT,
            location: location,
            type: "自定义行程",
            courseType: "自定义行程",
            credit: null,
            description: description,
            colorIndex: colorIndex,
            customColorHex: customColorHex,
          ),
        )
        .toList();
  }

  CourseInstance toInstance() {
    final periods = List.generate(
      endPeriod - startPeriod + 1,
      (i) => startPeriod + i,
    );
    final startT = timeTable[startPeriod]?['begin'] ?? '08:00';
    final endT = timeTable[endPeriod]?['end'] ?? '08:45';

    return CourseInstance(
      id: '${id}_${weeks.first}_${day}_$startPeriod',
      course: title,
      teacher: "",
      week: weeks.isNotEmpty ? weeks.first : 1,
      day: day,
      periods: periods,
      startTime: startT,
      endTime: endT,
      location: location,
      type: "自定义行程",
      courseType: "自定义行程",
      credit: null,
      description: description,
      colorIndex: colorIndex,
    );
  }
}

final Map<int, Map<String, String>> timeTable = {
  1: {"begin": "08:00", "end": "08:45"},
  2: {"begin": "08:55", "end": "09:40"},
  3: {"begin": "10:15", "end": "11:00"},
  4: {"begin": "11:10", "end": "11:55"},
  5: {"begin": "14:00", "end": "14:45"},
  6: {"begin": "14:55", "end": "15:40"},
  7: {"begin": "16:15", "end": "17:00"},
  8: {"begin": "17:10", "end": "17:55"},
  9: {"begin": "19:00", "end": "19:45"},
  10: {"begin": "19:55", "end": "20:40"},
  11: {"begin": "20:50", "end": "21:35"},
  12: {"begin": "21:45", "end": "22:30"},
};

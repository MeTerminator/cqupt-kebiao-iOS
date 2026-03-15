import SwiftUI
import WidgetKit

// MARK: - 辅助扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Entry
struct CourseEntry: TimelineEntry {
    let date: Date
    let courses: [CourseInstance]
    let todayWeekInfo: String
    let tomorrowWeekInfo: String
    let todayDateStr: String
    let tomorrowDateStr: String
    let todayCourseCount: Int
    let tomorrowCourseCount: Int
}

// MARK: - 数据提供者
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CourseEntry {
        CourseEntry(
            date: Date(), courses: [], todayWeekInfo: "第 - 周", tomorrowWeekInfo: "第 - 周",
            todayDateStr: "00/00", tomorrowDateStr: "00/00", todayCourseCount: 0,
            tomorrowCourseCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CourseEntry) -> Void) {
        completion(loadData(for: Date()))
    }

    func getTimeline(
        in context: Context, completion: @escaping @Sendable (Timeline<CourseEntry>) -> Void
    ) {
        let now = Date()
        let calendar = Calendar.current

        // 1. 生成当前时刻的 Entry
        let currentEntry = loadData(for: now)
        var entries: [CourseEntry] = [currentEntry]

        // 2. 提取今天和明天所有课程的关键时间点（开始和结束）
        var refreshDates = Set<Date>()
        for course in currentEntry.courses {
            // 今天课程的开始和结束时间
            if let start = combine(date: now, timeStr: course.start_time) {
                refreshDates.insert(start)
            }
            if let end = combine(date: now, timeStr: course.end_time) {
                refreshDates.insert(end)
            }
        }

        // 3. 过滤掉过去的时间，排序并为每个关键点生成 Entry
        let futureDates = refreshDates.filter { $0 > now }.sorted()
        for date in futureDates {
            entries.append(loadData(for: date))
        }

        // 4. 设置刷新策略：只在下一个关键时间点刷新（上下课时间）
        // 如果没有更多关键点，则设置为明天凌晨刷新
        let nextUpdate: Date
        if let nextKeyTime = futureDates.first {
            nextUpdate = nextKeyTime
        } else {
            // 设置到明天凌晨 0 点
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            nextUpdate = calendar.startOfDay(for: tomorrow)
        }

        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    // 逻辑核心：根据传入的 referenceDate 计算该时刻应显示的课程数据
    private func loadData(for referenceDate: Date) -> CourseEntry {
        let prefs = UserDefaults(suiteName: "group.top.met6.cquptscheduleios")
        let calendar = Calendar.current

        guard let jsonString = prefs?.string(forKey: "full_schedule_json"),
            let data = jsonString.data(using: .utf8),
            let response = try? JSONDecoder().decode(ScheduleResponse.self, from: data)
        else {
            return CourseEntry(
                date: referenceDate, courses: [], todayWeekInfo: "-", tomorrowWeekInfo: "-",
                todayDateStr: "-", tomorrowDateStr: "-", todayCourseCount: 0, tomorrowCourseCount: 0
            )
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let firstMonday = df.date(from: String(response.week_1_monday.prefix(10))) ?? referenceDate

        func getWeek(for date: Date) -> Int {
            let diff = calendar.dateComponents([.day], from: firstMonday, to: date).day ?? 0
            return (diff / 7) + 1
        }

        let weekday = calendar.component(.weekday, from: referenceDate)
        let currentDay = (weekday == 1) ? 7 : (weekday - 1)

        func formatDate(_ date: Date, offset: Int) -> (String, Int) {
            let targetDate = calendar.date(byAdding: .day, value: offset, to: date)!
            let dayNames = ["", "一", "二", "三", "四", "五", "六", "日"]
            let dayIdx =
                (calendar.component(.weekday, from: targetDate) == 1)
                ? 7 : (calendar.component(.weekday, from: targetDate) - 1)
            df.dateFormat = "MM/dd"
            return ("\(df.string(from: targetDate)) 星期\(dayNames[dayIdx])", dayIdx)
        }

        let (todayStr, _) = formatDate(referenceDate, offset: 0)
        let (tomorrowStr, _) = formatDate(referenceDate, offset: 1)

        let refMinutes =
            calendar.component(.hour, from: referenceDate) * 60
            + calendar.component(.minute, from: referenceDate)

        // 过滤：当天且尚未结束的课程
        let todayCourses = response.instances.filter {
            $0.week == getWeek(for: referenceDate) && $0.day == currentDay
                && timeToMin($0.end_time) > refMinutes
        }.sorted { a, b in
            timeToMin(a.start_time) < timeToMin(b.start_time)
        }

        let tomorrowTargetDay = (currentDay == 7) ? 1 : currentDay + 1
        let tomorrowTargetWeek =
            (currentDay == 7) ? getWeek(for: referenceDate) + 1 : getWeek(for: referenceDate)
        let tomorrowCourses = response.instances.filter {
            $0.week == tomorrowTargetWeek && $0.day == tomorrowTargetDay
        }.sorted { a, b in
            timeToMin(a.start_time) < timeToMin(b.start_time)
        }

        return CourseEntry(
            date: referenceDate,
            courses: todayCourses + tomorrowCourses,
            todayWeekInfo: "第 \(getWeek(for: referenceDate)) 周",
            tomorrowWeekInfo: "第 \(tomorrowTargetWeek) 周",
            todayDateStr: todayStr,
            tomorrowDateStr: tomorrowStr,
            todayCourseCount: todayCourses.count,
            tomorrowCourseCount: tomorrowCourses.count
        )
    }

    // MARK: - 工具函数
    private func timeToMin(_ t: String) -> Int {
        let parts = t.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }

    private func combine(date: Date, timeStr: String) -> Date? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1])
        else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }
}

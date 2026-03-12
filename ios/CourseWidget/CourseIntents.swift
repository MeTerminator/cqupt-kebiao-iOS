import AppIntents
import Foundation

struct CheckCourseIntent: AppIntent {
    static var title: LocalizedStringResource = "查询课表安排"
    static var description = IntentDescription("询问 Siri 下一节课在哪里上，还有多久。")

    @MainActor
    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let prefs = UserDefaults(suiteName: "group.top.met6.cquptscheduleios")
        
        guard let jsonString = prefs?.string(forKey: "full_schedule_json"),
              let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(ScheduleResponse.self, from: data) else {
            return .result(value: "未找到课表", dialog: IntentDialog("抱歉，我没能找到你的课表信息，请先打开 App 同步数据。"))
        }

        let now = Date()
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let firstMonday = df.date(from: String(response.week_1_monday.prefix(10))) ?? now
        let diff = calendar.dateComponents([.day], from: firstMonday, to: now).day ?? 0
        let currentWeek = (diff / 7) + 1
        let weekday = calendar.component(.weekday, from: now)
        let currentDay = (weekday == 1) ? 7 : (weekday - 1)
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let todayCourses = response.instances.filter { $0.week == currentWeek && $0.day == currentDay }
        
        let ongoing = todayCourses.first {
            timeToMin($0.start_time) <= currentMinutes && timeToMin($0.end_time) > currentMinutes
        }
        let upcoming = todayCourses.filter { timeToMin($0.start_time) > currentMinutes }
            .sorted { timeToMin($0.start_time) < timeToMin($1.start_time) }.first

        // 处理地点：在每个数字之间插入空格，防止 Siri 读成“三百零二”
        func formatLocation(_ loc: String) -> String {
            return loc.map { String($0) }.joined(separator: " ")
        }

        // 处理时间格式化
        func formatTimeLeft(_ minutes: Int) -> String {
            let hours = minutes / 60
            let mins = minutes % 60
            if hours > 0 {
                return "\(hours)小时\(mins)分钟"
            } else {
                return "\(mins)分钟"
            }
        }

        if let course = ongoing {
            let timeLeft = timeToMin(course.end_time) - currentMinutes
            let speech = "还剩\(formatTimeLeft(timeLeft))，地点\(formatLocation(course.location))，\(course.course)，教师\(course.teacher ?? "无")。"
            return .result(value: speech, dialog: IntentDialog(stringLiteral: speech))
        } else if let course = upcoming {
            let timeUntil = timeToMin(course.start_time) - currentMinutes
            let speech = "还剩\(formatTimeLeft(timeUntil))，地点\(formatLocation(course.location))，\(course.course)，教师\(course.teacher ?? "无")。"
            return .result(value: speech, dialog: IntentDialog(stringLiteral: speech))
        } else {
            return .result(value: "没课了", dialog: IntentDialog("你今天已经没有课程安排了。"))
        }
    }

    private func timeToMin(_ t: String) -> Int {
        let parts = t.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }
}

struct CourseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckCourseIntent(),
            phrases: [
                "用 \(.applicationName) 查看课程",
                "在 \(.applicationName) 查课表",
                "查 \(.applicationName) ",
                "查询 \(.applicationName) ",
                "查看 \(.applicationName) ",
            ],
            shortTitle: "查询课表",
            systemImageName: "calendar"
        )
    }
}

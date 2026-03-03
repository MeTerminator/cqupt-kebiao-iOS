import EventKit
import UIKit

class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()

    func requestAccess(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    DispatchQueue.main.async { completion(granted && error == nil) }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    DispatchQueue.main.async { completion(granted && error == nil) }
                }
            }
        case .authorized, .fullAccess:
            completion(true)
        case .denied, .restricted:
            showSettingsAlert()
            completion(false)
        default:
            completion(false)
        }
    }

    func syncCourses(instances: [CourseInstance], startDateStr: String, firstAlert: Int?, secondAlert: Int?, calendarName: String) throws {
        // 1. 获取/创建日历
        var calendar: EKCalendar? = eventStore.calendars(for: .event).first(where: { $0.title == calendarName })
        if calendar == nil {
            calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar?.title = calendarName
            calendar?.source = eventStore.defaultCalendarForNewEvents?.source
            try eventStore.saveCalendar(calendar!, commit: true)
        }

        // 2. 清空旧事件
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let twoYearsAfter = Calendar.current.date(byAdding: .year, value: 2, to: now)!
        let predicate = eventStore.predicateForEvents(withStart: oneYearAgo, end: twoYearsAfter, calendars: [calendar!])
        for event in eventStore.events(matching: predicate) {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()

        // 3. 准备基础日期
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let firstMonday = formatter.date(from: String(startDateStr.prefix(10))) else { return }

        // 4. 写入新事件
        for instance in instances {
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            
            let rawTeacher = instance.teacher ?? ""
            let hasTeacher = !rawTeacher.isEmpty && rawTeacher != "无"
            let teacherText = hasTeacher ? rawTeacher : ""
            let periodsStr = instance.periods.map { String($0) }.joined(separator: ",")
            
            // --- 对齐 SUMMARY (标题) ---
            if instance.type == "自定义行程" {
                event.title = "【自定义】\(instance.course)"
            } else if instance.type == "常规" || instance.type == "考试" {
                event.title = instance.course
            } else {
                event.title = "\(instance.course) (\(instance.type))"
            }

            // --- 地点 LOCATION & 描述 DESCRIPTION ---
            // 使用数组管理，最后用换行符连接，这样可以自动处理空行问题
            var notesArray: [String] = []

            if instance.type == "考试" {
                event.location = instance.location
                let locationParts = instance.location.components(separatedBy: " ")
                let building = locationParts.first ?? instance.location
                let seat = locationParts.count > 1 ? locationParts[1] : "未分配"
                
                notesArray.append("地点: \(building)")
                notesArray.append("座位号: \(seat)")
                if hasTeacher { notesArray.append("教师: \(teacherText)") }
                notesArray.append("类型: \(instance.type)")
                notesArray.append("节次: \(periodsStr)")
                
            } else if instance.type == "冲突" {
                event.location = instance.location
                if let desc = instance.description, !desc.isEmpty {
                    notesArray.append(desc.replacingOccurrences(of: "\\n", with: "\n"))
                }
            } else {
                // 普通课程或自定义行程
                // 地点：如果有教师就显示 "地点 教师"，没有就只显示 "地点"
                event.location = hasTeacher ? "\(instance.location) \(teacherText)" : instance.location
                
                notesArray.append("地点: \(instance.location)")
                if hasTeacher { notesArray.append("教师: \(teacherText)") }
                notesArray.append("类型: \(instance.type)")
                notesArray.append("节次: \(periodsStr)")
            }

            // --- 追加备注 Description ---
            // 只有当 description 不为空，且不是冲突类型（避免重复）时才添加
            if let extraDesc = instance.description, !extraDesc.isEmpty, instance.type != "冲突" {
                notesArray.append("备注: \(extraDesc.replacingOccurrences(of: "\\n", with: "\n"))")
            }
            
            // 将所有非空行合并
            event.notes = notesArray.joined(separator: "\n")

            // --- 时间计算 ---
            let daysOffset = (instance.week - 1) * 7 + (instance.day - 1)
            guard let baseDate = Calendar.current.date(byAdding: .day, value: daysOffset, to: firstMonday) else { continue }
            event.startDate = combine(date: baseDate, timeStr: instance.startTime)
            event.endDate = combine(date: baseDate, timeStr: instance.endTime)

            // --- 提醒设置 ---
            event.alarms = nil
            if let first = firstAlert, first > 0 {
                event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-first * 60)))
            }
            if let second = secondAlert, second > 0 {
                event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-second * 60)))
            }

            try eventStore.save(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }
    private func combine(date: Date, timeStr: String) -> Date {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return date }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date) ?? date
    }

    private func showSettingsAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "日历权限", message: "请在设置中开启日历权限以同步课表。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "设置", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.windows.first?.rootViewController?.present(alert, animated: true)
            }
        }
    }
}

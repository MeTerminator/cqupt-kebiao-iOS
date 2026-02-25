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
        // 1. 获取日历
        var calendar: EKCalendar? = eventStore.calendars(for: .event).first(where: { $0.title == calendarName })
        if calendar == nil {
            calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar?.title = calendarName
            calendar?.source = eventStore.defaultCalendarForNewEvents?.source
            try eventStore.saveCalendar(calendar!, commit: true)
        }

        // 2. 彻底清空旧事件
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let twoYearsAfter = Calendar.current.date(byAdding: .year, value: 2, to: now)!
        let predicate = eventStore.predicateForEvents(withStart: oneYearAgo, end: twoYearsAfter, calendars: [calendar!])
        let oldEvents = eventStore.events(matching: predicate)
        
        for event in oldEvents {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit() // 先提交删除

        // 3. 准备日期格式
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let firstMonday = formatter.date(from: String(startDateStr.prefix(10))) else { return }

        // 4. 写入新事件
        for instance in instances {
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            
            // 标题逻辑：非常规类型加后缀
            if instance.type == "常规" {
                event.title = instance.course
            } else {
                event.title = "\(instance.course) (\(instance.type))"
            }
            
            event.location = instance.location
            event.notes = "教师: \(instance.teacher)\n类型: \(instance.type)\n周数: 第\(instance.week)周"

            let daysOffset = (instance.week - 1) * 7 + (instance.day - 1)
            guard let baseDate = Calendar.current.date(byAdding: .day, value: daysOffset, to: firstMonday) else { continue }
            
            event.startDate = combine(date: baseDate, timeStr: instance.startTime)
            event.endDate = combine(date: baseDate, timeStr: instance.endTime)

            event.alarms = nil // 显式清空，防止系统自动添加默认提醒
            
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

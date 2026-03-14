import Foundation

struct CourseInstance: Codable, Identifiable {
    var id: String { "\(course)_\(week)_\(day)_\(start_time)" }
    let course: String
    let teacher: String?
    let week: Int
    let day: Int
    let start_time: String
    let end_time: String
    let location: String
    let type: String

    // 辅助计算属性：将时间转换为当天的分钟数，方便排序和比较
    var startMin: Int {
        let parts = start_time.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }
    var endMin: Int {
        let parts = end_time.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }
}

extension CourseInstance {
    func progress(at date: Date) -> Double {
        let calendar = Calendar.current
        let nowMin =
            calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        let total = Double(endMin - startMin)
        if total <= 0 { return 1.0 }

        let passed = Double(nowMin - startMin)
        return max(0, min(1, passed / total))
    }
}
struct ScheduleResponse: Codable {
    let week_1_monday: String
    let instances: [CourseInstance]
}

enum CourseStatus {
    case upcoming  // 未开始
    case ongoing  // 进行中
}

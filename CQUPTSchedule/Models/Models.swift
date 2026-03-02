import Foundation

struct ScheduleResponse: Codable {
    let studentId: String
    let studentName: String
    let academicYear: String
    let semester: String
    let week1Monday: String
    let instances: [CourseInstance]
    
    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case studentName = "student_name"
        case academicYear = "academic_year"
        case semester = "semester"
        case week1Monday = "week_1_monday"
        case instances
    }
}

struct CourseInstance: Codable, Identifiable {
    var id = UUID()
    let course: String
    let teacher: String?
    let week: Int
    let day: Int
    let periods: [Int]
    let startTime: String
    let endTime: String
    let location: String
    let type: String
    let courseType: String?
    let credit: String?
    let description: String?
    var colorIndex: Int?
    
    enum CodingKeys: String, CodingKey {
        case course, teacher, week, day, periods, location, type
        case startTime = "start_time"
        case endTime = "end_time"
        case courseType = "course_type"
        case credit, description
        case colorIndex // 如果后端不返回这个字段，Codable 会自动设为 nil
    }
}

struct CustomCourse: Codable, Identifiable {
    var id = UUID()
    var title: String
    var location: String
    var description: String
    var colorIndex: Int
    var week: Int
    var day: Int
    var startPeriod: Int
    var endPeriod: Int
    
    func toInstance() -> CourseInstance {
        let periods = Array(startPeriod...endPeriod)
        
        // 获取真实时间字符串
        let startT = timeTable[startPeriod]?["begin"] ?? "08:00"
        let endT = timeTable[endPeriod]?["end"] ?? "08:45"
        
        return CourseInstance(
            id: self.id,
            course: title,
            teacher: "",
            week: week,
            day: day,
            periods: periods,
            startTime: startT,
            endTime: endT,
            location: location,
            type: "自定义行程",
            courseType: "自定义行程",
            credit: nil,
            description: description,
            colorIndex: self.colorIndex
        )
    }
}

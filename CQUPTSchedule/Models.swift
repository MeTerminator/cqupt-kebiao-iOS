//
//  Models.swift
//  CQUPTSchedule
//
//  Created by MeTerminator on 2026/2/25.
//

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
    let teacher: String
    let week: Int
    let day: Int
    let periods: [Int]
    let startTime: String
    let endTime: String
    let location: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case course, teacher, week, day, periods, location, type
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

let timeTable = [
    1: ["begin": "08:00", "end": "08:45"],
    2: ["begin": "08:55", "end": "09:40"],
    3: ["begin": "10:15", "end": "11:00"],
    4: ["begin": "11:10", "end": "11:55"],
    
    5: ["begin": "14:00", "end": "14:45"],
    6: ["begin": "14:55", "end": "15:40"],
    7: ["begin": "16:15", "end": "17:00"],
    8: ["begin": "17:10", "end": "17:55"],
    
    9: ["begin": "19:00", "end": "19:45"],
    10: ["begin": "19:55", "end": "20:40"],
    11: ["begin": "20:50", "end": "21:35"],
    12: ["begin": "21:45", "end": "22:30"],
]

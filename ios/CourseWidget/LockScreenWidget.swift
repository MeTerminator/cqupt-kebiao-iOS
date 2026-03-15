import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    var entry: CourseEntry

    var body: some View {
        contentView(now: Date())
    }

    @ViewBuilder
    func contentView(now: Date) -> some View {
        let nowMin =
            Calendar.current.component(.hour, from: now) * 60
            + Calendar.current.component(.minute, from: now)

        let todayCourses = Array(entry.courses.prefix(entry.todayCourseCount))
        let upcomingCourse =
            todayCourses.first(where: { $0.endMin > nowMin })
            ?? entry.courses.dropFirst(entry.todayCourseCount).first

        if let course = upcomingCourse {
            let isToday = todayCourses.contains(where: { $0.id == course.id })
            let isOngoing = isToday && course.startMin <= nowMin

            // 获取目标时间
            if let targetDate = combine(
                date: now, timeStr: isOngoing ? course.end_time : course.start_time,
                isTomorrow: !isToday)
            {

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        // 原生倒计时部分
                        HStack(spacing: 0) {
                            Text(isToday ? (isOngoing ? "离下课 " : "离上课 ") : "离上课 ")

                            Text(targetDate, style: .timer)
                                .font(.system(size: 16, weight: .bold))
                                .monospacedDigit()
                        }
                        .font(.system(size: 16))

                        Text(course.course).font(.system(size: 16, weight: .bold)).lineLimit(1)
                        Text(course.location).font(.system(size: 16, weight: .medium)).lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if isOngoing {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: CGFloat(course.progress(at: now)))
                                .stroke(
                                    Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 20, height: 20)
                    }
                }
            }
        } else {
            Text("近期无课程").font(.subheadline)
        }
    }

    func combine(date: Date, timeStr: String, isTomorrow: Bool) -> Date? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = h
        components.minute = m
        components.second = 0
        var targetDate = Calendar.current.date(from: components)
        if isTomorrow, let t = targetDate {
            targetDate = Calendar.current.date(byAdding: .day, value: 1, to: t)
        }
        return targetDate
    }
}

// 锁屏组件定义
struct LockScreenWidget: Widget {
    let kind: String = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("锁屏课表")
        .description("实时显示课程进度与倒计时")
        .supportedFamilies([.accessoryRectangular])
    }
}

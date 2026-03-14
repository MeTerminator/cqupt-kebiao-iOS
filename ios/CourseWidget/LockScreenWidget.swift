import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    var entry: CourseEntry

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let nowMin =
                Calendar.current.component(.hour, from: now) * 60
                + Calendar.current.component(.minute, from: now)

            if let course = entry.courses.first(where: { $0.endMin > nowMin }) {
                let isOngoing = course.startMin <= nowMin
                let targetDate =
                    isOngoing
                    ? combine(date: now, timeStr: course.end_time)
                    : combine(date: now, timeStr: course.start_time)

                // 布局核心：HStack 默认左对齐，将进度环放最前，随后是信息区
                HStack(alignment: .center, spacing: 8) {

                    // 2. 信息区：左对齐
                    VStack(alignment: .leading, spacing: 1) {
                        if let target = targetDate {
                            // 倒计时文本
                            Text(isOngoing ? " 下课" : " 上课")
                                .font(.system(size: 16))
                                + Text(target, style: .timer)
                                .font(.system(size: 16, weight: .bold))
                                .monospacedDigit()
                        }

                        Text(course.course)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        Text(course.location)
                            .font(.system(size: 16))
                            .lineLimit(1)
                    }

                    // 3. 这里的 Spacer 将内容向左顶（如果需要的话）
                    Spacer(minLength: 0)

                    // 1. 进度环：仅在进行中显示，固定在左侧
                    if isOngoing, let target = targetDate {
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
            } else {
                Text("近期无课程")
            }
        }
    }

    func combine(date: Date, timeStr: String) -> Date? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: date)
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

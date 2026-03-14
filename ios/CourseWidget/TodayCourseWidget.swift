import SwiftUI
import WidgetKit

struct TodayCourseWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        // 使用 TimelineView 包裹，确保视图在刷新时基于最新的时间上下文进行渲染
        TimelineView(.everyMinute) { context in
            // 根据组件大小分配可展示的最大行数
            let maxLines = (family == .systemLarge) ? 6 : 2

            // 1. 计算显示数量
            let todayLimit = min(entry.todayCourseCount, maxLines)
            let remainingSpace = maxLines - todayLimit
            let tomorrowLimit = min(entry.tomorrowCourseCount, remainingSpace)

            // 2. 计算未显示的课程数量
            let unshownCount =
                (entry.todayCourseCount - todayLimit) + (entry.tomorrowCourseCount - tomorrowLimit)

            // 使用顶部的对齐方式，并移除顶部的 Spacer
            VStack(alignment: .leading, spacing: 6) {
                // 头部：今日信息
                if entry.todayCourseCount > 0 {
                    HeaderView(
                        dateStr: entry.todayDateStr, count: entry.todayCourseCount,
                        weekInfo: entry.todayWeekInfo
                    )
                    .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if entry.courses.isEmpty {
                        Text("近期无课程")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        // 显示今天课程
                        ForEach(Array(entry.courses.prefix(todayLimit))) { course in
                            CourseRow(course: course)
                                .padding(.vertical, 1)
                        }

                        // 显示明天课程（如果有空间）
                        if remainingSpace > 0 && entry.tomorrowCourseCount > 0 {
                            // 明天课程的分割标题
                            HeaderView(
                                dateStr: entry.tomorrowDateStr, count: entry.tomorrowCourseCount,
                                weekInfo: entry.tomorrowWeekInfo
                            )
                            .padding(.vertical, 2)  // 增加一点间距区分日期

                            ForEach(
                                Array(
                                    entry.courses.dropFirst(entry.todayCourseCount).prefix(
                                        tomorrowLimit))
                            ) { course in
                                CourseRow(course: course)
                                    .padding(.vertical, 1)
                            }
                        }

                        // 底部居中提示文本
                        if unshownCount > 0 {
                            Text("还有 \(unshownCount) 节课未显示")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                // 这个最后的 Spacer 会将上方所有的内容“顶”到屏幕最上方
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

struct HeaderView: View {
    let dateStr: String
    let count: Int
    let weekInfo: String

    var body: some View {
        HStack {
            Text("\(dateStr) · \(count) 节课")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Text(weekInfo)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}

struct CourseRow: View {
    let course: CourseInstance
    var body: some View {
        let teacherStr = (course.teacher?.isEmpty == false) ? course.teacher! : ""

        HStack(spacing: 8) {
            // 1. 左侧彩色条
            Capsule()
                .fill(colorFor(course.course))
                .frame(width: 4, height: 34)

            // 2. 课程与地点
            VStack(alignment: .leading, spacing: 1) {
                Text(course.course)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text("\(course.location)  \(teacherStr)")
                    .font(.system(size: 14))
                    .lineLimit(1)
            }

            Spacer()

            // 3. 时间
            VStack(alignment: .trailing, spacing: 0) {
                Text(course.start_time)
                    .font(.system(size: 13, weight: .medium))
                Text(course.end_time)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }

    private func colorFor(_ name: String) -> Color {
        let colors: [Color] = [.orange, .blue, .green, .purple, .pink, .red, .cyan]
        return colors[abs(name.hashValue) % colors.count]
    }
}

struct TodayCourseWidget: Widget {
    let kind: String = "TodayCourseWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TodayCourseWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("今日课程")
        .description("按照时间顺序显示今天和明天的课程。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

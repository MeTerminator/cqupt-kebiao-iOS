import SwiftUI
import WidgetKit

struct UpcomingCourseWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: CourseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text(entry.todayDateStr)
                    .font(.system(size: 13, weight: .regular))
                Spacer()
                if family != .systemSmall {
                    Text(entry.todayWeekInfo)
                        .font(.system(size: 13, weight: .regular))
                }
            }

            // 内容区
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    // MARK: - 中号组件布局 (左右并排)
    var mediumLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                if let current = entry.courses[safe: 0] {
                    CourseBlockView(course: current, barColor: .yellow)
                } else {
                    Text("今日无更多课程")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 接下来课程 (索引 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("接下来")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                if let next = entry.courses[safe: 1] {
                    CourseBlockView(course: next, barColor: .orange)
                } else {
                    Text("无")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 小号组件布局 (上下堆叠)
    var smallLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let current = entry.courses[safe: 0] {
                CourseBlockView(course: current, barColor: .yellow)

                // 简化版的“接下来”提示
                if let next = entry.courses[safe: 1] {
                    HStack(spacing: 6) {
                        Capsule().fill(Color.orange).frame(width: 3, height: 18)
                        Text(next.course)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("今日已无课程")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 课程块视图
struct CourseBlockView: View {
    let course: CourseInstance
    let barColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(barColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(course.course)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)

                // 处理教师名称逻辑
                let teacherStr = (course.teacher?.isEmpty == false) ? course.teacher! : "未知"
                Text("\(course.location)  \(teacherStr)")
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Text("\(course.start_time) - \(course.end_time)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
            }

        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 组件定义
struct UpcomingCourseWidget: Widget {
    let kind: String = "UpcomingCourseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            UpcomingCourseWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("临近课程")
        .description("显示当前要上的课程和下一节课。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

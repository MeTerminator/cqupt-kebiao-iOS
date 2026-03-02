import SwiftUI


struct CourseBlock: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let course: CourseInstance
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let isExam = course.type.contains("考试")
        let isCustom = course.type == "自定义行程"
        
        let backgroundColor: Color = {
            if isExam {
                return colorScheme == .dark ? .white : .black
            } else if isCustom {
                // 优先读取转换过来的 colorIndex，如果没有则用 0 兜底
                let index = course.colorIndex ?? 0
                return Color.dynamicCourseColor(index: index, total: 10)
            } else {
                let colorIndex = viewModel.courseColorMap[course.course] ?? 0
                return Color.dynamicCourseColor(index: colorIndex, total: 20)
            }
        }()

        let textColor: Color = isExam ? (colorScheme == .dark ? .black : .white) : .white

        VStack(spacing: 2) {
            Spacer(minLength: 1)
            Text(course.course)
                .font(.system(size: 14, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            
            Text(course.location)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .opacity(0.9)
            
            if course.type != "常规" {
                Image(systemName: isExam ? "pencil.and.outline" : "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isExam ? .orange : .yellow)
            }
            Spacer(minLength: 1)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .foregroundColor(textColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: isCustom ? 2 : 0)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

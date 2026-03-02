import SwiftUI


struct CourseDetailView: View {
    let course: CourseInstance
    let courseDate: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("基本信息")) {
                    DetailRow(label: "课程名称", value: course.course)
                    
                    if let teacher = course.credit, !teacher.isEmpty {
                        DetailRow(label: "上课教师", value: "\(teacher)")
                    }
                    
                    DetailRow(label: "上课地点", value: course.location)
                    
                    if let credit = course.credit, !credit.isEmpty {
                        DetailRow(label: "学分", value: "\(credit)")
                    }
                    
                    if let cType = course.courseType, !cType.isEmpty {
                        DetailRow(label: "课程性质", value: cType)
                    }
                    
                }
                
                Section(header: Text("时间安排")) {
                    DetailRow(label: "上课日期", value: courseDate)
                    DetailRow(label: "周数/星期", value: "第\(course.week)周 星期\(getChineseDay(course.day))")
                    DetailRow(label: "具体时间", value: "\(course.startTime) - \(course.endTime)")
                    DetailRow(label: "上课节数", value: course.periods.map{String($0)}.joined(separator: ", "))
                    DetailRow(label: "形式", value: course.type)
                }
                
                if let desc = course.description, !desc.isEmpty {
                    Section(header: Text("备注")) {
                        Text(desc)
                            .font(.subheadline)
                            .lineSpacing(4) // 增加行间距提高可读性
                            .padding(.vertical, 4)
                            .fixedSize(horizontal: false, vertical: true) // 强制垂直方向自适应，防止长文本被截断
                    }
                }
            }
            .navigationTitle("课程详情")
            .navigationBarItems(trailing: Button("完成") { presentationMode.wrappedValue.dismiss() })
        }
    }
    
    private func getChineseDay(_ day: Int) -> String {
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        return (day >= 1 && day <= 7) ? days[day - 1] : ""
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View { HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).bold() } }
}

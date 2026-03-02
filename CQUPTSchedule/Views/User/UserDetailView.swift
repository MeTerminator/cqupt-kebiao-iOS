import SwiftUI

struct UserDetailView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var showCalendarSheet: Bool
    
    @State private var editingItem: CustomCourse? = nil
    
    var logout: () -> Void
    @Environment(\.presentationMode) var pm
    
    var body: some View {
        NavigationView {
            List {
                Section("个人信息") {
                    infoRow(title: "姓名", value: viewModel.scheduleData?.studentName ?? "")
                    infoRow(title: "学号", value: viewModel.scheduleData?.studentId ?? "")
                }
                
                Section("学期信息") {
                    infoRow(title: "学年", value: viewModel.scheduleData?.academicYear ?? "")
                    infoRow(title: "学期", value: "第 \(viewModel.scheduleData?.semester ?? "") 学期")
                    infoRow(title: "开学日期", value: String(viewModel.scheduleData?.week1Monday.prefix(10) ?? ""))
                }
                
                Section("同步选项") {
                    NavigationLink(destination: CalendarExportView(viewModel: viewModel)) {
                        Label("同步课表至系统日历", systemImage: "calendar.badge.plus")
                            .foregroundColor(.primary)
                    }
                }
                
                Section("自定义行程管理") {
                    if viewModel.customCourses.isEmpty {
                        Text("暂无自定义行程").foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.customCourses) { item in
                            CustomCourseRow(item: item) {
                                // 只需要给 item 赋值，sheet 就会自动弹出
                                self.editingItem = item
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.deleteCustomCourse(at: indexSet)
                        }
                    }
                    
                    if !viewModel.customCourses.isEmpty {
                        Button("清空所有自定义行程", role: .destructive) {
                            viewModel.clearAllCustomCourses()
                        }
                    }
                }
                
                Section {
                    Button("退出登录", role: .destructive) {
                        logout()
                        pm.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("用户详情")
            .navigationBarItems(trailing: Button("完成") { pm.wrappedValue.dismiss() })
            .sheet(item: $editingItem) { course in
                AddCustomCourseView(viewModel: viewModel, editingCourse: course)
                    .id(course.id)
            }
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}

// 子视图部分保持不变
struct CustomCourseRow: View {
    let item: CustomCourse
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(Color.dynamicCourseColor(index: item.colorIndex, total: 10))
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).bold().foregroundColor(.primary)
                    Text("第\(item.week)周 周\(getChineseDay(item.day)) \(item.startPeriod)-\(item.endPeriod)节")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "pencil").font(.caption).foregroundColor(.secondary)
            }
        }
    }
    
    private func getChineseDay(_ day: Int) -> String {
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        return (day >= 1 && day <= 7) ? days[day - 1] : ""
    }
}

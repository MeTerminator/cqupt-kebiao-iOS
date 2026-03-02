import SwiftUI

struct AddCustomCourseView: View {
    @Environment(\.presentationMode) var pm
    @ObservedObject var viewModel: ScheduleViewModel
    
    // 待编辑的课程（如果是新增则为 nil）
    private var editingCourse: CustomCourse?
    
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var description: String = ""
    @State private var selectedWeek: Int = 1
    @State private var selectedDay: Int = 1
    @State private var startPeriod: Int = 1
    @State private var endPeriod: Int = 2
    @State private var colorIndex: Int = 0
    
    init(viewModel: ScheduleViewModel, editingCourse: CustomCourse? = nil) {
        self.viewModel = viewModel
        self.editingCourse = editingCourse
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("行程标题 (必填)", text: $title)
                    TextField("地点", text: $location)
                    TextField("备注", text: $description)
                }
                
                Section(header: Text("时间选择")) {
                    Picker("周数", selection: $selectedWeek) {
                        ForEach(0...20, id: \.self) { w in
                            Text("第 \(w) 周").tag(w)
                        }
                    }
                    
                    Picker("星期", selection: $selectedDay) {
                        ForEach(1...7, id: \.self) { d in
                            Text("星期\(getChineseDay(d))").tag(d)
                        }
                    }
                    
                    HStack {
                        Picker("开始节", selection: $startPeriod) {
                            ForEach(1...12, id: \.self) { i in Text("\(i)").tag(i) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .onChange(of: startPeriod) { _, new in
                            if endPeriod < new { endPeriod = new }
                        }
                        
                        Text("至")
                        
                        Picker("结束节", selection: $endPeriod) {
                            ForEach(1...12, id: \.self) { i in Text("\(i)").tag(i) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .onChange(of: endPeriod) { _, new in
                            if startPeriod > new { startPeriod = new }
                        }
                    }
                }
                
                Section(header: Text("外观颜色")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
                        ForEach(0..<10, id: \.self) { index in
                            Circle()
                                .fill(Color.dynamicCourseColor(index: index, total: 10))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .opacity(colorIndex == index ? 1 : 0)
                                )
                                .onTapGesture {
                                    colorIndex = index
                                }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle(editingCourse == nil ? "添加自定义行程" : "编辑行程")
            .navigationBarItems(
                leading: Button("取消") { pm.wrappedValue.dismiss() },
                trailing: Button(editingCourse == nil ? "添加" : "保存") {
                    saveAction()
                }
                .disabled(title.isEmpty)
            )
            .onAppear {
                if let course = editingCourse {
                    title = course.title
                    location = course.location
                    // --- 修复点：直接赋值，不使用 ?? ---
                    description = course.description
                    selectedWeek = course.week
                    selectedDay = course.day
                    startPeriod = course.startPeriod
                    endPeriod = course.endPeriod
                    colorIndex = course.colorIndex
                } else {
                    selectedWeek = viewModel.selectedWeek
                    selectedDay = viewModel.currentDayOfWeek
                }
            }
        }
    }
    
    private func saveAction() {
        let newCourse = CustomCourse(
            id: editingCourse?.id ?? UUID(),
            title: title,
            location: location,
            description: description,
            colorIndex: colorIndex,
            week: selectedWeek,
            day: selectedDay,
            startPeriod: startPeriod,
            endPeriod: endPeriod
        )
        
        if editingCourse != nil {
            viewModel.updateCustomCourse(newCourse)
        } else {
            viewModel.addCustomCourse(newCourse)
        }
        pm.wrappedValue.dismiss()
    }
    
    private func getChineseDay(_ day: Int) -> String {
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        return (day >= 1 && day <= 7) ? days[day - 1] : ""
    }
}

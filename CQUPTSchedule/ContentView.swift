//
//  ContentView.swift
//  CQUPTSchedule
//
//  Created by MeTerminator on 2026/2/25.
//

import SwiftUI

// MARK: - 主界面
struct ContentView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @AppStorage("saved_id") private var savedId: String = ""
    @AppStorage("is_logged_in") private var isLoggedIn: Bool = false
    
    @State private var inputId: String = ""
    @State private var selectedCourse: CourseInstance?
    @State private var showUserSheet = false
    @State private var showCalendarSheet = false

    private func calculateDate(week: Int, day: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let startStr = viewModel.scheduleData?.week1Monday.prefix(10),
              let startDate = formatter.date(from: String(startStr)) else {
            return "未知日期"
        }
        
        // 计算偏移量：(周数-1)*7 + (星期几-1)
        let offset = (week - 1) * 7 + (day - 1)
        if let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: startDate) {
            let outFormatter = DateFormatter()
            outFormatter.dateFormat = "yyyy年M月d日"
            return outFormatter.string(from: targetDate)
        }
        return "日期错误"
    }
    
    var body: some View {
        // 使用 ZStack 将提示框置于顶层
        ZStack(alignment: .top) {
            NavigationView {
                if isLoggedIn {
                    VStack(spacing: 0) {
                        HeaderView(
                            viewModel: viewModel,
                            showUser: $showUserSheet,
                            showCalendarSheet: $showCalendarSheet
                        )
                        
                        TabView(selection: $viewModel.selectedWeek) {
                            ForEach(1...20, id: \.self) { week in
                                ScheduleGrid(viewModel: viewModel, weekToShow: week) { course in
                                    self.selectedCourse = course
                                }
                                .tag(week)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                    .navigationBarHidden(true)
                    .sheet(item: $selectedCourse) { course in
                        // 在这里计算该课程的具体日期
                        let dateString = calculateDate(week: course.week, day: course.day)
                        CourseDetailView(course: course, courseDate: dateString)
                    }
                    .sheet(isPresented: $showUserSheet) {
                        UserDetailView(viewModel: viewModel) {
                            isLoggedIn = false
                            savedId = ""
                        }
                    }
                    .sheet(isPresented: $showCalendarSheet) {
                        CalendarExportView(viewModel: viewModel)
                    }
                    .onAppear { viewModel.startup(studentId: savedId) }
                } else {
                    LoginView(id: $inputId) {
                        savedId = inputId
                        isLoggedIn = true
                        viewModel.startup(studentId: inputId)
                    }
                }
            }
            .navigationViewStyle(.stack)
            
            // 提示框逻辑：放在 NavigationView 同级，确保层级最高
            if viewModel.showToast {
                Text(viewModel.toastMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(25)
                    .padding(.top, 15) // 这里的数值可以根据是否有刘海屏微调
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(1)
            }
        }
        // 必须添加这个动画关联，否则 transition 不生效
        .animation(.spring(), value: viewModel.showToast)
    }
}


// MARK: - 顶部操作栏
struct HeaderView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var showUser: Bool
    @Binding var showCalendarSheet: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatToSchedule()).font(.system(size: 22, weight: .bold))
                HStack {
                    Text("第\(viewModel.selectedWeek)周")
                    Text(viewModel.isCurrentWeekReal ? "本周" : "非本周")
                        .padding(.horizontal, 6).background(Color.secondary.opacity(0.1)).cornerRadius(4)
                }.font(.system(size: 14)).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 20) {
                // --- 导入日历按钮 ---
                Button(action: { showCalendarSheet = true }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 20))
                }
                
                Button(action: { viewModel.refreshData() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 20))
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(viewModel.isLoading ? .linear.repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                }
                
                Button(action: { showUser = true }) {
                    Image(systemName: "person.circle").font(.system(size: 24))
                }
            }
        }.padding()
    }
}

// MARK: - 课程表格
struct ScheduleGrid: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let weekToShow: Int
    let detailAction: (CourseInstance) -> Void
    
    private var hourHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 100 : 70
    }
    
    // --- 日期计算逻辑 ---
    private func getDate(for dayIndex: Int) -> (month: String, day: String) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // 解析第一周周一的日期
        guard let startDateString = viewModel.scheduleData?.week1Monday.prefix(10),
              let startDate = formatter.date(from: String(startDateString)) else {
            return ("", "")
        }
        
        // 计算偏移量：(周数-1)*7 + (礼拜几-1)
        let offsetDays = (weekToShow - 1) * 7 + dayIndex
        if let targetDate = calendar.date(byAdding: .day, value: offsetDays, to: startDate) {
            let day = calendar.component(.day, from: targetDate)
            let month = calendar.component(.month, from: targetDate)
            return ("\(month)", "\(day)")
        }
        return ("", "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部：显示月份和日期数字
            HStack(spacing: 0) {
                // 左上角月份显示
                Text("\(getDate(for: 0).month)\n月")
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(width: 45)
                
                ForEach(0..<7, id: \.self) { index in
                    let dayNames = ["一", "二", "三", "四", "五", "六", "日"]
                    let dateInfo = getDate(for: index)
                    
                    VStack(spacing: 2) {
                        Text(dayNames[index])
                            .font(.system(size: 14, weight: .medium))
                        Text(dateInfo.day)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .background(isToday(dayIndex: index) ? Color.secondary.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                }
            }
            .padding(.bottom, 10)
            
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    // --- 左侧时间/节数栏 ---
                    VStack(spacing: 0) {
                        ForEach(1...12, id: \.self) { i in
                            VStack {
                                Text("\(i)").bold()
                                if let t = timeTable[i] {
                                    Text(t["begin"]!).font(.system(size: 8))
                                    Text(t["end"]!).font(.system(size: 8))
                                }
                            }
                            .frame(width: 45, height: hourHeight)
                            .foregroundColor(.gray)
                            // 分段背景色设置
                            .background(
                                Group {
                                    if i >= 1 && i <= 4 {
                                        Color.green.opacity(0.12) // 1-4节：绿色
                                    } else if i >= 5 && i <= 8 {
                                        Color.blue.opacity(0.12)  // 5-8节：蓝色
                                    } else if i >= 9 && i <= 12 {
                                        Color.purple.opacity(0.12)// 9-12节：紫色
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                        }
                    }
                    
                    // --- 右侧课程格子区域 ---
                    GeometryReader { geo in
                        let colW = geo.size.width / 7
                        ZStack(alignment: .topLeading) {
                            // 绘制背景横线
                            ForEach(0...12, id: \.self) { i in
                                Path { p in
                                    p.move(to: .init(x: 0, y: CGFloat(i)*hourHeight))
                                    p.addLine(to: .init(x: geo.size.width, y: CGFloat(i)*hourHeight))
                                }
                                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                            }
                            
                            // 渲染课程块
                            let courses = viewModel.scheduleData?.instances.filter { $0.week == weekToShow } ?? []
                            ForEach(courses) { course in
                                CourseBlock(viewModel: viewModel, course: course)
                                    .frame(width: colW - 2, height: CGFloat(course.periods.count) * hourHeight - 2)
                                    .offset(x: CGFloat(course.day-1)*colW + 1, y: CGFloat(course.periods.first!-1)*hourHeight + 1)
                                    .onTapGesture { detailAction(course) }
                            }
                        }
                    }
                    .frame(height: hourHeight * 12)
                }
            }
        }
    }
    
    // 辅助函数：判断是否为正在显示的这一天
    private func isToday(dayIndex: Int) -> Bool {
        guard viewModel.isCurrentWeekReal && weekToShow == viewModel.selectedWeek else {
            return false
        }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // 将系统 weekday (周日1, 周一2...) 转换为 0-6 (周一0...周日6)
        let normalizedTodayIndex = (weekday + 5) % 7
        return dayIndex == normalizedTodayIndex
    }
}
// MARK: - 课程块
struct CourseBlock: View {
    @ObservedObject var viewModel: ScheduleViewModel // 引入观察，以便获取课程总数和索引
    let course: CourseInstance
    
    var body: some View {
        // 1. 获取当前课程在总名单中的索引
        let colorIndex = viewModel.courseColorMap[course.course] ?? 0
        // 2. 获取本学期总课程数
        let totalCourses = viewModel.courseColorMap.count
        
        ZStack {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // 1. 课程名称
                        Text(course.course)
                            .font(.system(size: 14, weight: .bold)) // 稍微调小一点适配小格子
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true) // 允许换行
                        
                        Text("").frame(height: 4)
                        
                        // 2. 上课地点
                        Text(course.location)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                        
                        // 3. 黄色五角星：移动到地点下方
                        if course.type != "常规" {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                                .padding(.top, 2)
                        }
                        
                        Spacer()
                    }
                    .padding(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dynamicCourseColor(index: colorIndex, total: totalCourses))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
    }
}

// MARK: - 用户详情页
struct UserDetailView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    var logout: () -> Void
    @Environment(\.presentationMode) var pm
    
    var body: some View {
        NavigationView {
            List {
                Section("个人信息") {
                    HStack { Text("姓名"); Spacer(); Text(viewModel.scheduleData?.studentName ?? "") }
                    HStack { Text("学号"); Spacer(); Text(viewModel.scheduleData?.studentId ?? "") }
                }
                Section("学期信息") {
                    HStack { Text("学年"); Spacer(); Text(viewModel.scheduleData?.academicYear ?? "") }
                    HStack { Text("学期"); Spacer(); Text("第 \(viewModel.scheduleData?.semester ?? "") 学期") }
                    HStack { Text("开学日期"); Spacer(); Text(String(viewModel.scheduleData?.week1Monday.prefix(10) ?? "")) }
                }
                Button("退出登录", role: .destructive) { logout(); pm.wrappedValue.dismiss() }.frame(maxWidth: .infinity)
            }
            .navigationTitle("用户详情").navigationBarItems(trailing: Button("完成") { pm.wrappedValue.dismiss() })
        }
    }
}

// MARK: - 登录页
struct LoginView: View {
    @Binding var id: String
    var action: () -> Void
    
    // 适配深色模式的颜色定义
    private var schoolGreen: Color { Color(red: 0.0, green: 0.48, blue: 0.35) }
    private var inputBackground: Color { Color(UIColor.secondarySystemBackground) }
    
    // 校验学号
    private var isValidId: Bool {
        id.count == 10 && id.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 40) {
                // 顶部 Logo
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(schoolGreen.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(schoolGreen)
                    }
                    
                    Text("重邮课表")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        // 使用 primary 会根据深浅模式自动切换黑白
                        .foregroundColor(.primary)
                }
                .padding(.top, 60)
                
                // 输入区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("学号登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(schoolGreen)
                        
                        TextField("请输入10位学号", text: $id)
                            .keyboardType(.numberPad)
                            .onChange(of: id) { oldValue, newValue in
                                if newValue.count > 10 {
                                    id = String(newValue.prefix(10))
                                }
                            }
                    }
                    .padding()
                    .background(inputBackground) // 使用系统二级背景色
                    .cornerRadius(15)
                    
                    // 校验提示
                    if !id.isEmpty && !isValidId {
                        Text("学号应为10位数字")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 40)
                
                // 登录按钮
                Button(action: action) {
                    Text("进入课表")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(isValidId ? schoolGreen : Color.gray.opacity(0.3))
                        .cornerRadius(15)
                        .shadow(color: isValidId ? schoolGreen.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                }
                .disabled(!isValidId)
                .frame(maxWidth: 400)
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        // 关键：强制让 ZStack 响应环境变化
        .animation(.easeInOut, value: id)
    }
}

// MARK: - 课程详情页
struct CourseDetailView: View {
    let course: CourseInstance
    let courseDate: String  // 新增：用于接收计算好的具体日期
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("基本信息")) {
                    DetailRow(label: "课程名称", value: course.course)
                    DetailRow(label: "上课教师", value: course.teacher)
                    DetailRow(label: "上课地点", value: course.location)
                }
                Section(header: Text("时间安排")) {
                    // 添加这一行显示具体日期
                    DetailRow(label: "上课日期", value: courseDate)
                    
                    DetailRow(label: "周数/星期", value: "第\(course.week)周 星期\(getChineseDay(course.day))")
                    DetailRow(label: "具体时间", value: "\(course.startTime) - \(course.endTime)")
                    DetailRow(label: "上课节数", value: course.periods.map{String($0)}.joined(separator: ", "))
                    DetailRow(label: "课程类型", value: course.type)
                }
            }
            .navigationTitle("课程详情")
            .navigationBarItems(trailing: Button("关闭") { presentationMode.wrappedValue.dismiss() })
        }
    }
    
    // 辅助函数：数字转中文星期
    private func getChineseDay(_ day: Int) -> String {
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        return (day >= 1 && day <= 7) ? days[day - 1] : ""
    }
}

// MARK: - 日历导出配置页
struct CalendarExportView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.presentationMode) var pm
    
    @State private var calendarName = "重邮课表"
    @State private var enableAlarm = true
    @State private var firstAlert: Int = 30
    @State private var secondAlert: Int = 10
    
    let options = [5, 10, 15, 30, 45, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("日历设置"), footer: Text("注意：同步将彻底清空系统日历中名为“\(calendarName)”的所有现有事件。").foregroundColor(.red)) {
                    HStack {
                        Text("日历名称")
                        TextField("请输入日历名称", text: $calendarName)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("提醒设置")) {
                    Toggle("开启上课提醒", isOn: $enableAlarm)
                    
                    if enableAlarm {
                        // 第一次提醒选择器
                        Picker("第一次提醒", selection: $firstAlert) {
                            ForEach(options, id: \.self) { min in
                                Text("前 \(min) 分钟").tag(min)
                            }
                        }
                        // 适配 iOS 17 的新语法：onChange(of: newValue)
                        .onChange(of: firstAlert) { oldValue, newValue in
                            if secondAlert >= newValue {
                                secondAlert = 0
                            }
                        }
                        
                        // 第二次提醒选择器
                        Picker("第二次提醒", selection: $secondAlert) {
                            Text("不设置").tag(0)
                            ForEach(options.filter { $0 < firstAlert }, id: \.self) { min in
                                Text("前 \(min) 分钟").tag(min)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        let first = enableAlarm ? firstAlert : nil
                        let second = (enableAlarm && secondAlert > 0) ? secondAlert : nil
                        let finalName = calendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "重邮课表" : calendarName
                        
                        viewModel.exportToCalendar(
                            firstAlert: first,
                            secondAlert: second,
                            calendarName: finalName
                        )
                        pm.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView().padding(.trailing, 8)
                            }
                            Text("清空并覆盖同步").bold()
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .foregroundColor(.white)
                    .listRowBackground(viewModel.isLoading ? Color.gray : Color.blue)
                }
            }
            .navigationTitle("日历同步")
            .navigationBarItems(leading: Button("取消") { pm.wrappedValue.dismiss() })
        }
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View { HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).bold() } }
}

extension Color {
    // 接受当前索引和总课程数来均分色环
    static func dynamicCourseColor(index: Int, total: Int) -> Color {
        guard total > 0 else { return .blue }
        
        // 使用质数步长跳跃选色，避免色环上相邻的颜色太像
        let step = 7
        let steppedIndex = (index * step) % total
        let hue = Double(steppedIndex) / Double(total)
        
        // 亮度 0.6 确保白色文字清晰
        return Color(hue: hue, saturation: 0.7, brightness: 0.6)
    }
}

extension Date {
    func formatToSchedule() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/M/d"; return f.string(from: self)
    }
}


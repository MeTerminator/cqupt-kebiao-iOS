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
                            ForEach(0...20, id: \.self) { week in
                                ScheduleGrid(viewModel: viewModel, weekToShow: week) { course in
                                    self.selectedCourse = course
                                }
                                .tag(week)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.6), value: viewModel.selectedWeek)
                        
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
            // --- 左侧：日期与当前显示周数 ---
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatToSchedule())
                    .font(.system(size: 22, weight: .bold))
                
                HStack(spacing: 6) {
                    Text("第\(viewModel.selectedWeek)周")
                        .fontWeight(.semibold)
                    
                    let realWeek = viewModel.calculateCurrentRealWeek()
                    Text(realWeek == 0 ? "开学准备" : (realWeek < 0 ? "未开学" : (viewModel.isCurrentWeekReal ? "本周" : "非当前周")))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(viewModel.isCurrentWeekReal ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                        .foregroundColor(viewModel.isCurrentWeekReal ? .green : .secondary)
                        .cornerRadius(4)
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // --- 右侧：功能按钮组 ---
            HStack(spacing: 16) {
                // 1. 动态返回按钮
                if !viewModel.isCurrentWeekReal {
                    Button(action: {
                        let realWeek = viewModel.calculateCurrentRealWeek()
                        var targetWeek: Int
                        
                        if realWeek <= 0 {
                            let hasCourseInWeek0 = viewModel.scheduleData?.instances.contains { $0.week == 0 } ?? false
                            targetWeek = hasCourseInWeek0 ? 0 : 1
                        } else {
                            targetWeek = min(realWeek, 20)
                        }
                        
                        // --- 核心修改：明确指定时长和类型 ---
                        withAnimation(.easeInOut(duration: 0.6)) {
                            viewModel.selectedWeek = targetWeek
                        }
                        
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                    // 按钮本身的消失动画
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.8))
                    ))
                }

                // 2. 导入日历按钮
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCalendarSheet = true
                }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 20))
                }
                
                // 3. 刷新按钮
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.refreshData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                }
                
                // 4. 个人中心按钮
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showUser = true
                }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                }
            }
            .foregroundColor(.primary)
            // 关键：使右侧按钮在返回按钮消失时，位置平滑移动
            .animation(.spring(response: 0.35), value: viewModel.isCurrentWeekReal)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
}

// MARK: - 课程表格
struct ScheduleGrid: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let weekToShow: Int
    let detailAction: (CourseInstance) -> Void
    
    // 基础高度基准
    private var hourHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 100 : 70
    }
    
    // 辅助函数：将 "HH:mm" 转为分钟数
    private func toMinutes(_ timeStr: String) -> Int {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return 0 }
        return h * 60 + m
    }

    // 计算位置和高度的核心逻辑
    private func calculateGeometry(for course: CourseInstance) -> (y: CGFloat, height: CGFloat) {
        guard let firstP = course.periods.first, let lastP = course.periods.last,
              let stdBegin = timeTable[firstP]?["begin"],
              let stdEnd = timeTable[lastP]?["end"] else {
            return (0, 0)
        }

        // 1. 计算标准锚点：第 N 节课在格子里本该在的位置
        let standardY = CGFloat(firstP - 1) * hourHeight
        let standardHeight = CGFloat(course.periods.count) * hourHeight

        // 2. 计算偏差（分钟）
        // 比例尺：假设标准一节课（含课间）45-55分钟对应一个 hourHeight，取 50 为平均参考
        let pixelsPerMinute = hourHeight / 50.0
        
        let startDiff = CGFloat(toMinutes(course.startTime) - toMinutes(stdBegin))
        let endDiff = CGFloat(toMinutes(course.endTime) - toMinutes(stdEnd))

        // 3. 应用偏差
        let finalY = standardY + (startDiff * pixelsPerMinute)
        // 高度 = 原始标准高度 - 顶部偏移 + 底部偏移
        let finalHeight = standardHeight - (startDiff * pixelsPerMinute) + (endDiff * pixelsPerMinute)

        return (finalY, max(finalHeight, 30)) // 确保高度不小于30
    }

    private func getDate(for dayIndex: Int) -> (month: String, day: String) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let startStr = viewModel.scheduleData?.week1Monday.prefix(10),
              let startDate = formatter.date(from: String(startStr)) else { return ("", "") }
        let offset = (weekToShow - 1) * 7 + dayIndex
        if let targetDate = calendar.date(byAdding: .day, value: offset, to: startDate) {
            return ("\(calendar.component(.month, from: targetDate))", "\(calendar.component(.day, from: targetDate))")
        }
        return ("", "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部日期栏
            HStack(spacing: 0) {
                Text("\(getDate(for: 0).month)\n月").font(.system(size: 11)).foregroundColor(.secondary).frame(width: 45)
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text(["一","二","三","四","五","六","日"][i]).font(.system(size: 14, weight: .medium))
                        Text(getDate(for: i).day).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .background(isToday(dayIndex: i) ? Color.secondary.opacity(0.1) : Color.clear).cornerRadius(4)
                }
            }
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // 左侧节数时间轴
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
                            .background(i <= 4 ? Color.green.opacity(0.08) : (i <= 8 ? Color.blue.opacity(0.08) : Color.purple.opacity(0.08)))
                        }
                    }

                    // 右侧课程格子
                    GeometryReader { geo in
                        let colW = geo.size.width / 7
                        ZStack(alignment: .topLeading) {
                            // 背景横线
                            ForEach(0...12, id: \.self) { i in
                                Path { p in
                                    p.move(to: .init(x: 0, y: CGFloat(i)*hourHeight))
                                    p.addLine(to: .init(x: geo.size.width, y: CGFloat(i)*hourHeight))
                                }.stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                            }

                            let courses = viewModel.scheduleData?.instances.filter { $0.week == weekToShow } ?? []
                            ForEach(courses) { course in
                                let geoInfo = calculateGeometry(for: course)
                                CourseBlock(viewModel: viewModel, course: course)
                                    .frame(width: colW - 2, height: geoInfo.height - 2)
                                    .offset(x: CGFloat(course.day-1)*colW + 1, y: geoInfo.y + 1)
                                    .onTapGesture { detailAction(course) }
                            }
                        }
                    }
                    .frame(height: hourHeight * 12)
                }
            }
        }
    }

    private func isToday(dayIndex: Int) -> Bool {
        guard viewModel.isCurrentWeekReal && weekToShow == viewModel.selectedWeek else { return false }
        let weekday = Calendar.current.component(.weekday, from: Date())
        return dayIndex == (weekday + 5) % 7
    }
}

// MARK: - 课程块
struct CourseBlock: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let course: CourseInstance
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let isExam = course.type.contains("考试")
        
        let backgroundColor: Color = {
            if isExam {
                return colorScheme == .dark ? .white : .black
            } else {
                // 使用优化过的排序索引颜色，避免刷新变色
                let colorIndex = viewModel.courseColorMap[course.course] ?? 0
                return Color.dynamicCourseColor(index: colorIndex)
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
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// 建议同步更新 Color 扩展（黄金分割法防止变红变蓝）
extension Color {
    static func dynamicCourseColor(index: Int) -> Color {
        let goldenRatio = 0.618033988749895
        let hue = (Double(index) * goldenRatio).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
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


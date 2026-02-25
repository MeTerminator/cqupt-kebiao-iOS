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

    var body: some View {
        // 使用 ZStack 将提示框置于顶层
        ZStack(alignment: .top) {
            NavigationView {
                if isLoggedIn {
                    VStack(spacing: 0) {
                        HeaderView(viewModel: viewModel, showUser: $showUserSheet)
                        
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
                    .sheet(item: $selectedCourse) { CourseDetailView(course: $0) }
                    .sheet(isPresented: $showUserSheet) {
                        UserDetailView(viewModel: viewModel) {
                            isLoggedIn = false
                            savedId = ""
                        }
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
    
    // 如果是 iPad，格子高度增加到 100
    private var hourHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 100 : 70
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("月").font(.system(size: 10)).frame(width: 45)
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day).frame(maxWidth: .infinity).font(.system(size: 14))
                }
            }.padding(.bottom, 10)
            
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(1...14, id: \.self) { i in
                            VStack {
                                Text("\(i)").bold()
                                if let t = timeTable[i] {
                                    Text(t["begin"]!).font(.system(size: 8))
                                    Text(t["end"]!).font(.system(size: 8))
                                }
                            }.frame(width: 45, height: hourHeight).foregroundColor(.gray)
                        }
                    }
                    GeometryReader { geo in
                        let colW = geo.size.width / 7
                        ZStack(alignment: .topLeading) {
                            ForEach(0...14, id: \.self) { i in
                                Path { p in p.move(to: .init(x: 0, y: CGFloat(i)*hourHeight)); p.addLine(to: .init(x: geo.size.width, y: CGFloat(i)*hourHeight)) }
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                            }
                            let courses = viewModel.scheduleData?.instances.filter { $0.week == weekToShow } ?? []
                            ForEach(courses) { course in
                                CourseBlock(viewModel: viewModel, course: course)
                                    .frame(width: colW - 2, height: CGFloat(course.periods.count) * hourHeight - 2)
                                    .offset(x: CGFloat(course.day-1)*colW + 1, y: CGFloat(course.periods.first!-1)*hourHeight + 1)
                                    .onTapGesture { detailAction(course) }
                            }
                        }
                    }.frame(height: hourHeight * 14)
                }
            }
        }
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
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Spacer()
                Text(course.course)
                    .font(.system(size: 14, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("").frame(height: 5)
                
                Text(course.location)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 3. 使用动态均分色环算法
            .background(Color.dynamicCourseColor(index: colorIndex, total: totalCourses))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            if course.type != "常规" {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                    .padding(.top, 4)
            }
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
                    DetailRow(label: "上课时间", value: "\(course.startTime) - \(course.endTime)")
                    DetailRow(label: "上课节数", value: course.periods.map{String($0)}.joined(separator: ","))
                    DetailRow(label: "课程类型", value: course.type)
                }
            }
            .navigationTitle("课程详情")
            .navigationBarItems(trailing: Button("关闭") { presentationMode.wrappedValue.dismiss() })
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

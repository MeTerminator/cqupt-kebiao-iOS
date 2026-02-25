//
//  ContentView.swift
//  CQUPTSchedule
//
//  Created by MeTerminator on 2026/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @AppStorage("saved_id") private var savedId: String = ""
    @AppStorage("is_logged_in") private var isLoggedIn: Bool = false
    
    @State private var inputId: String = ""
    @State private var selectedCourse: CourseInstance?
    @State private var showUserSheet = false

    var body: some View {
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
                .alert(isPresented: $viewModel.showAlert) {
                    Alert(title: Text("提示"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("确定")))
                }
                .sheet(item: $selectedCourse) { CourseDetailView(course: $0) }
                .sheet(isPresented: $showUserSheet) {
                    UserDetailView(viewModel: viewModel) {
                        isLoggedIn = false
                        savedId = ""
                    }
                }
                // 【修复1】：调用 viewModel 实例的 startup 方法
                .onAppear { viewModel.startup(studentId: savedId) }
            } else {
                LoginView(id: $inputId) {
                    savedId = inputId
                    isLoggedIn = true
                    // 【修复2】：调用 viewModel 的 startup 方法
                    viewModel.startup(studentId: inputId)
                }
            }
        }
    }
}

// MARK: - Subviews
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

struct ScheduleGrid: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let weekToShow: Int
    let detailAction: (CourseInstance) -> Void
    let hourHeight: CGFloat = 70
    
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
                                CourseBlock(course: course)
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

struct CourseBlock: View {
    let course: CourseInstance
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Spacer()
                Text(course.course).font(.system(size: 12, weight: .bold)).multilineTextAlignment(.center)
                Text("").frame(height: 8) // 空一行
                Text(course.location).font(.system(size: 11)).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(4).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.courseColor(course.course)).foregroundColor(.white).cornerRadius(8)
            
            if course.type != "常规" {
                Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow).padding(.top, 4)
            }
        }
    }
}

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

struct LoginView: View {
    @Binding var id: String
    var action: () -> Void
    var body: some View {
        VStack(spacing: 30) {
            Text("CQUPT 课表").font(.largeTitle.bold())
            TextField("输入学号", text: $id).textFieldStyle(.roundedBorder).padding(.horizontal, 50).keyboardType(.numberPad)
            Button(action: action) {
                Text("进入课表").bold().frame(width: 200, height: 50).background(Color.blue).foregroundColor(.white).cornerRadius(12)
            }
        }
    }
}

// MARK: - 详情弹窗
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
    static func courseColor(_ name: String) -> Color {
        let hash = abs(name.hashValue)
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.6, brightness: 0.8)
    }
}

extension Date {
    func formatToSchedule() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/M/d"; return f.string(from: self)
    }
}

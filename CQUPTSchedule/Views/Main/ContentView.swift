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
    @State private var showCalendarSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            NavigationView {
                if isLoggedIn {
                    VStack(spacing: 0) {
                        // 顶部操作栏
                        HeaderView(viewModel: viewModel, showUser: $showUserSheet)
                        
                        // 分周滑动视图
                        TabView(selection: $viewModel.selectedWeek) {
                            ForEach(Array(0...20), id: \.self) { week in
                                ScheduleGrid(viewModel: viewModel, weekToShow: week) { course in
                                    self.selectedCourse = course
                                }
                                .tag(week) // 这里的 tag 必须是 Int，对应 selectedWeek
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.6), value: viewModel.selectedWeek)
                    }
                    .navigationBarHidden(true)
                    .sheet(item: $selectedCourse) { course in
                        CourseDetailView(course: course, courseDate: calculateDate(week: course.week, day: course.day))
                    }
                    .sheet(isPresented: $showUserSheet) {
                        UserDetailView(viewModel: viewModel, showCalendarSheet: $showCalendarSheet) {
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
            
            // 全局 Toast 提示
            if viewModel.showToast {
                ToastView(message: viewModel.toastMessage)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    .zIndex(10000)
            }
        }
    }
    
    // 计算课程对应的具体日期字符串
    private func calculateDate(week: Int, day: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let startStr = viewModel.scheduleData?.week1Monday.prefix(10),
              let startDate = formatter.date(from: String(startStr)) else { return "未知日期" }
        
        // (周数-1)*7 + (周几-1)
        let offset = (week - 1) * 7 + (day - 1)
        let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: startDate) ?? Date()
        
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "yyyy年M月d日"
        return outFormatter.string(from: targetDate)
    }
}

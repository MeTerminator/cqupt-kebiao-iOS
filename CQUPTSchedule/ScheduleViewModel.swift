//
//  ScheduleViewModel.swift
//  CQUPTSchedule
//
//  Created by MeTerminator on 2026/2/25.
//

import Foundation
import Combine
import SwiftUI

class ScheduleViewModel: ObservableObject {
    @Published var scheduleData: ScheduleResponse?
    @Published var isLoading = false
    @Published var selectedWeek: Int = 1 { didSet { updateCurrentWeekStatus() } }
    @Published var isCurrentWeekReal: Bool = false
    
    // 刷新结果提示
    @Published var toastMessage: String = ""
    @Published var showToast: Bool = false
    
    // 课程颜色映射表 [课程名: 颜色索引]
    @Published var courseColorMap: [String: Int] = [:]
    
    private var firstMondayDate: Date?
    private var refreshTimer: AnyCancellable?
    private var currentId: String = ""
    
    // 缓存路径
    private var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("schedule_cache.json")
    }

    init() {
        // 10分钟自动定时器
        refreshTimer = Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshData(silent: true) }
    }
    
    private func triggerToast(msg: String) {
        self.toastMessage = msg
        withAnimation(.spring()) { self.showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showToast = false }
        }
    }

    // 分析所有课程并生成颜色映射表
    func generateColorMap() {
        var newMap: [String: Int] = [:]
        
        // 1. 获取所有课程实例，如果没有数据则直接返回
        guard let instances = scheduleData?.instances else { return }
        
        // 2. 提取所有非考试课程的名称，并进行去重
        let nonExamCourseNames = Set(instances.filter { !$0.type.contains("考试") }.map { $0.course })
        
        // 3. 对课程名称进行排序 (字母/汉字顺序)
        // 排序确保了每次刷新时，课程 A 永远分配到相同的 index，颜色从而固定
        let sortedNames = nonExamCourseNames.sorted()
        
        // 4. 按顺序分配索引
        for (index, name) in sortedNames.enumerated() {
            newMap[name] = index
        }
        
        // 5. 更新到 ViewModel 的属性中（建议在主线程更新 UI 相关数据）
        DispatchQueue.main.async {
            self.courseColorMap = newMap
        }
    }

    // 启动流：读缓存 -> 自动静默同步网络
    func startup(studentId: String) {
        self.currentId = studentId
        loadFromCache(isInitial: true)
        refreshData(silent: true)
    }

    func refreshData(silent: Bool = false) {
        guard !currentId.isEmpty else { return }
        guard let url = URL(string: "https://cqupt.ishub.top/api/curriculum/\(currentId)/curriculum.json") else { return }
        
        if !silent { self.isLoading = true }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let data = data, let decoded = try? JSONDecoder().decode(ScheduleResponse.self, from: data) {
                    self?.scheduleData = decoded
                    self?.saveToCache(data: data)
                    
                    self?.generateColorMap() // 更新课程颜色映射
                    self?.parseStartDate(autoJump: false)
                    
                    if !silent { self?.triggerToast(msg: "课表已同步") }
                } else if !silent {
                    self?.triggerToast(msg: "刷新失败: \(error?.localizedDescription ?? "解析错误")")
                }
            }
        }.resume()
    }

    private func saveToCache(data: Data) { try? data.write(to: cacheURL) }

    private func loadFromCache(isInitial: Bool) {
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode(ScheduleResponse.self, from: data) {
            self.scheduleData = decoded
            self.generateColorMap() // 从缓存读取后也要生成颜色映射
            self.parseStartDate(autoJump: isInitial)
        }
    }

    func clearCache() { try? FileManager.default.removeItem(at: cacheURL) }

    private func parseStartDate(autoJump: Bool = false) {
        guard let data = scheduleData else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var date = formatter.date(from: data.week1Monday)
        if date == nil {
            let alt = DateFormatter()
            alt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            date = alt.date(from: data.week1Monday)
        }
        
        if let finalDate = date {
            // 关键：将时间统一到周一的凌晨 00:00:00，避免时差干扰
            self.firstMondayDate = Calendar.current.startOfDay(for: finalDate)
            
            if autoJump {
                let currentRealWeek = calculateCurrentRealWeek()
                // 如果还没开学 (realWeek < 1)，默认停留在第 0 周查看，但状态会显示“非本周/未开学”
                self.selectedWeek = max(0, min(currentRealWeek, 20))
            }
            updateCurrentWeekStatus()
        }
    }

    /// 提取出来的纯净周数计算函数
    func calculateCurrentRealWeek() -> Int {
        guard let startDate = firstMondayDate else { return 1 }
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        
        let components = calendar.dateComponents([.day], from: startDate, to: now)
        let days = components.day ?? 0
        
        // 如果在开学前 1-7 天，返回 0
        if days < 0 && days >= -7 {
            return 0
        } else if days < -7 {
            return -1 // 更早的时间显示为未开学
        }
        
        return (days / 7) + 1
    }

    func updateCurrentWeekStatus() {
        let realWeek = calculateCurrentRealWeek()
        
        // 定义“应当显示的周”：
        let expectedWeek: Int
        if realWeek <= 0 {
            // 如果是准备期，检查第 0 周是否有课
            let hasCourseInWeek0 = scheduleData?.instances.contains { $0.week == 0 } ?? false
            expectedWeek = hasCourseInWeek0 ? 0 : 1
        } else {
            expectedWeek = min(realWeek, 20)
        }
        
        // 核心逻辑：只要当前选中的周等于我们认为“现在该看”的那一周，就标记为 Real
        DispatchQueue.main.async {
            self.isCurrentWeekReal = (self.selectedWeek == expectedWeek)
        }
    }
    
    func exportToCalendar(firstAlert: Int?, secondAlert: Int?, calendarName: String) {
        guard !currentId.isEmpty else { return }

        // 调用之前写的权限检查逻辑
        CalendarManager.shared.requestAccess { granted in
            if granted {
                self.isLoading = true
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try CalendarManager.shared.syncCourses(
                            instances: self.scheduleData?.instances ?? [],
                            startDateStr: self.scheduleData?.week1Monday ?? "",
                            firstAlert: firstAlert,
                            secondAlert: secondAlert,
                            calendarName: calendarName // 传递给 Manager
                        )
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.triggerToast(msg: "同步至“\(calendarName)”成功")
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.triggerToast(msg: "同步失败")
                        }
                    }
                }
            } else {
                self.triggerToast(msg: "需要日历权限")
            }
        }
    }

    private func saveAndOpenICS(data: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cqupt_schedule.ics")
        do {
            try data.write(to: tempURL)
            
            // 获取当前的 RootViewController 来弹出预览
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                let interactionController = UIDocumentInteractionController(url: tempURL)
                interactionController.delegate = rootVC as? UIDocumentInteractionControllerDelegate
                // 必须在主线程打开
                if !interactionController.presentOpenInMenu(from: .zero, in: rootVC.view, animated: true) {
                    self.triggerToast(msg: "未发现支持日历导入的应用")
                }
            }
        } catch {
            self.triggerToast(msg: "文件保存失败")
        }
    }
}

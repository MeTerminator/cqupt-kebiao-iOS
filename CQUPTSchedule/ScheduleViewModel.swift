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
    private func generateColorMap() {
        guard let instances = scheduleData?.instances else { return }
        // 获取所有不重复的课程名称并排序，确保颜色分配逻辑稳定
        let uniqueCourseNames = Array(Set(instances.map { $0.course })).sorted()
        
        var newMap: [String: Int] = [:]
        for (index, name) in uniqueCourseNames.enumerated() {
            newMap[name] = index
        }
        self.courseColorMap = newMap
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
                // 如果还没开学 (realWeek < 1)，默认停留在第 1 周查看，但状态会显示“非本周/未开学”
                self.selectedWeek = max(1, min(currentRealWeek, 20))
            }
            updateCurrentWeekStatus()
        }
    }

    /// 提取出来的纯净周数计算函数
    func calculateCurrentRealWeek() -> Int {
        guard let startDate = firstMondayDate else { return 1 }
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        
        // 计算从第一周周一到今天的天数
        let components = calendar.dateComponents([.day], from: startDate, to: now)
        let days = components.day ?? 0
        
        // 核心修复：days 为负数时代表未开学
        if days < 0 {
            return -1 // 使用 -1 代表“未开学”状态
        }
        return (days / 7) + 1
    }

    func updateCurrentWeekStatus() {
        let realWeek = calculateCurrentRealWeek()
        
        // 只有当“当前选择的周”等于“现实中的周”，且“现实中已经开学”时，才标记为本周
        if realWeek >= 1 && self.selectedWeek == realWeek {
            self.isCurrentWeekReal = true
        } else {
            self.isCurrentWeekReal = false
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

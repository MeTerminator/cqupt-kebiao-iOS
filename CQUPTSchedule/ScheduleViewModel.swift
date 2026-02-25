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
            self.firstMondayDate = finalDate
            let days = Calendar.current.dateComponents([.day], from: finalDate, to: Date()).day ?? 0
            let realWeek = (days / 7) + 1

            if autoJump {
                self.selectedWeek = max(1, min(realWeek, 20))
            }
            updateCurrentWeekStatus()
        }
    }

    func updateCurrentWeekStatus() {
        guard let startDate = firstMondayDate else { return }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        self.isCurrentWeekReal = (self.selectedWeek == (days / 7) + 1)
    }
}

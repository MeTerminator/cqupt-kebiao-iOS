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
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    
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

    // 启动流：读缓存 -> 自动静默同步网络
    func startup(studentId: String) {
        self.currentId = studentId
        loadFromCache()
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
                    self?.parseStartDate()
                    if !silent {
                        self?.alertMessage = "课表同步成功"
                        self?.showAlert = true
                    }
                } else if !silent {
                    self?.alertMessage = "刷新失败: \(error?.localizedDescription ?? "解析错误")"
                    self?.showAlert = true
                }
            }
        }.resume()
    }

    private func saveToCache(data: Data) { try? data.write(to: cacheURL) }

    private func loadFromCache() {
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode(ScheduleResponse.self, from: data) {
            self.scheduleData = decoded
            self.parseStartDate()
        }
    }

    func clearCache() { try? FileManager.default.removeItem(at: cacheURL) }

    private func parseStartDate() {
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
            let week = (days / 7) + 1
            self.selectedWeek = max(1, min(week, 20))
        }
    }

    func updateCurrentWeekStatus() {
        guard let startDate = firstMondayDate else { return }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        self.isCurrentWeekReal = (self.selectedWeek == (days / 7) + 1)
    }
}

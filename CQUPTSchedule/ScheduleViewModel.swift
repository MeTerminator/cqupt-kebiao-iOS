import Foundation
import Combine
import SwiftUI

class ScheduleViewModel: ObservableObject {
    @Published var scheduleData: ScheduleResponse?
    @Published var isLoading = false
    @Published var selectedWeek: Int = 1
    
    // 状态提示
    @Published var toastMessage: String = ""
    @Published var showToast: Bool = false
    @Published var courseColorMap: [String: Int] = [:]
    
    private var firstMondayDate: Date?
    private var refreshTimer: AnyCancellable?
    private var currentId: String = ""
    
    // 缓存路径
    private var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("schedule_cache.json")
    }

    // MARK: - 计算属性 (响应式 UI)
    
    /// 判断当前选中的周是否是现实中的那一周
    var isCurrentWeekReal: Bool {
        let real = calculateCurrentRealWeek()
        // 处理开学前的边界：如果还没开学，通常第1周就是他们的“本周”
        let expected = real <= 0 ? 1 : min(real, 20)
        return selectedWeek == expected
    }

    /// 获取今天是周几 (1:周一, 7:周日)
    var currentDayOfWeek: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // 系统 1 是周日，这里转换为 1 是周一
        return weekday == 1 ? 7 : weekday - 1
    }

    /// 判断指定的周和天是否是今天 (用于 Grid 高亮)
    func isToday(week: Int, day: Int) -> Bool {
        return week == calculateCurrentRealWeek() && day == currentDayOfWeek
    }

    // MARK: - 初始化与同步

    init() {
        refreshTimer = Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshData(silent: true) }
    }
    
    func startup(studentId: String) {
        self.currentId = studentId
        loadFromCache(isInitial: true)
        refreshData(silent: true)
    }

    func generateColorMap() {
        guard let instances = scheduleData?.instances else { return }
        let names = Set(instances.filter { !$0.type.contains("考试") }.map { $0.course }).sorted()
        var newMap: [String: Int] = [:]
        for (index, name) in names.enumerated() { newMap[name] = index }
        DispatchQueue.main.async { self.courseColorMap = newMap }
    }

    func refreshData(silent: Bool = false) {
        guard !currentId.isEmpty, let url = URL(string: "https://cqupt.ishub.top/api/curriculum/\(currentId)/curriculum.json") else { return }
        if !silent { self.isLoading = true }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let data = data, let decoded = try? JSONDecoder().decode(ScheduleResponse.self, from: data) {
                    self?.scheduleData = decoded
                    try? data.write(to: self!.cacheURL)
                    self?.generateColorMap()
                    self?.parseStartDate(autoJump: false)
                    if !silent { self?.triggerToast(msg: "课表已同步") }
                }
            }
        }.resume()
    }

    private func loadFromCache(isInitial: Bool) {
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode(ScheduleResponse.self, from: data) {
            self.scheduleData = decoded
            self.generateColorMap()
            self.parseStartDate(autoJump: isInitial)
        }
    }

    // MARK: - 时间逻辑核心

    private func parseStartDate(autoJump: Bool = false) {
        guard let data = scheduleData else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let date = formatter.date(from: data.week1Monday) ?? {
            let alt = DateFormatter()
            alt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            return alt.date(from: data.week1Monday)
        }()
        
        if let finalDate = date {
            // 归一化到周一凌晨
            self.firstMondayDate = Calendar.current.startOfDay(for: finalDate)
            if autoJump {
                let real = calculateCurrentRealWeek()
                // 自动跳转，最小第1周，最大20周
                self.selectedWeek = max(0, min(real, 20))
            }
        }
    }

    /// 精准周数计算：使用 weekOfYear 差值，完美处理周日跨周
    func calculateCurrentRealWeek() -> Int {
        guard let startDate = firstMondayDate else { return 1 }
        let calendar = Calendar.current
        
        let fromDate = calendar.startOfDay(for: startDate) // 第一周周一 00:00
        let now = calendar.startOfDay(for: Date())         // 今天 00:00
        
        // 计算今天距离第一周周一差了多少天
        let components = calendar.dateComponents([.day], from: fromDate, to: now)
        let daysDiff = components.day ?? 0
        
        if daysDiff < 0 {
            // 如果在周一之前：
            // -1 到 -7 天（即开学前那个周一到周日）属于第 0 周
            if daysDiff >= -7 {
                return 0
            } else {
                return -1 // 更早的时间
            }
        }
        
        // 开学后的计算：0-6天算第1周，7-13天算第2周...
        return (daysDiff / 7) + 1
    }

    private func triggerToast(msg: String) {
        self.toastMessage = msg
        withAnimation(.spring()) { self.showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showToast = false }
        }
    }

    // MARK: - 外部工具
    
    func exportToCalendar(firstAlert: Int?, secondAlert: Int?, calendarName: String) {
        CalendarManager.shared.requestAccess { granted in
            if granted {
                self.isLoading = true
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try CalendarManager.shared.syncCourses(
                            instances: self.scheduleData?.instances ?? [],
                            startDateStr: self.scheduleData?.week1Monday ?? "",
                            firstAlert: firstAlert, secondAlert: secondAlert,
                            calendarName: calendarName
                        )
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.triggerToast(msg: "同步至“\(calendarName)”成功")
                        }
                    } catch {
                        DispatchQueue.main.async { self.isLoading = false; self.triggerToast(msg: "同步失败") }
                    }
                }
            } else {
                self.triggerToast(msg: "需要日历权限")
            }
        }
    }
}

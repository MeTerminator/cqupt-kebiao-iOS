import SwiftUI


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

                            let courses = viewModel.allCourses(for: weekToShow)
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

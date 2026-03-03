import SwiftUI


struct HeaderView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var showUser: Bool
    
    @State private var showAddCustomSheet = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatToSchedule())
                    .font(.system(size: 22, weight: .bold))
                
                HStack(spacing: 6) {
                    Text("第\(viewModel.selectedWeek)周")
                        .fontWeight(.semibold)
                    
                    let realWeek = viewModel.calculateCurrentRealWeek()
                    // 标记当前周状态
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
            
            HStack(spacing: 16) {
                // 如果不是本周，显示快捷返回按钮
                if !viewModel.isCurrentWeekReal {
                    Button(action: {
                        let realWeek = viewModel.calculateCurrentRealWeek()
                        let target = max(0, min(realWeek, 20))
                        withAnimation(.easeInOut(duration: 0.6)) {
                            viewModel.selectedWeek = target
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Button(action: {  showAddCustomSheet = true }) {
                     Image(systemName: "plus.circle.fill") // 换个显眼的图标
                         .font(.system(size: 24))
                         .foregroundColor(.accentColor)
                 }
                 .sheet(isPresented: $showAddCustomSheet) {
                     AddCustomCourseView(viewModel: viewModel)
                 }
                
                Button(action: { viewModel.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 24))
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                }
                
                Button(action: { showUser = true }) {
                    Image(systemName: "person.circle").font(.system(size: 24))
                }
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
}

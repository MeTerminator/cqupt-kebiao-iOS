import SwiftUI


struct CalendarExportView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.presentationMode) var pm
    
    @State private var calendarName = "重邮课表"
    @State private var enableAlarm = true
    @State private var firstAlert: Int = 30
    @State private var secondAlert: Int = 10
    
    let options = [5, 10, 15, 30, 45, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("日历设置"), footer: Text("注意：同步将彻底清空系统日历中名为“\(calendarName)”的所有现有事件。").foregroundColor(.red)) {
                    HStack {
                        Text("日历名称")
                        TextField("请输入日历名称", text: $calendarName)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("提醒设置")) {
                    Toggle("开启上课提醒", isOn: $enableAlarm)
                    
                    if enableAlarm {
                        // 第一次提醒选择器
                        Picker("第一次提醒", selection: $firstAlert) {
                            ForEach(options, id: \.self) { min in
                                Text("前 \(min) 分钟").tag(min)
                            }
                        }
                        // 适配 iOS 17 的新语法：onChange(of: newValue)
                        .onChange(of: firstAlert) { oldValue, newValue in
                            if secondAlert >= newValue {
                                secondAlert = 0
                            }
                        }
                        
                        // 第二次提醒选择器
                        Picker("第二次提醒", selection: $secondAlert) {
                            Text("不设置").tag(0)
                            ForEach(options.filter { $0 < firstAlert }, id: \.self) { min in
                                Text("前 \(min) 分钟").tag(min)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        let first = enableAlarm ? firstAlert : nil
                        let second = (enableAlarm && secondAlert > 0) ? secondAlert : nil
                        let finalName = calendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "重邮课表" : calendarName
                        
                        viewModel.exportToCalendar(
                            firstAlert: first,
                            secondAlert: second,
                            calendarName: finalName
                        )
                        pm.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView().padding(.trailing, 8)
                            }
                            Text("清空并覆盖同步").bold()
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .foregroundColor(.white)
                    .listRowBackground(viewModel.isLoading ? Color.gray : Color.blue)
                }
            }
            .navigationTitle("日历同步")
//            .navigationBarItems(leading: Button("取消") { pm.wrappedValue.dismiss() })
        }
    }
}

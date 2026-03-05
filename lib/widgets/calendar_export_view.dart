import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../view_models/schedule_view_model.dart';
import '../services/calendar_service.dart'; // 导入 Service
import '../models/schedule_model.dart';    // 导入 Model

class CalendarExportView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const CalendarExportView({super.key, required this.viewModel});

  @override
  State<CalendarExportView> createState() => _CalendarExportViewState();
}

class _CalendarExportViewState extends State<CalendarExportView> {
  late TextEditingController _calendarNameController;
  final CalendarService _calendarService = CalendarService(); // 实例化 Service
  
  bool _isLoading = false; // 本地 loading 状态
  bool _enableAlarm = true;
  int _firstAlert = 30;
  int _secondAlert = 10;

  final List<int> _options = [5, 10, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _calendarNameController = TextEditingController(text: '重邮课表');
    _calendarNameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _calendarNameController.dispose();
    super.dispose();
  }

  /// 核心导出逻辑
  Future<void> _handleExport() async {
    final name = _calendarNameController.text.trim().isEmpty 
        ? '重邮课表' 
        : _calendarNameController.text.trim();

    // 1. 震动反馈
    HapticFeedback.mediumImpact();

    // 2. 获取数据准备
    final week1Monday = widget.viewModel.scheduleData?.week1Monday ?? '';
    if (week1Monday.isEmpty) {
      widget.viewModel.triggerToast('错误：未找到学期开学日期');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. 汇总 0-20 周所有课程实例（包含自定义课程）
      final allInstances = <CourseInstance>[];
      for (int w = 0; w <= 20; w++) {
        allInstances.addAll(widget.viewModel.allCourses(w));
      }

      if (allInstances.isEmpty) {
        throw '当前没有可同步的课程数据';
      }

      // 4. 调用 Service 执行同步
      final success = await _calendarService.syncCourses(
        instances: allInstances,
        startDateStr: week1Monday,
        calendarName: name,
        firstAlertMinutes: _enableAlarm ? _firstAlert : null,
        secondAlertMinutes: (_enableAlarm && _secondAlert > 0) ? _secondAlert : null,
      );

      if (mounted) {
        if (success) {
          widget.viewModel.triggerToast('已导出到日历 "$name"');
          Navigator.pop(context); // 成功后关闭
        } else {
          widget.viewModel.triggerToast('同步失败：请检查系统日历权限设置');
        }
      }
    } catch (e) {
      if (mounted) widget.viewModel.triggerToast('同步异常: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text('取消', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ),
                  const Text('导出至系统日历', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 60), 
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 20),
                child: Column(
                  children: [
                    _buildCard(
                      child: _buildListTile(
                        label: '日历名称',
                        trailing: Expanded(
                          child: TextField(
                            controller: _calendarNameController,
                            textAlign: TextAlign.right,
                            enabled: !_isLoading,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '请输入名称',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildHintText('同步将清空日历 "${_calendarNameController.text}" 下的所有旧课程'),
                    
                    const SizedBox(height: 24),

                    _buildCard(
                      child: Column(
                        children: [
                          _buildListTile(
                            label: '开启上课提醒',
                            trailing: Switch.adaptive(
                              value: _enableAlarm,
                              activeColor: Colors.blueAccent,
                              onChanged: _isLoading ? null : (v) => setState(() => _enableAlarm = v),
                            ),
                          ),
                          if (_enableAlarm) ...[
                            const Divider(height: 1, indent: 16),
                            _buildAlertSelector('第一次提醒', _firstAlert, _options, (v) {
                              setState(() {
                                _firstAlert = v;
                                if (_secondAlert >= v) _secondAlert = 0;
                              });
                            }),
                            const Divider(height: 1, indent: 16),
                            _buildAlertSelector(
                              '第二次提醒', 
                              _secondAlert, 
                              [0, ..._options.where((e) => e < _firstAlert)], 
                              (v) => setState(() => _secondAlert = v),
                              isSecond: true,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: _isLoading 
                            ? [Colors.grey, Colors.grey] 
                            : [const Color(0xFF2196F3), const Color(0xFF007AFF)],
                        ),
                        boxShadow: _isLoading ? [] : [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleExport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('立即同步', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 构建 Helper 方法 ---

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _buildListTile({required String label, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _buildAlertSelector(String label, int current, List<int> options, Function(int) onSelect, {bool isSecond = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((m) {
                final isSelected = current == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m == 0 ? '不提醒' : '$m分钟'),
                    selected: isSelected,
                    onSelected: _isLoading ? null : (_) => onSelect(m),
                    selectedColor: Colors.blueAccent.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blueAccent : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[100],
                    side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.transparent),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.orange[400]),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.orange[600]))),
        ],
      ),
    );
  }
}
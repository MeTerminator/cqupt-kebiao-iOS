import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../utils/extensions.dart';
import '../services/calendar_service.dart';
import 'add_custom_course_view.dart';

class UserDetailView extends StatefulWidget {
  final ScheduleViewModel viewModel;
  final VoidCallback onLogout;

  const UserDetailView({
    super.key,
    required this.viewModel,
    required this.onLogout,
  });

  @override
  State<UserDetailView> createState() => _UserDetailViewViewState();
}

class _UserDetailViewViewState extends State<UserDetailView> {
  final CalendarService _calendarService = CalendarService();
  final TextEditingController _calendarNameController = TextEditingController(
    text: '重邮课表',
  );
  bool _isSyncing = false;

  // 提醒时间选项定义
  final List<Map<String, dynamic>> _alertOptions = [
    {'label': '无', 'value': 0},
    {'label': '5分钟', 'value': 5},
    {'label': '10分钟', 'value': 10},
    {'label': '15分钟', 'value': 15},
    {'label': '30分钟', 'value': 30},
    {'label': '1小时', 'value': 60},
    {'label': '2小时', 'value': 120},
  ];

  String getChineseDay(int day) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return (day >= 1 && day <= 7) ? days[day - 1] : '';
  }

  String _formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = weeks.toList()..sort();
    final ranges = <String>[];
    int start = sorted.first;
    int end = start;

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add(start == end ? '$start' : '$start-$end');
        start = sorted[i];
        end = start;
      }
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    return '第${ranges.join(',')}周';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '用户详情',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(context, '个人信息', [
                        _buildRow(
                          context,
                          '姓名',
                          widget.viewModel.scheduleData?.studentName ?? '',
                        ),
                        _buildRow(
                          context,
                          '学号',
                          widget.viewModel.scheduleData?.studentId ?? '',
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, '学期信息', [
                        _buildRow(
                          context,
                          '学年',
                          widget.viewModel.scheduleData?.academicYear ?? '',
                        ),
                        _buildRow(
                          context,
                          '学期',
                          '第 ${widget.viewModel.scheduleData?.semester ?? ""} 学期',
                        ),
                        _buildRow(
                          context,
                          '开学日期',
                          widget.viewModel.scheduleData?.week1Monday.substring(
                                0,
                                10,
                              ) ??
                              '',
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, '自定义行程管理', [
                        if (widget.viewModel.customCourses.isEmpty)
                          const SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '暂无自定义行程',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else ...[
                          ...widget.viewModel.customCourses.asMap().entries.map(
                            (entry) => _buildCustomCourseRow(
                              context,
                              entry.value,
                              entry.key,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () {
                                  widget.viewModel.clearAllCustomCourses();
                                  setState(() {});
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('清空所有自定义行程'),
                              ),
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, '系统同步', [
                        _buildSyncCalendarRow(context),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onLogout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('退出登录'),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCalendarSyncDialog(BuildContext context) {
    int firstAlert = 30;
    int secondAlert = 10;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导入到系统日历'),
          content: SingleChildScrollView(
            // 防止输入法弹出时溢出
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '日历名称：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _calendarNameController,
                  decoration: InputDecoration(
                    hintText: '请输入日历名称',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '第一次提醒：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _alertOptions.map((opt) {
                    return ChoiceChip(
                      label: Text(
                        opt['label'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: firstAlert == opt['value'],
                      onSelected: (selected) {
                        if (selected)
                          setDialogState(() => firstAlert = opt['value']);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '第二次提醒：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _alertOptions.map((opt) {
                    return ChoiceChip(
                      label: Text(
                        opt['label'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: secondAlert == opt['value'],
                      onSelected: (selected) {
                        if (selected)
                          setDialogState(() => secondAlert = opt['value']);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  '注意：导入将清空该名称日历下的旧日程。',
                  style: TextStyle(fontSize: 14, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _calendarNameController.text.trim();
                Navigator.pop(context);
                // 将自定义名称传给同步函数
                _syncToCalendar(context, firstAlert, secondAlert, name);
              },
              child: const Text('立即导入'),
            ),
          ],
        ),
      ),
    );
  }

  // 修改 _syncToCalendar 签名，接收 name
  Future<void> _syncToCalendar(
    BuildContext context,
    int firstAlert,
    int secondAlert,
    String name,
  ) async {
    setState(() => _isSyncing = true);

    try {
      final week1Monday = widget.viewModel.scheduleData?.week1Monday ?? '';
      if (week1Monday.isEmpty) throw '无法获取开学日期';

      final allInstances = <CourseInstance>[];
      for (int w = 1; w <= 20; w++) {
        allInstances.addAll(widget.viewModel.allCourses(w));
      }

      final success = await _calendarService.syncCourses(
        instances: allInstances,
        startDateStr: week1Monday,
        calendarName: name.isEmpty ? 'CQUPT课表' : name, // 传递自定义名称
        firstAlertMinutes: firstAlert == 0 ? null : firstAlert,
        secondAlertMinutes: secondAlert == 0 ? null : secondAlert,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '同步至 "$name" 成功！' : '同步失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- UI 构建方法 (保持原样) ---

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCustomCourseRow(
    BuildContext context,
    CustomCourse item,
    int index,
  ) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        widget.viewModel.deleteCustomCourseById(item.id);
        setState(() {});
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddCustomCourseView(
              viewModel: widget.viewModel,
              editingCourse: item,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ColorExtensions.dynamicCourseColor(
                    index: item.colorIndex,
                    total: 10,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatWeeks(item.weeks)} 周${getChineseDay(item.day)} ${item.startPeriod}-${item.endPeriod}节',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCalendarRow(BuildContext context) {
    return InkWell(
      onTap: _isSyncing ? null : () => _showCalendarSyncDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 20, color: Colors.blueAccent),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '同步课表到系统日历',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (_isSyncing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../utils/extensions.dart';
import '../services/calendar_service.dart';
import 'add_custom_course_view.dart';
import 'calendar_export_view.dart';

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
  bool _isSyncing = false;

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
                // 顶部指示条
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
                      
                      // 1. 个人信息
                      _buildSection(context, '个人信息', [
                        _buildRow(context, '姓名', widget.viewModel.scheduleData?.studentName ?? ''),
                        _buildRow(context, '学号', widget.viewModel.scheduleData?.studentId ?? ''),
                      ]),
                      const SizedBox(height: 16),

                      // 2. 学期信息
                      _buildSection(context, '学期信息', [
                        _buildRow(context, '学年', widget.viewModel.scheduleData?.academicYear ?? ''),
                        _buildRow(context, '学期', '第 ${widget.viewModel.scheduleData?.semester ?? ""} 学期'),
                        _buildRow(context, '开学日期', widget.viewModel.scheduleData?.week1Monday.substring(0, 10) ?? ''),
                      ]),
                      const SizedBox(height: 16),

                      // 3. 自定义行程管理
                      _buildSection(context, '自定义行程管理', [
                        if (widget.viewModel.customCourses.isEmpty)
                          const SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('暂无自定义行程', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                            ),
                          )
                        else ...[
                          ...widget.viewModel.customCourses.asMap().entries.map((entry) => _buildCustomCourseRow(context, entry.value, entry.key)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () {
                                  widget.viewModel.clearAllCustomCourses();
                                  setState(() {});
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('清空所有自定义行程'),
                              ),
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 16),

                      // 4. 系统同步 (点击触发美化后的导出 View)
                      _buildSection(context, '系统同步', [
                        _buildSyncCalendarRow(context),
                      ]),
                      const SizedBox(height: 16),

                      // 5. 退出登录
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// 唤起美化后的同步底部弹窗
  void _showCalendarSyncSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CalendarExportView(
        viewModel: widget.viewModel,
        // 这里可以直接在 CalendarExportView 内部点击“立即同步”时回调回来，
        // 或者直接在 CalendarExportView 中处理逻辑。
        // 为了保持逻辑内聚，我们将同步逻辑直接写在 CalendarExportView 的 handle 中。
      ),
    );
  }

  // --- UI 构建辅助方法 ---

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100],
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

  Widget _buildCustomCourseRow(BuildContext context, CustomCourse item, int index) {
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
          Navigator.pop(context); // 关闭详情页
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
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: ColorExtensions.dynamicCourseColor(index: item.colorIndex, total: 10),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
      onTap: () => _showCalendarSyncSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 20, color: Colors.blueAccent),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('导出到系统日历', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../utils/extensions.dart';
import 'add_custom_course_view.dart';

class CustomCourseListView extends StatefulWidget {
  final ScheduleViewModel viewModel;
  const CustomCourseListView({super.key, required this.viewModel});

  @override
  State<CustomCourseListView> createState() => _CustomCourseListViewState();
}

class _CustomCourseListViewState extends State<CustomCourseListView> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('自定义行程管理')),
      body: Column(
        children: [
          Expanded(
            child: widget.viewModel.customCourses.isEmpty
                ? const Center(child: Text('暂无自定义行程'))
                : ListView.builder(
                    itemCount: widget.viewModel.customCourses.length,
                    itemBuilder: (context, index) {
                      final item = widget.viewModel.customCourses[index];
                      return _buildCustomCourseRow(context, item, index);
                    },
                  ),
          ),
          if (widget.viewModel.customCourses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  widget.viewModel.clearAllCustomCourses();
                  setState(() {});
                },
                child: const Text(
                  '清空所有行程',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddCourse(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openAddCourse(CustomCourse? course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCustomCourseView(
        viewModel: widget.viewModel,
        editingCourse: course,
      ),
    ).then((_) => setState(() {})); // 底部弹窗关闭后刷新界面
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
}

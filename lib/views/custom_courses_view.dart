import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../widgets/add_custom_course_view.dart';
import '../utils/course_colors.dart';

class CustomCoursesView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const CustomCoursesView({super.key, required this.viewModel});

  @override
  State<CustomCoursesView> createState() => _CustomCoursesViewState();
}

class _CustomCoursesViewState extends State<CustomCoursesView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义行程'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '自定义行程管理',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FloatingActionButton.small(
                  onPressed: _showAddCourseDialog,
                  backgroundColor: const Color.fromRGBO(0, 122, 89, 1),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: widget.viewModel.customCourses.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: widget.viewModel.customCourses.length,
                      itemBuilder: (context, index) {
                        final course = widget.viewModel.customCourses[index];
                        return _buildCourseCard(course, index);
                      },
                    ),
            ),
            if (widget.viewModel.customCourses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _confirmClearAll,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('清空所有自定义行程'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_note_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '暂无自定义行程',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角添加行程',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CustomCourse course, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showEditCourseDialog(course),
                      icon: const Icon(Icons.edit),
                      iconSize: 20,
                    ),
                    IconButton(
                      onPressed: () => _confirmDeleteCourse(index),
                      icon: const Icon(Icons.delete),
                      iconSize: 20,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (course.location.isNotEmpty)
              Text(
                '地点：${course.location}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            if (course.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '备注：${course.description}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    // 优先使用 customColorHex，否则使用 colorIndex
                    color: course.customColorHex != null
                        ? _hexToColor(course.customColorHex!)
                        : CourseColors.dynamicCourseColor(
                            index: course.colorIndex,
                            total: 20,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '星期${_getChineseDay(course.day)} 第${course.startPeriod}-${course.endPeriod}节',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '周次：${_formatWeeks(course.weeks)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /// Hex 颜色字符串转 Color
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // 添加 alpha 通道
    }
    return Color(int.parse(hex, radix: 16));
  }

  void _showAddCourseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCustomCourseView(viewModel: widget.viewModel),
    );
  }

  void _showEditCourseDialog(CustomCourse course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCustomCourseView(
        viewModel: widget.viewModel,
        editingCourse: course,
      ),
    );
  }

  void _confirmDeleteCourse(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除行程'),
        content: const Text('确定要删除这个自定义行程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              widget.viewModel.deleteCustomCourseAt(index);
              Navigator.pop(context);
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有行程'),
        content: const Text('确定要清空所有自定义行程吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await widget.viewModel.clearAllCustomCourses();
              Navigator.pop(context);
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  String _getChineseDay(int day) {
    const days = ['', '一', '二', '三', '四', '五', '六', '日'];
    return days[day];
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
    return ranges.join(',');
  }
}

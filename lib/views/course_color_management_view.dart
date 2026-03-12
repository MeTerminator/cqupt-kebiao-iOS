import 'package:flutter/material.dart';
import '../view_models/schedule_view_model.dart';
import '../utils/course_colors.dart';
import '../widgets/custom_color_picker_sheet.dart';

class CourseColorManagementView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const CourseColorManagementView({super.key, required this.viewModel});

  @override
  State<CourseColorManagementView> createState() =>
      _CourseColorManagementViewState();
}

class _CourseColorManagementViewState extends State<CourseColorManagementView> {
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
        title: const Text('课程颜色管理'),
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
            Text(
              '课程颜色管理',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '为每门课程分配独特的颜色，便于区分',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: widget.viewModel.getAllCourseNames().isEmpty
                  ? _buildEmptyState()
                  : _buildCourseList(),
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
          const Icon(Icons.palette_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text('暂无课程', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            '请先导入课表数据',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    final courseNames = widget.viewModel.getAllCourseNames();

    return ListView.builder(
      itemCount: courseNames.length,
      itemBuilder: (context, index) {
        final courseName = courseNames[index];

        // 优先使用自定义颜色，否则使用颜色索引
        final customColorHex =
            widget.viewModel.courseCustomColorMap[courseName];

        // 先计算 colorIndex，用于后续逻辑
        final colorIndex = widget.viewModel.courseColorMap[courseName] ?? index;

        final Color color;
        if (customColorHex != null) {
          color = CourseColors.hexToColor(customColorHex);
        } else {
          color = CourseColors.dynamicCourseColor(index: colorIndex, total: 20);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    courseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showColorPicker(courseName, colorIndex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.color_lens,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '选择颜色',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
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
      },
    );
  }

  void _showColorPicker(String courseName, int currentIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _ColorPickerSheet(
        viewModel: widget.viewModel,
        courseName: courseName,
        currentIndex: currentIndex,
      ),
    );
  }

  /// Hex 颜色字符串转 Color
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // 添加 alpha 通道
    }
    final color = Color(int.parse(hex, radix: 16));
    return color;
  }
}

class _ColorPickerSheet extends StatefulWidget {
  final ScheduleViewModel viewModel;
  final String courseName;
  final int currentIndex;

  const _ColorPickerSheet({
    required this.viewModel,
    required this.courseName,
    required this.currentIndex,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  int _selectedIndex = 0;
  Color? _customColor;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;

    // 优先使用课程的自定义颜色
    final customColorHex =
        widget.viewModel.courseCustomColorMap[widget.courseName];
    if (customColorHex != null) {
      _customColor = CourseColors.hexToColor(customColorHex);
    } else {
      _customColor = CourseColors.dynamicCourseColor(
        index: widget.currentIndex,
        total: 20,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.courseName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '选择课程颜色',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      '自定义颜色',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        await _pickCustomColor();
                        if (_customColor != null) {
                          setState(() {
                            _selectedIndex = -1;
                          });
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _customColor ?? Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _customColor != null
                                ? const Color.fromRGBO(0, 122, 89, 1)
                                : Colors.grey.shade400,
                            width: _customColor != null ? 3 : 1,
                          ),
                          boxShadow: _customColor != null
                              ? [
                                  BoxShadow(
                                    color: _customColor!.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: _customColor != null
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              )
                            : const Icon(
                                Icons.colorize,
                                color: Colors.grey,
                                size: 24,
                              ),
                      ),
                    ),
                    if (_customColor != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _customColor!.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${_customColor!.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _customColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_customColor != null) {
                        // 保存自定义颜色的 Hex 值
                        final customColorHex =
                            '#${_customColor!.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';
                        widget.viewModel.updateCourseCustomColor(
                          widget.courseName,
                          customColorHex,
                        );
                      } else {
                        widget.viewModel.updateCourseColor(
                          widget.courseName,
                          _selectedIndex,
                        );
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('颜色已更新'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(0, 122, 89, 1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCustomColor() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomColorPickerSheet(
        initialColor: _customColor,
        onColorSelected: (color) {
          setState(() {
            _customColor = color;
            _selectedIndex = -1;
          });
        },
      ),
    );
  }
}

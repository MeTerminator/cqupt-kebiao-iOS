import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../utils/course_colors.dart';
import 'custom_color_picker_sheet.dart';

class AddCustomCourseView extends StatefulWidget {
  final ScheduleViewModel viewModel;
  final CustomCourse? editingCourse;

  const AddCustomCourseView({
    super.key,
    required this.viewModel,
    this.editingCourse,
  });

  @override
  State<AddCustomCourseView> createState() => _AddCustomCourseViewState();
}

class _AddCustomCourseViewState extends State<AddCustomCourseView> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  Set<int> _selectedWeeks = {};
  int _selectedDay = 1;
  int _startPeriod = 1;
  int _endPeriod = 2;
  Color? _customColor;

  bool get isEditing => widget.editingCourse != null;

  @override
  void initState() {
    super.initState();
    if (widget.editingCourse != null) {
      final course = widget.editingCourse!;
      _titleController.text = course.title;
      _locationController.text = course.location;
      _descriptionController.text = course.description;
      _selectedWeeks = course.weeks.toSet();
      _selectedDay = course.day;
      _startPeriod = course.startPeriod;
      _endPeriod = course.endPeriod;

      // 恢复颜色：优先使用自定义颜色 Hex 值
      if (course.customColorHex != null) {
        _customColor = CourseColors.hexToColor(course.customColorHex!);
      } else {
        // 如果没有自定义颜色，使用 colorIndex 生成一个默认颜色
        _customColor = CourseColors.dynamicCourseColor(
          index: course.colorIndex,
          total: 20,
        );
      }
    } else {
      _selectedWeeks = {widget.viewModel.selectedWeek};
      _selectedDay = widget.viewModel.currentDayOfWeek;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String getChineseDay(int day) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return (day >= 1 && day <= 7) ? days[day - 1] : '';
  }

  void _toggleWeek(int week) {
    setState(() {
      if (_selectedWeeks.contains(week)) {
        if (_selectedWeeks.length > 1) {
          _selectedWeeks.remove(week);
        }
      } else {
        _selectedWeeks.add(week);
      }
    });
  }

  void _selectAllWeeks() {
    setState(() {
      _selectedWeeks = Set.from(List.generate(21, (i) => i));
    });
  }

  void _clearWeeks() {
    setState(() {
      _selectedWeeks = {widget.viewModel.selectedWeek};
    });
  }

  void _save() {
    if (_titleController.text.isEmpty || _selectedWeeks.isEmpty) return;
    final sortedWeeks = _selectedWeeks.toList()..sort();

    // 保存自定义颜色的 Hex 值
    String? customColorHex;
    int colorIndex = 0; // 默认使用第一个颜色作为占位

    if (_customColor != null) {
      customColorHex =
          '#${_customColor!.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';
    }

    final course = CustomCourse(
      id:
          widget.editingCourse?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      location: _locationController.text,
      description: _descriptionController.text,
      colorIndex: colorIndex,
      customColorHex: customColorHex,
      weeks: sortedWeeks,
      day: _selectedDay,
      startPeriod: _startPeriod,
      endPeriod: _endPeriod,
    );

    if (isEditing) {
      widget.viewModel.updateCustomCourse(course);
    } else {
      widget.viewModel.addCustomCourse(course);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          // 适配 Safe Area，确保刘海屏不遮挡内容
          child: SafeArea(
            child: Column(
              children: [
                _buildTopHandle(isDark),
                _buildHeader(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection('基本信息', [
                          _buildTextField(
                            '行程标题 (必填)',
                            _titleController,
                            isRequired: true,
                          ),
                          _buildTextField('地点', _locationController),
                          _buildTextField(
                            '备注',
                            _descriptionController,
                            maxLines: 3,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildSection('时间选择', [
                          _buildWeekSelector(isDark),
                          const SizedBox(height: 12),
                          _buildPickerRow(
                            '星期',
                            _selectedDay,
                            List.generate(7, (i) => i + 1),
                            (v) => setState(() => _selectedDay = v),
                            (i) => '星期${getChineseDay(i)}',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPickerRow(
                                  '开始',
                                  _startPeriod,
                                  List.generate(12, (i) => i + 1),
                                  (v) {
                                    setState(() {
                                      _startPeriod = v;
                                      if (_endPeriod < v) _endPeriod = v;
                                    });
                                  },
                                  (i) => '第 $i 节',
                                  showLabel: false,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  '至',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _buildPickerRow(
                                  '结束',
                                  _endPeriod,
                                  List.generate(12, (i) => i + 1),
                                  (v) {
                                    setState(() {
                                      _endPeriod = v;
                                      if (_startPeriod > v) _startPeriod = v;
                                    });
                                  },
                                  (i) => '第 $i 节',
                                  showLabel: false,
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildSection('外观颜色', [
                          const SizedBox(height: 8),
                          _buildColorPicker(isDark),
                          const SizedBox(height: 8),
                        ]),
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

  Widget _buildTopHandle(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          Text(
            isEditing ? '编辑行程' : '添加自定义行程',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: _titleController.text.isEmpty || _selectedWeeks.isEmpty
                ? null
                : _save,
            child: Text(
              isEditing ? '保存' : '添加',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '周数 (已选 ${_selectedWeeks.length} 周)',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _selectAllWeeks,
                  child: Text(
                    '全选',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      // 关键修改：深色模式下全选按钮显示为白色，浅色模式跟随主题绿色
                      color: isDark
                          ? Colors.white
                          : const Color.fromRGBO(0, 122, 89, 1),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _clearWeeks,
                  child: Text(
                    '清空',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 21,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final week = index;
              final isSelected = _selectedWeeks.contains(week);
              return GestureDetector(
                onTap: () => _toggleWeek(week),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 46,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color.fromRGBO(0, 122, 89, 1)
                        : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$week',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[600],
            fontSize: 14,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
        ),
        onChanged: isRequired ? (_) => setState(() {}) : null,
      ),
    );
  }

  Widget _buildPickerRow<T>(
    String label,
    T value,
    List<T> items,
    Function(T) onChanged,
    String Function(T) labelBuilder, {
    bool showLabel = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (showLabel) ...[
            Text(
              label,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const Spacer(),
          ],
          Expanded(
            flex: showLabel ? 2 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  items: items
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            labelBuilder(e),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '自定义颜色',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showCustomColorPicker(isDark),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _customColor ?? Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _customColor != null
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.grey.shade400,
                    width: _customColor != null ? 2 : 1,
                  ),
                ),
                child: _customColor != null
                    ? const Icon(Icons.colorize, color: Colors.white, size: 18)
                    : const Icon(Icons.colorize, color: Colors.grey, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            if (_customColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        ),
      ],
    );
  }

  void _showCustomColorPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomColorPickerSheet(
        initialColor: _customColor,
        onColorSelected: (color) {
          setState(() {
            _customColor = color;
          });
        },
      ),
    );
  }
}

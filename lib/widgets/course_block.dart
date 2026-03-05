import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../utils/extensions.dart';

class CourseBlock extends StatelessWidget {
  final ScheduleViewModel viewModel;
  final CourseInstance course;

  const CourseBlock({
    super.key,
    required this.viewModel,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExam = course.type.contains("考试");
    final isCustom = course.type == "自定义行程";

    final isOngoing = viewModel.isCourseOngoing(course);
    final bool noOngoingAnywhere = !viewModel.hasAnyCourseOngoing();
    final nextUpcoming = viewModel.getNextUpcomingCourseGlobal();

    final bool shouldHighlight = noOngoingAnywhere &&
        nextUpcoming != null &&
        nextUpcoming.id == course.id &&
        nextUpcoming.week == course.week &&
        nextUpcoming.day == course.day;

    // --- 动态颜色判定 ---
    // 1. 背景色逻辑：考试块白天为黑，黑夜为白
    Color backgroundColor;
    if (isExam) {
      backgroundColor = isDark ? Colors.white : Colors.black;
    } else if (isCustom) {
      backgroundColor = ColorExtensions.dynamicCourseColor(index: course.colorIndex ?? 0, total: 10);
    } else {
      final colorIndex = viewModel.courseColorMap[course.course] ?? 0;
      backgroundColor = ColorExtensions.dynamicCourseColor(index: colorIndex, total: 20);
    }

    // 2. 基础文字颜色逻辑：
    // 如果是考试块：文字颜色要和背景反色（白天背景黑->文字白；黑夜背景白->文字黑）
    // 如果是常规块：文字统一白色
    final Color baseTextColor = isExam 
        ? (isDark ? Colors.black : Colors.white) 
        : Colors.white;

    // 3. 标签（红色部分）在考试块背景下的适配：
    // 在深色背景上用浅红，在浅色背景（黑夜考试块）上用深红，保证可读性
    final Color tagColor = (isExam && isDark) ? Colors.redAccent.shade700 : Colors.redAccent;

    if (shouldHighlight) {
      backgroundColor = backgroundColor.withOpacity(0.85);
    }

    // --- 文本处理函数 ---
    InlineSpan getFormattedTitle(String fullTitle) {
      final regExp = RegExp(r'【(.*?)】');
      final match = regExp.firstMatch(fullTitle);

      if (match != null) {
        String tagContent = match.group(1)!; // 只提取括号内的文字
        String rest = fullTitle.replaceFirst(match.group(0)!, '').trim();

        return TextSpan(
          children: [
            TextSpan(
              text: '$tagContent\n',
              style: TextStyle(
                color: tagColor,
                fontWeight: FontWeight.bold, // 极粗
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: rest,
              style: TextStyle(
                color: baseTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        );
      } else {
        return TextSpan(
          text: fullTitle,
          style: TextStyle(
            color: baseTextColor, 
            fontWeight: FontWeight.bold, 
            fontSize: 14
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: isCustom
            ? Border.all(color: isDark ? Colors.white70 : Colors.black54, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            if (isOngoing || shouldHighlight)
              _buildHighlightEffect(isOngoing ? Colors.blue : Colors.yellow),

            Padding(
              padding: const EdgeInsets.all(1.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  if (isOngoing)
                    _buildProgressIndicator(viewModel.getCourseProgress(course))
                  else if (shouldHighlight)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Icon(Icons.access_time_filled, size: 16, color: Colors.white),
                    )
                  else
                    const SizedBox(height: 18),
                  
                  Text.rich(
                    getFormattedTitle(course.course),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.2),
                  ),
                  
                  const SizedBox(height: 4),
                  Text(
                    course.location,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: baseTextColor.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightEffect(Color color) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.8), width: 4),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  color.withOpacity(0.1),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(double progress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 2.5,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}
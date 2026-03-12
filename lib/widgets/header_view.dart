import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../view_models/schedule_view_model.dart';
import '../utils/extensions.dart';
import 'add_custom_course_view.dart';

class HeaderView extends StatelessWidget {
  final ScheduleViewModel viewModel;
  final VoidCallback onUserTap;

  const HeaderView({
    super.key,
    required this.viewModel,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final realWeek = viewModel.calculateCurrentRealWeek();
    String weekStatus;
    Color statusColor;
    Color statusBgColor;
    final headerColor = viewModel.headerTextColor;

    if (realWeek == 0) {
      weekStatus = "开学准备";
      statusColor = Colors.orange;
      statusBgColor = Colors.orange.withOpacity(0.15);
    } else if (realWeek < 0) {
      weekStatus = "未开学";
      statusColor = Colors.grey;
      statusBgColor = Colors.grey.withOpacity(0.15);
    } else if (viewModel.isCurrentWeekReal) {
      weekStatus = "本周";
      statusColor = Colors.green;
      statusBgColor = Colors.green.withOpacity(0.15);
    } else {
      weekStatus = "非当前周";
      statusColor = Colors.grey;
      statusBgColor = Colors.grey.withOpacity(0.15);
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final headerOpacity = viewModel.headerOpacity;
    final hasBlurEffect = viewModel.headerBlurEffect;
    final headerBgColor = viewModel.headerBackgroundColor;
    final headerBgOpacity = viewModel.headerBackgroundOpacity;

    Widget headerContent = Container(
      padding: EdgeInsets.only(
        top: topPadding + 10,
        bottom: 5,
        left: 16,
        right: 16,
      ),
      decoration: headerBgColor != null && headerBgOpacity > 0
          ? BoxDecoration(
              color: headerBgColor.withOpacity(headerBgOpacity),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateTime.now().formatToSchedule(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '第${viewModel.selectedWeek}周',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: headerColor ?? Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      weekStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (!viewModel.isCurrentWeekReal)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    final realWeek = viewModel.calculateCurrentRealWeek();
                    final target = realWeek.clamp(0, 20);
                    // 设置标志位，表示需要使用动画
                    viewModel.shouldAnimateToWeek = true;
                    viewModel.selectedWeek = target;
                    viewModel.notifyListeners();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 24,
                      color: headerColor ?? Colors.orange,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        AddCustomCourseView(viewModel: viewModel),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.add_circle_rounded,
                    size: 24,
                    color: headerColor ?? const Color.fromRGBO(0, 122, 89, 1),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  viewModel.refreshData();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedRotation(
                    turns: viewModel.isLoading ? 1 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 24,
                      color: headerColor,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onUserTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.account_circle_rounded,
                    size: 24,
                    color: headerColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // 应用毛玻璃效果
    if (hasBlurEffect) {
      headerContent = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: headerContent,
        ),
      );
    }

    // 应用透明度
    if (headerOpacity < 1.0) {
      headerContent = Opacity(opacity: headerOpacity, child: headerContent);
    }

    return headerContent;
  }
}

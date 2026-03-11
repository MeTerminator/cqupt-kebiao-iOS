import 'package:cqupt_schedule_app/widgets/custom_course_list_view.dart';
import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../utils/extensions.dart';
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
  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              // 顶部指示条（作为拖动把手）
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '用户详情',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // 内容区域：必须使用传入的 scrollController
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 个人信息
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

                      // 2. 学期信息
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

                      // 3. 自定义行程管理
                      _buildSection(context, '行程管理', [
                        ListTile(
                          leading: const Icon(Icons.list_alt),
                          title: const Text('自定义行程'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomCourseListView(
                                  viewModel: widget.viewModel,
                                ),
                              ),
                            ).then(
                              (_) => setState(() {}),
                            ); // 返回时刷新 UserDetailView
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // 4. 系统同步
                      _buildSection(context, '系统同步', [
                        _buildSyncCalendarRow(context),
                      ]),
                      const SizedBox(height: 24),

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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('退出登录'),
                        ),
                      ),

                      const SizedBox(height: 32),
                      // --- 版权与项目信息 ---
                      _buildFooterInfo(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCalendarSyncSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CalendarExportView(viewModel: widget.viewModel),
    );
  }

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

  Widget _buildSyncCalendarRow(BuildContext context) {
    return InkWell(
      onTap: () => _showCalendarSyncSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month,
              size: 20,
              color: Colors.blueAccent,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '导出到系统日历',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterInfo(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'GitHub: MeTerminator/cqupt-schedule-app',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          Text(
            '反馈QQ群：1051832310',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Text(
            '© 2026 MeTerminator',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

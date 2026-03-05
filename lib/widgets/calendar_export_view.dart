import 'package:flutter/material.dart';
import '../view_models/schedule_view_model.dart';

class CalendarExportView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const CalendarExportView({super.key, required this.viewModel});

  @override
  State<CalendarExportView> createState() => _CalendarExportViewState();
}

class _CalendarExportViewState extends State<CalendarExportView> {
  final _calendarNameController = TextEditingController(text: '重邮课表');
  bool _enableAlarm = true;
  int _firstAlert = 30;
  int _secondAlert = 10;

  final List<int> _options = [5, 10, 15, 30, 45, 60];

  @override
  void dispose() {
    _calendarNameController.dispose();
    super.dispose();
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        const Text(
                          '日历同步',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 60),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      '日历设置',
                      [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Text('日历名称'),
                              const Spacer(),
                              SizedBox(
                                width: 150,
                                child: TextField(
                                  controller: _calendarNameController,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '请输入日历名称',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      footer:
                          '注意：同步将彻底清空系统日历中名为"${_calendarNameController.text}"的所有现有事件。',
                    ),
                    const SizedBox(height: 16),
                    _buildSection('提醒设置', [
                      SwitchListTile(
                        title: const Text('开启上课提醒'),
                        value: _enableAlarm,
                        onChanged: (v) => setState(() => _enableAlarm = v),
                      ),
                      if (_enableAlarm) ...[
                        _buildPickerRow('第一次提醒', _firstAlert, (v) {
                          setState(() {
                            _firstAlert = v;
                            if (_secondAlert >= v) _secondAlert = 0;
                          });
                        }, [5, 10, 15, 30, 45, 60]),
                        _buildPickerRow(
                          '第二次提醒',
                          _secondAlert,
                          (v) => setState(() => _secondAlert = v),
                          [0, ..._options.where((e) => e < _firstAlert)],
                          showNoneOption: true,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.viewModel.isLoading
                            ? null
                            : () {
                                final first = _enableAlarm ? _firstAlert : null;
                                final second =
                                    (_enableAlarm && _secondAlert > 0)
                                    ? _secondAlert
                                    : null;
                                final name =
                                    _calendarNameController.text.trim().isEmpty
                                    ? '重邮课表'
                                    : _calendarNameController.text.trim();

                                widget.viewModel.triggerToast('日历同步功能需要设备权限支持');
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: widget.viewModel.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('清空并覆盖同步'),
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
    );
  }

  Widget _buildSection(String title, List<Widget> children, {String? footer}) {
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
        if (footer != null) ...[
          const SizedBox(height: 8),
          Text(footer, style: TextStyle(fontSize: 12, color: Colors.red[400])),
        ],
      ],
    );
  }

  Widget _buildPickerRow(
    String label,
    int value,
    Function(int) onChanged,
    List<int> items, {
    bool showNoneOption = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                items: items
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          showNoneOption && e == 0 ? '不设置' : '前 $e 分钟',
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
        ],
      ),
    );
  }
}

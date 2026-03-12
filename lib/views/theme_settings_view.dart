import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../view_models/schedule_view_model.dart';
import '../models/theme_model.dart';
import '../widgets/custom_color_picker_sheet.dart';

class ThemeSettingsView extends StatelessWidget {
  const ThemeSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleViewModel>(
      builder: (context, viewModel, child) {
        return _ThemeSettingsContent(viewModel: viewModel);
      },
    );
  }
}

class _ThemeSettingsContent extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const _ThemeSettingsContent({required this.viewModel});

  @override
  State<_ThemeSettingsContent> createState() => _ThemeSettingsContentState();
}

class _ThemeSettingsContentState extends State<_ThemeSettingsContent> {
  final ImagePicker _picker = ImagePicker();

  ThemeSettings get _currentTheme => widget.viewModel.currentTheme;

  // 更新主题并自动保存
  void _updateAndSaveTheme(ThemeSettings newTheme) {
    widget.viewModel.saveThemeSettings(newTheme);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主题设置'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header 设置
            _buildSection(context, '顶部导航栏设置', [
              _buildHeaderBlurEffectSwitch(context),
              const Divider(height: 1),
              _buildHeaderBackgroundOpacitySlider(context),
              const Divider(height: 1),
              _buildHeaderBackgroundColorPicker(context),
            ]),
            const SizedBox(height: 24),

            // 背景设置
            _buildSection(context, '背景设置', [
              _buildBackgroundTypeSelector(context),
              const SizedBox(height: 16),
              if (_currentTheme.backgroundType == BackgroundType.solid)
                _buildSolidColorPicker(context)
              else
                _buildImageSelector(context),
            ]),
            const SizedBox(height: 24),

            // 字体颜色设置
            _buildSection(context, '字体颜色设置', [
              _buildColorPickerRow(
                context,
                '顶部字体颜色',
                _currentTheme.headerTextColorHex,
                (color) => _updateAndSaveTheme(
                  _currentTheme.copyWith(headerTextColorHex: color),
                ),
              ),
              const Divider(height: 1),
              _buildColorPickerRow(
                context,
                '时间轴字体颜色',
                _currentTheme.timelineTextColorHex,
                (color) => _updateAndSaveTheme(
                  _currentTheme.copyWith(timelineTextColorHex: color),
                ),
              ),
              const Divider(height: 1),
              _buildColorPickerRow(
                context,
                '课程块字体颜色',
                _currentTheme.courseBlockTextColorHex,
                (color) => _updateAndSaveTheme(
                  _currentTheme.copyWith(courseBlockTextColorHex: color),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // 课程块描边设置
            _buildSection(context, '课程块描边设置', [
              _buildColorPickerRow(
                context,
                '描边颜色',
                _currentTheme.courseBlockBorderColorHex,
                (color) => _updateAndSaveTheme(
                  _currentTheme.copyWith(courseBlockBorderColorHex: color),
                ),
              ),
              const Divider(height: 1),
              _buildBorderWidthSlider(context),
            ]),
            const SizedBox(height: 24),

            // 课程块不透明度设置
            _buildSection(context, '课程块外观', [_buildOpacitySlider(context)]),
            const SizedBox(height: 32),

            // 重置按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _resetToDefault(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('重置为默认主题', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
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

  Widget _buildBackgroundTypeSelector(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _updateAndSaveTheme(
              _currentTheme.copyWith(backgroundType: BackgroundType.solid),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _currentTheme.backgroundType == BackgroundType.solid
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _currentTheme.backgroundType == BackgroundType.solid
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.color_lens, size: 20),
                  const SizedBox(width: 8),
                  const Text('纯色背景'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _updateAndSaveTheme(
              _currentTheme.copyWith(backgroundType: BackgroundType.image),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _currentTheme.backgroundType == BackgroundType.image
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _currentTheme.backgroundType == BackgroundType.image
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, size: 20),
                  const SizedBox(width: 8),
                  const Text('图片背景'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSolidColorPicker(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CustomColorPickerSheet(
            initialColor: _currentTheme.backgroundColorHex != null
                ? ThemeColorUtils.hexToColor(_currentTheme.backgroundColorHex!)
                : Colors.white,
            onColorSelected: (color) {
              _updateAndSaveTheme(
                _currentTheme.copyWith(
                  backgroundColorHex: ThemeColorUtils.colorToHex(color),
                ),
              );
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _currentTheme.backgroundColorHex != null
                    ? ThemeColorUtils.hexToColor(
                        _currentTheme.backgroundColorHex!,
                      )
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            const Text('选择背景颜色'),
            const Spacer(),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector(BuildContext context) {
    return Column(
      children: [
        if (_currentTheme.backgroundImagePath != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(File(_currentTheme.backgroundImagePath!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    _updateAndSaveTheme(
                      _currentTheme.copyWith(backgroundImagePath: image.path),
                    );
                  }
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('从相册选择'),
              ),
            ),
            if (_currentTheme.backgroundImagePath != null) ...[
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  _updateAndSaveTheme(
                    _currentTheme.copyWith(backgroundImagePath: null),
                  );
                },
                icon: const Icon(Icons.clear),
                color: Colors.red,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildColorPickerRow(
    BuildContext context,
    String label,
    String? colorHex,
    Function(String?) onColorSelected,
  ) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CustomColorPickerSheet(
            initialColor: colorHex != null
                ? ThemeColorUtils.hexToColor(colorHex)
                : Colors.white,
            onColorSelected: (color) {
              onColorSelected(ThemeColorUtils.colorToHex(color));
            },
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(label),
            const Spacer(),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorHex != null
                    ? ThemeColorUtils.hexToColor(colorHex)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey),
              ),
              child: colorHex == null
                  ? const Icon(Icons.close, size: 16, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildBorderWidthSlider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('描边粗细'),
              const Spacer(),
              Text(
                '${_currentTheme.courseBlockBorderWidth.toStringAsFixed(1)}px',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          Slider(
            value: _currentTheme.courseBlockBorderWidth,
            min: 0.0,
            max: 5.0,
            divisions: 10,
            label:
                '${_currentTheme.courseBlockBorderWidth.toStringAsFixed(1)}px',
            onChanged: (value) {
              _updateAndSaveTheme(
                _currentTheme.copyWith(courseBlockBorderWidth: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBlurEffectSwitch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Text('毛玻璃效果'),
          const Spacer(),
          Switch(
            value: _currentTheme.headerBlurEffect,
            onChanged: (value) {
              _updateAndSaveTheme(
                _currentTheme.copyWith(headerBlurEffect: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackgroundOpacitySlider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('导航栏背景不透明度'),
              const Spacer(),
              Text(
                '${(_currentTheme.headerBackgroundOpacity * 100).toInt()}%',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          Slider(
            value: _currentTheme.headerBackgroundOpacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: '${(_currentTheme.headerBackgroundOpacity * 100).toInt()}%',
            onChanged: (value) {
              _updateAndSaveTheme(
                _currentTheme.copyWith(headerBackgroundOpacity: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackgroundColorPicker(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CustomColorPickerSheet(
            initialColor: _currentTheme.headerBackgroundColorHex != null
                ? ThemeColorUtils.hexToColor(
                    _currentTheme.headerBackgroundColorHex!,
                  )
                : Colors.white,
            onColorSelected: (color) {
              _updateAndSaveTheme(
                _currentTheme.copyWith(
                  headerBackgroundColorHex: ThemeColorUtils.colorToHex(color),
                ),
              );
            },
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Text('导航栏背景颜色'),
            const Spacer(),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _currentTheme.headerBackgroundColorHex != null
                    ? ThemeColorUtils.hexToColor(
                        _currentTheme.headerBackgroundColorHex!,
                      )
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey),
              ),
              child: _currentTheme.headerBackgroundColorHex == null
                  ? const Icon(Icons.close, size: 16, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildOpacitySlider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('课程块不透明度'),
              const Spacer(),
              Text(
                '${(_currentTheme.courseBlockOpacity * 100).toInt()}%',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          Slider(
            value: _currentTheme.courseBlockOpacity,
            min: 0.3,
            max: 1.0,
            divisions: 14,
            label: '${(_currentTheme.courseBlockOpacity * 100).toInt()}%',
            onChanged: (value) {
              _updateAndSaveTheme(
                _currentTheme.copyWith(courseBlockOpacity: value),
              );
            },
          ),
        ],
      ),
    );
  }

  void _resetToDefault() {
    _updateAndSaveTheme(ThemeSettings.defaultTheme());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已重置为默认主题')));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../state/app_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  void _showOffsetPicker(BuildContext context) {
    String currentOffset = controller.offsetInput;
    bool isNegative = currentOffset.startsWith('-');
    String timePart = currentOffset.startsWith(RegExp(r'[+-]'))
        ? currentOffset.substring(1)
        : currentOffset;
    List<String> parts = timePart.split(':');
    int h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    int m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    int s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    int signIndex = isNegative ? 1 : 0;
    int hIndex = h;
    int mIndex = m;
    int sIndex = s;

    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '时间偏移',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: '正负号',
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                                initialItem: signIndex),
                            itemExtent: 40.0,
                            onSelectedItemChanged: (int index) =>
                                signIndex = index,
                            children: const [
                              Center(child: Text('+')),
                              Center(child: Text('-')),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: '小时',
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                                initialItem: hIndex),
                            itemExtent: 40.0,
                            onSelectedItemChanged: (int index) => hIndex = index,
                            children: List.generate(
                                24,
                                (index) => Center(
                                    child: Text(index.toString().padLeft(2, '0')))),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: '分钟',
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                                initialItem: mIndex),
                            itemExtent: 40.0,
                            onSelectedItemChanged: (int index) => mIndex = index,
                            children: List.generate(
                                60,
                                (index) => Center(
                                    child: Text(index.toString().padLeft(2, '0')))),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: '秒数',
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                                initialItem: sIndex),
                            itemExtent: 40.0,
                            onSelectedItemChanged: (int index) => sIndex = index,
                            children: List.generate(
                                60,
                                (index) => Center(
                                    child: Text(index.toString().padLeft(2, '0')))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: FilledButton(
                    onPressed: () {
                      String sign = signIndex == 1 ? '-' : '+';
                      String hs = hIndex.toString().padLeft(2, '0');
                      String ms = mIndex.toString().padLeft(2, '0');
                      String ss = sIndex.toString().padLeft(2, '0');
                      String newOffset = '$sign$hs:$ms:$ss';

                      final error = controller.updateSettings(
                        offsetInput: newOffset,
                        maxGapMinutes: controller.maxGapMinutes,
                        overwriteExistingGps: controller.overwriteExistingGps,
                      );
                      if (error != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(error)));
                      }
                      Navigator.pop(bottomSheetContext);
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGapPicker(BuildContext context) {
    int gapIndex = controller.maxGapMinutes - 1;
    if (gapIndex < 0) gapIndex = 0;
    if (gapIndex > 29) gapIndex = 29;

    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '最大匹配时间差 (分钟)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: '最大匹配时间差分钟数',
                    child: CupertinoPicker(
                      scrollController:
                          FixedExtentScrollController(initialItem: gapIndex),
                      itemExtent: 40.0,
                      onSelectedItemChanged: (int index) => gapIndex = index,
                      children: List.generate(
                          30, (index) => Center(child: Text('${index + 1}'))),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: FilledButton(
                    onPressed: () {
                      final error = controller.updateSettings(
                        offsetInput: controller.offsetInput,
                        maxGapMinutes: gapIndex + 1,
                        overwriteExistingGps: controller.overwriteExistingGps,
                      );
                      if (error != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(error)));
                      }
                      Navigator.pop(bottomSheetContext);
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('参数设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 88, top: 16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('时间偏移'),
                    subtitle: Text(controller.offsetInput),
                    onTap: () => _showOffsetPicker(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('最大匹配时间差'),
                    subtitle: Text('${controller.maxGapMinutes} 分钟'),
                    onTap: () => _showGapPicker(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('应用主题'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto),
                              label: Text('系统')),
                          ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode),
                              label: Text('浅色')),
                          ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode),
                              label: Text('深色')),
                        ],
                        selected: {controller.themeMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          controller.updateThemeMode(newSelection.first);
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  SwitchListTile(
                    secondary: const Icon(Icons.gps_fixed),
                    value: controller.overwriteExistingGps,
                    onChanged: (value) {
                      final error = controller.updateSettings(
                        offsetInput: controller.offsetInput,
                        maxGapMinutes: controller.maxGapMinutes,
                        overwriteExistingGps: value,
                      );
                      if (error != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                    title: const Text('覆盖已有 GPS 的照片'),
                    subtitle: const Text('关闭后会跳过已经包含定位信息的图片'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

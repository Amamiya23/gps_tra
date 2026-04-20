import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import '../state/app_controller.dart';
import '../state/photo_geotag_controller.dart';
import '../state/track_recorder_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.appController,
    this.trackRecorderController,
  });

  final PhotoGeotagController controller;
  final AppController appController;
  final TrackRecorderController? trackRecorderController;

  Future<void> _showTextSettingDialog({
    required BuildContext context,
    required String title,
    required String label,
    required String initialValue,
    required String? Function(String value) onSave,
    String? helperText,
  }) async {
    final textController = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: textController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: label,
              helperText: helperText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(textController.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    textController.dispose();
    if (value == null) {
      return;
    }
    onSave(value);
  }

  Future<void> _pickExportFolder(BuildContext context) async {
    final selectedPath = await FilePicker.getDirectoryPath(
      dialogTitle: '选择导出文件夹',
    );
    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }

    final normalized = selectedPath.replaceAll('\\', '/');
    final marker = '/Pictures/';
    final index = normalized.toLowerCase().indexOf(marker.toLowerCase());
    final folderValue = index >= 0
        ? normalized.substring(index + marker.length)
        : p.basename(normalized);

    controller.updateSettings(
      offsetInput: controller.offsetInput,
      maxGapMinutes: controller.maxGapMinutes,
      overwriteExistingGps: controller.overwriteExistingGps,
      exportFolderName: folderValue,
      exportFileSuffix: controller.exportFileSuffix,
      writeToOriginal: controller.writeToOriginal,
    );
  }

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
                    '相机时间校准',
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
                        exportFolderName: controller.exportFolderName,
                        exportFileSuffix: controller.exportFileSuffix,
                        writeToOriginal: controller.writeToOriginal,
                      );
                      if (error != null) return;
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
                    '允许的最大时间差 (分钟)',
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
                        exportFolderName: controller.exportFolderName,
                        exportFileSuffix: controller.exportFileSuffix,
                        writeToOriginal: controller.writeToOriginal,
                      );
                      if (error != null) return;
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

  void _showRecordIntervalPicker(BuildContext context) {
    if (trackRecorderController == null) return;
    
    // Convert current interval in seconds to an index for the picker.
    // e.g., 1 sec -> 0, 2 sec -> 1, ..., 30 sec -> 29.
    int currentSeconds = trackRecorderController!.recordIntervalSeconds;
    int intervalIndex = currentSeconds - 1;
    if (intervalIndex < 0) intervalIndex = 0;
    if (intervalIndex > 59) intervalIndex = 59;

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
                    '轨迹记录频率 (秒/次)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: '轨迹记录频率秒数',
                    child: CupertinoPicker(
                      scrollController:
                          FixedExtentScrollController(initialItem: intervalIndex),
                      itemExtent: 40.0,
                      onSelectedItemChanged: (int index) => intervalIndex = index,
                      children: List.generate(
                          60, (index) => Center(child: Text('${index + 1}'))),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: FilledButton(
                    onPressed: () {
                      trackRecorderController!.updateRecordInterval(intervalIndex + 1);
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

  Future<void> _clearTemporaryCache(BuildContext context) async {
    final removed = await controller.clearTemporaryCache();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(removed > 0 ? '已清理 $removed 个缓存项' : '没有可清理的缓存'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工具设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AnimatedBuilder(
            animation: Listenable.merge([controller, appController, if (trackRecorderController != null) trackRecorderController!]),
            builder: (context, _) {
              final exportPreviewPath = controller.writeToOriginal
                  ? '原图保持原文件名，直接写回所选照片'
                  : 'Pictures/${controller.exportFolderName}/IMG_20260416_131059${controller.exportFileSuffix}.jpg';

              return ListView(
                padding: const EdgeInsets.only(bottom: 88, top: 16),
                children: [
                  if (trackRecorderController != null) ...[
                    ListTile(
                      leading: const Icon(Icons.speed),
                      title: const Text('轨迹记录频率'),
                      subtitle: Text('${trackRecorderController!.recordIntervalSeconds} 秒/次'),
                      onTap: () => _showRecordIntervalPicker(context),
                    ),
                    const Divider(height: 32),
                  ],
                  ListTile(
                    leading: const Icon(Icons.photo_camera_back_outlined),
                    title: const Text('位置写入方式'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.copy_outlined),
                            label: Text('另存为副本'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.photo_outlined),
                            label: Text('直接修改原图'),
                          ),
                        ],
                        selected: {controller.writeToOriginal},
                        onSelectionChanged: (selection) {
                          controller.updateSettings(
                            offsetInput: controller.offsetInput,
                            maxGapMinutes: controller.maxGapMinutes,
                            overwriteExistingGps: controller.overwriteExistingGps,
                            exportFolderName: controller.exportFolderName,
                            exportFileSuffix: controller.exportFileSuffix,
                            writeToOriginal: selection.first,
                          );
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('相机时间校准'),
                    subtitle: Text(controller.offsetInput),
                    onTap: () => _showOffsetPicker(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('允许的最大时间差'),
                    subtitle: Text('${controller.maxGapMinutes} 分钟'),
                    onTap: () => _showGapPicker(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('外观'),
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
                         selected: {appController.themeMode},
                         onSelectionChanged: (Set<ThemeMode> newSelection) {
                           appController.updateThemeMode(newSelection.first);
                         },
                       ),
                    ),
                  ),
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('照片保存位置'),
                    subtitle: Text(
                      'Pictures/${controller.exportFolderName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickExportFolder(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_rename_outline),
                    title: const Text('导出文件名后缀'),
                    subtitle: Text(
                      controller.exportFileSuffix.isEmpty ? '不追加后缀' : controller.exportFileSuffix,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _showTextSettingDialog(
                      context: context,
                      title: '导出文件名后缀',
                      label: '后缀',
                      initialValue: controller.exportFileSuffix,
                      helperText: '例如 _gps_copy，导出时会追加到文件名',
                      onSave: (value) => controller.updateSettings(
                        offsetInput: controller.offsetInput,
                        maxGapMinutes: controller.maxGapMinutes,
                        overwriteExistingGps: controller.overwriteExistingGps,
                        exportFolderName: controller.exportFolderName,
                        exportFileSuffix: value,
                        writeToOriginal: controller.writeToOriginal,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.visibility_outlined),
                    title: const Text('导出效果预览'),
                    subtitle: Text(
                      exportPreviewPath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('清理临时缓存'),
                    subtitle: const Text('清理历史导入留下的临时副本，不影响已导出的照片'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _clearTemporaryCache(context),
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
                        exportFolderName: controller.exportFolderName,
                        exportFileSuffix: controller.exportFileSuffix,
                        writeToOriginal: controller.writeToOriginal,
                      );
                      if (error != null) return;
                    },
                    title: const Text('覆盖已有位置'),
                    subtitle: const Text('关闭时，将跳过已含位置信息的照片'),
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

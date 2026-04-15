import 'package:flutter/material.dart';

import '../models/process_result.dart';
import '../models/selected_photo.dart';
import '../state/app_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppController _controller;
  late final TextEditingController _offsetController;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _offsetController = TextEditingController(text: _controller.offsetInput);
  }

  @override
  void dispose() {
    _offsetController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('GPX 照片定位器')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionCard(
                  title: '说明',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('1. 选择 1 个 GPX 文件。'),
                      Text('2. 选择多张 JPG。'),
                      Text('3. 如有需要，输入时间偏移，例如 -08:00:00。'),
                      Text('4. 预览匹配结果后，直接覆盖原图写入 GPS EXIF。'),
                    ],
                  ),
                ),
                _SectionCard(
                  title: '文件选择',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                _controller.isBusy ? null : () => _runAction(_controller.pickGpx),
                            icon: const Icon(Icons.route),
                            label: const Text('选择 GPX'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _controller.isBusy
                                ? null
                                : () => _runAction(_controller.pickPhotos),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('选择 JPG'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('GPX 文件: ${_controller.gpxFileName ?? '未选择'}'),
                      const SizedBox(height: 4),
                      Text('轨迹点数量: ${_controller.trackPoints.length}'),
                      const SizedBox(height: 4),
                      Text('照片数量: ${_controller.photos.length}'),
                      const SizedBox(height: 4),
                      Text('可写入照片: ${_controller.writablePhotoCount}'),
                    ],
                  ),
                ),
                _SectionCard(
                  title: '时间偏移',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _offsetController,
                        enabled: !_controller.isBusy,
                        decoration: const InputDecoration(
                          labelText: '偏移 HH:MM:SS',
                          hintText: '例如 -08:00:00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '这个偏移会直接加到照片 EXIF 时间后再和 GPX 时间比较。',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _controller.isBusy ? null : _applyOffset,
                        icon: const Icon(Icons.schedule),
                        label: const Text('应用偏移'),
                      ),
                    ],
                  ),
                ),
                _SectionCard(
                  title: '预览',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('预览匹配成功: ${_controller.matchedPreviewCount}/${_controller.photos.length}'),
                      const SizedBox(height: 12),
                      if (_controller.photos.isEmpty)
                        const Text('还没有选择照片。')
                      else
                        ..._controller.photos.take(20).map(_buildPreviewTile),
                      if (_controller.photos.length > 20)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('仅展示前 20 张，实际会处理全部 ${_controller.photos.length} 张。'),
                        ),
                    ],
                  ),
                ),
                _SectionCard(
                  title: '执行',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('写入会直接覆盖原 JPG 文件，请确认你已经备份。'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _controller.canProcess ? _confirmAndProcess : null,
                        icon: const Icon(Icons.save),
                        label: const Text('开始写入 GPS EXIF'),
                      ),
                      const SizedBox(height: 12),
                      Text(_controller.statusText),
                      if (_controller.isBusy) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _controller.progress),
                      ],
                    ],
                  ),
                ),
                if (_controller.results.isNotEmpty)
                  _SectionCard(
                    title: '结果',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _controller.results.map(_buildResultTile).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewTile(SelectedPhoto photo) {
    final preview = photo.preview;
    final title = Text(photo.name, maxLines: 1, overflow: TextOverflow.ellipsis);
    final subtitleLines = <String>[
      '拍摄时间: ${photo.rawOriginalDate ?? '未读取到'}',
      '已有 GPS: ${photo.hasGps ? '是' : '否'}',
    ];

    if (photo.loadError != null) {
      subtitleLines.add('错误: ${photo.loadError}');
    } else if (preview != null) {
      subtitleLines.add('匹配: ${preview.reason}');
      if (preview.location != null) {
        subtitleLines.add(
          '坐标: ${preview.location!.latitude.toStringAsFixed(6)}, '
          '${preview.location!.longitude.toStringAsFixed(6)}',
        );
      }
      if (preview.adjustedPhotoTime != null) {
        subtitleLines.add('校正后时间: ${_formatDateTime(preview.adjustedPhotoTime!)} UTC');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          photo.preview?.matched == true ? Icons.check_circle : Icons.info_outline,
          color: photo.preview?.matched == true ? Colors.green : Colors.orange,
        ),
        title: title,
        subtitle: Text(subtitleLines.join('\n')),
      ),
    );
  }

  Widget _buildResultTile(ProcessResult result) {
    final lines = <String>[result.message];
    if (result.location != null) {
      lines.add(
        '坐标: ${result.location!.latitude.toStringAsFixed(6)}, '
        '${result.location!.longitude.toStringAsFixed(6)}',
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          result.success ? Icons.check_circle : Icons.error_outline,
          color: result.success ? Colors.green : Colors.red,
        ),
        title: Text(result.photoName),
        subtitle: Text(lines.join('\n')),
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    await action();
    _showPendingMessage();
  }

  void _applyOffset() {
    _controller.updateOffset(_offsetController.text);
    _showPendingMessage();
  }

  Future<void> _confirmAndProcess() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('确认覆盖原图'),
              content: const Text('这会直接修改所选 JPG 的 GPS EXIF，且不可撤销。是否继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('继续'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await _runAction(_controller.processPhotos);
  }

  void _showPendingMessage() {
    final message = _controller.takeMessage();
    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

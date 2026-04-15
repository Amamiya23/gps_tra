import 'package:flutter/material.dart';

import '../models/selected_photo.dart';
import '../state/app_controller.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});

  final AppController? controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AppController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('照片轨迹写入'),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return IconButton(
                onPressed: _controller.isBusy ? null : _openSettings,
                tooltip: '设置',
                icon: const Icon(Icons.settings),
              );
            },
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return _controller.canProcess
              ? FloatingActionButton.extended(
                  onPressed: _controller.isBusy ? null : _confirmAndProcess,
                  icon: _controller.isBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_controller.isBusy ? '处理中...' : '开始写入'),
                )
              : const SizedBox.shrink();
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final hasGpx = _controller.gpxFileName != null;
              final hasPhotos = _controller.photos.isNotEmpty;

              return ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  if (_controller.isBusy)
                    LinearProgressIndicator(value: _controller.progress),
                  if (_controller.statusText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _controller.statusText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ListTile(
                    leading: Icon(
                      hasGpx ? Icons.check_circle : Icons.route,
                      color: hasGpx ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: const Text('选择 GPX 轨迹'),
                    subtitle: Text(_controller.gpxFileName ?? '未选择'),
                    onTap: _controller.isBusy
                        ? null
                        : () => _runAction(_controller.pickGpx),
                  ),
                  ListTile(
                    leading: Icon(
                      hasPhotos ? Icons.check_circle : Icons.photo_library,
                      color: hasPhotos ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: const Text('选择照片'),
                    subtitle: Text(_controller.photos.isEmpty
                        ? '未选择'
                        : '已选 ${_controller.photos.length} 张 (可写入 ${_controller.writablePhotoCount} 张)'),
                    onTap: _controller.isBusy
                        ? null
                        : () => _runAction(_controller.pickPhotos),
                  ),
                  const Divider(),
                  if (_controller.photos.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.preview),
                      title: const Text('照片匹配预览'),
                      subtitle: Text('点击查看 ${_controller.photos.length} 张照片的匹配状态'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _controller.isBusy ? null : _showPreviewSheet,
                    ),
                  if (_controller.results.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: const Text('处理结果'),
                      subtitle: Text(
                          '成功 ${_controller.results.where((r) => r.success).length} 张，'
                          '失败 ${_controller.results.where((r) => !r.success).length} 张'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _controller.isBusy ? null : _showResultsSheet,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPreviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) {
        int selectedFilter = 0; // 0: All, 1: Matched, 2: Issues

        return StatefulBuilder(
          builder: (context, setState) {
            final displayPhotos = _controller.photos.where((p) {
              if (selectedFilter == 0) return true;
              final isMatched = p.preview?.matched == true && p.loadError == null;
              if (selectedFilter == 1) return isMatched;
              return !isMatched; // 2: Issues
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    AppBar(
                      title: const Text('照片预览'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('全部')),
                            ButtonSegment(value: 1, label: Text('已匹配')),
                            ButtonSegment(value: 2, label: Text('异常')),
                          ],
                          selected: {selectedFilter},
                          onSelectionChanged: (selection) {
                            setState(() => selectedFilter = selection.first);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: displayPhotos.isEmpty
                          ? const Center(child: Text('没有符合条件的照片'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: displayPhotos.length,
                              itemBuilder: (context, index) {
                                final photo = displayPhotos[index];
                                return ListTile(
                                  leading: const Icon(Icons.photo),
                                  title: Text(
                                    photo.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(_buildPreviewDetail(photo)),
                                  trailing: _buildPreviewTrailing(context, photo),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showResultsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) {
        int selectedFilter = 0; // 0: All, 1: Success, 2: Failed

        return StatefulBuilder(
          builder: (context, setState) {
            final displayResults = _controller.results.where((r) {
              if (selectedFilter == 0) return true;
              if (selectedFilter == 1) return r.success;
              return !r.success; // 2: Failed
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    AppBar(
                      title: const Text('处理结果'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('全部')),
                            ButtonSegment(value: 1, label: Text('成功')),
                            ButtonSegment(value: 2, label: Text('失败')),
                          ],
                          selected: {selectedFilter},
                          onSelectionChanged: (selection) {
                            setState(() => selectedFilter = selection.first);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: displayResults.isEmpty
                          ? const Center(child: Text('没有符合条件的结果'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: displayResults.length,
                              itemBuilder: (context, index) {
                                final result = displayResults[index];
                                return ListTile(
                                  leading: Icon(
                                    result.success
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: result.success
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.error,
                                  ),
                                  title: Text(
                                    result.photoName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(result.message),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget? _buildPreviewTrailing(BuildContext context, SelectedPhoto photo) {
    if (photo.loadError != null) {
      return Icon(Icons.error, color: Theme.of(context).colorScheme.error);
    }
    if (photo.preview?.matched == true) {
      return Icon(Icons.check, color: Theme.of(context).colorScheme.primary);
    }
    if (photo.hasGps && !_controller.overwriteExistingGps) {
      return Icon(Icons.skip_next, color: Theme.of(context).colorScheme.tertiary);
    }
    return null;
  }

  String _buildPreviewDetail(SelectedPhoto photo) {
    if (photo.loadError != null) {
      return photo.loadError!;
    }

    final preview = photo.preview;
    if (preview == null) {
      return '等待匹配';
    }

    if (!preview.matched || preview.location == null) {
      return preview.reason;
    }

    final latitude = preview.location!.latitude.toStringAsFixed(6);
    final longitude = preview.location!.longitude.toStringAsFixed(6);
    final timeText = preview.adjustedPhotoTime == null
        ? ''
        : ' · ${_formatDateTime(preview.adjustedPhotoTime!)}';
    return '$latitude, $longitude$timeText';
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(controller: _controller),
      ),
    );

    _showPendingMessage();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    await action();
    _showPendingMessage();
  }

  Future<void> _confirmAndProcess() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('确认写入'),
              content: Text(
                _controller.overwriteExistingGps
                    ? '这会直接修改所选 JPG 的 GPS EXIF，请确认原图已经备份。'
                    : '这会写入没有 GPS 的 JPG，已经包含 GPS 的照片会被跳过。',
              ),
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
    return '$year-$month-$day $hour:$minute';
  }
}

import 'package:flutter/material.dart';

import '../models/gpx_track_point.dart';
import '../models/selected_photo.dart';
import '../state/app_controller.dart';
import '../state/photo_geotag_controller.dart';
import '../state/track_recorder_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.appController,
    required this.trackRecorderController,
  });

  final PhotoGeotagController controller;
  final AppController appController;
  final TrackRecorderController trackRecorderController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PhotoGeotagController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('写入位置'),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: _controller.isReadyToProcess
                ? FloatingActionButton.extended(
                    key: const ValueKey('fab_extended'),
                    onPressed: _controller.isBusy ? null : _confirmAndProcess,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _controller.isBusy
                          ? SizedBox(
                              key: const ValueKey('fab_busy_icon'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: _controller.progress > 0 ? _controller.progress : null,
                              ),
                            )
                          : const Icon(Icons.save, key: ValueKey('fab_save_icon')),
                    ),
                    label: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _controller.isBusy
                            ? (_controller.totalProcessCount > 0
                                ? '处理中 (${_controller.currentProcessCount}/${_controller.totalProcessCount})'
                                : '处理中...')
                            : '开始写入',
                        key: ValueKey('fab_label_${_controller.isBusy}'),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('fab_empty')),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final hasGpx = _controller.gpxFileName != null;
                  return ListTile(
                    leading: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        hasGpx ? Icons.check_circle : Icons.route,
                        key: ValueKey('gpx_icon_$hasGpx'),
                        color: hasGpx ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    title: const Text('选择轨迹'),
                    subtitle: Text(_controller.gpxFileName ?? '未选择'),
                    onTap: _controller.isBusy
                        ? null
                        : _chooseTrackSource,
                  );
                },
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final hasPhotos = _controller.photos.isNotEmpty;
                  return ListTile(
                    leading: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        hasPhotos ? Icons.check_circle : Icons.photo_library,
                        key: ValueKey('photos_icon_$hasPhotos'),
                        color: hasPhotos ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    title: const Text('选择照片'),
                    subtitle: Text(_controller.photos.isEmpty
                        ? '未选择'
                        : '已选 ${_controller.photos.length} 张 (可写入 ${_controller.writablePhotoCount} 张)'),
                    onTap: _controller.isBusy
                        ? null
                        : () => _runAction(_controller.pickPhotos),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_controller.photos.isNotEmpty) const Divider(),
                      if (_controller.photos.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.preview),
                          title: const Text('照片匹配预览'),
                          subtitle: Text('共 ${_controller.photos.length} 张照片，点击查看详情'),
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseTrackSource() async {
    await showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('选择外部 GPX 文件'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _runAction(_controller.pickGpx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('选择应用内轨迹'),
                subtitle: Text(
                  widget.trackRecorderController.history.isEmpty
                      ? '还没有可用的历史轨迹'
                      : '从已保存的轨迹记录中选择',
                ),
                onTap: widget.trackRecorderController.history.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _showInternalTrackPicker();
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInternalTrackPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                AppBar(
                  title: const Text('应用内轨迹'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: widget.trackRecorderController.history.length,
                    itemBuilder: (context, index) {
                      final item = widget.trackRecorderController.history[index];
                      return ListTile(
                        leading: const Icon(Icons.route),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatDateTime(item.startedAt)} · ${_formatDuration(item.duration)} · ${item.pointCount} 点',
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _selectInternalTrack(item.id, item.title);
                        },
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
  }

  Future<void> _selectInternalTrack(String sessionId, String title) async {
    try {
      final points = await widget.trackRecorderController.loadSessionPoints(sessionId);
      if (!mounted) {
        return;
      }
      if (points.isEmpty) {
        return;
      }

      _controller.loadTrackPoints(
        name: title,
        points: points
            .map(
              (point) => GpxTrackPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude,
                time: point.timestamp.toUtc(),
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载应用内轨迹失败，请重试。')),
      );
    }
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
                          tooltip: '关闭',
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
                          ? const Center(child: Text('暂无照片'))
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
                                  subtitle: Text(
                                    _buildPreviewDetail(photo),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                          tooltip: '关闭',
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
                          ? const Center(child: Text('暂无记录'))
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
                                  subtitle: Text(
                                    result.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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

  Future<void> _runAction(Future<void> Function() action) async {
    await action();
  }

  Future<void> _confirmAndProcess() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('确认写入位置'),
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

  String _formatDateTime(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

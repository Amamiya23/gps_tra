import 'dart:async';
import 'package:flutter/material.dart';

import '../models/recorded_track_session.dart';
import '../models/track_recording_state.dart';
import '../state/app_controller.dart';
import '../state/photo_geotag_controller.dart';
import '../state/track_recorder_controller.dart';

class TrackRecorderScreen extends StatefulWidget {
  const TrackRecorderScreen({
    super.key,
    required this.controller,
    required this.onUseForGeotag,
    required this.appController,
    required this.photoController,
  });

  final TrackRecorderController controller;
  final AppController appController;
  final PhotoGeotagController photoController;
  final Future<void> Function(RecordedTrackSession session) onUseForGeotag;

  @override
  State<TrackRecorderScreen> createState() => _TrackRecorderScreenState();
}

class _TrackRecorderScreenState extends State<TrackRecorderScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('轨迹记录'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) =>
                          _buildStatusStrip(context, controller),
                    ),
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        if (!controller.locationPermissionGranted ||
                            !controller.backgroundPermissionGranted ||
                            !controller.locationEnabled ||
                            controller.hasRecoverableSession) {
                          return _buildGuidancePanel(context, controller);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) =>
                          _buildActiveSessionCard(context, controller),
                    ),
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) =>
                          _buildHistorySection(context, controller),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) =>
                    _buildBottomActions(context, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusStrip(
      BuildContext context, TrackRecorderController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.shield_outlined,
                    size: 16, color: colorScheme.primary),
                label: Text(
                  controller.locationPermissionGranted
                      ? controller.backgroundPermissionGranted
                          ? '定位已授权'
                          : '缺少后台定位'
                      : '定位未授权',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.notifications_active_outlined,
                    size: 16, color: colorScheme.primary),
                label: Text(
                  controller.locationEnabled ? '服务已开启' : '服务未开启',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(_statusIcon(controller.recordingState),
                    size: 16,
                    color: _statusColor(context, controller.recordingState)),
                label: Text(
                  _statusChipLabel(controller.recordingState),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidancePanel(
    BuildContext context,
    TrackRecorderController controller,
  ) {
    final actions = <Widget>[];

    if (!controller.locationPermissionGranted ||
        !controller.backgroundPermissionGranted) {
      actions.add(
        FilledButton.icon(
          onPressed: _handlePermissionRequest,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('请求定位权限'),
        ),
      );
    }

    if (!controller.locationEnabled) {
      actions.add(
        OutlinedButton.icon(
          onPressed: controller.refreshStatus,
          icon: const Icon(Icons.refresh),
          label: const Text('已开启，刷新重试'),
        ),
      );
    }

    if (controller.hasRecoverableSession) {
      actions.add(
        OutlinedButton.icon(
          onPressed: controller.dismissRecoveredSession,
          icon: const Icon(Icons.delete_outline),
          label: const Text('放弃草稿'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!controller.locationPermissionGranted)
            const Text('需要定位权限才能在后台记录轨迹。'),
          if (controller.locationPermissionGranted &&
              !controller.backgroundPermissionGranted)
            const Text('未开启“始终允许”定位，切到后台后可能中断记录。'),
          if (!controller.locationEnabled)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('系统定位服务已关闭，请前往系统设置开启。'),
            ),
          if (controller.hasRecoverableSession)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('检测到异常中断的轨迹记录。您可以继续、停止或放弃该记录。'),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(
      BuildContext context, TrackRecorderController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = controller.recordingState;
    final isRecording = state == TrackRecordingState.recording;
    final isIdle = state == TrackRecordingState.idle;

    String title;
    IconData icon;
    if (isIdle) {
      title = '未开始';
      icon = Icons.radio_button_unchecked;
    } else if (isRecording) {
      title = '记录中';
      icon = Icons.fiber_manual_record;
    } else {
      title = '已暂停';
      icon = Icons.pause_circle_outline;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Card(
        elevation: 0,
        color: isRecording
            ? colorScheme.primaryContainer.withAlpha(80)
            : colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isRecording
                ? colorScheme.primary.withAlpha(50)
                : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: _statusColor(context, state),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _statusColor(context, state),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _ElapsedDurationText(
                      controller: controller,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.bold,
                        color: isIdle
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      context,
                      '距离',
                      _formatDistance(controller.currentDistanceMeters),
                    ),
                  ),
                  Expanded(
                    child: _buildMetric(
                      context,
                      '开始时间',
                      isIdle
                          ? '--:--'
                          : _formatDateTime(
                                  controller.startedAt ?? DateTime.now())
                              .split(' ')[1],
                    ),
                  ),
                  Expanded(
                    child:
                        _buildMetric(context, '点数', '${controller.pointCount}'),
                  ),
                  Expanded(
                    child: _buildMetric(
                      context,
                      '均速',
                      _formatSpeed(controller.currentAverageSpeedMps),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tune,
                      size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isIdle
                          ? '采样配置: ${controller.recordIntervalSeconds}秒/次'
                          : '采样: ${controller.currentSamplingQualityLabel}'
                              '${controller.currentAverageSampleIntervalSeconds <= 0 ? '' : ' · 间隔${controller.currentAverageSampleIntervalSeconds.toStringAsFixed(1)}s'}'
                              '${controller.currentAverageAccuracyMeters == null ? '' : ' · 精度${controller.currentAverageAccuracyMeters!.toStringAsFixed(0)}m'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (controller.currentPoints.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '最新: ${controller.currentPoints.last.latitude.toStringAsFixed(5)}, ${controller.currentPoints.last.longitude.toStringAsFixed(5)}'
                        '${controller.currentPoints.last.accuracy == null ? '' : ' · 精度${controller.currentPoints.last.accuracy!.toStringAsFixed(0)}m'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ] else if (!isIdle) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_searching,
                        size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '正在等待定位信号...',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(
      BuildContext context, TrackRecorderController controller) {
    return Column(
      children: [
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('历史轨迹'),
          subtitle: Text('共 ${controller.history.length} 条已保存的轨迹，点击管理'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showHistorySheet(context, controller),
        ),
      ],
    );
  }

  void _showHistorySheet(
      BuildContext context, TrackRecorderController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            final theme = Theme.of(context);

            return Column(
              children: [
                AppBar(
                  title: const Text('历史轨迹'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      if (!controller.isLoaded) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (controller.history.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.route_outlined,
                                  size: 48,
                                  color: theme
                                      .colorScheme.surfaceContainerHighest),
                              const SizedBox(height: 16),
                              Text(
                                '暂无历史数据',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '开始记录后，保存的轨迹会显示在这里',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: controller.history.length,
                        itemBuilder: (context, index) {
                          final item = controller.history[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.route,
                                  color: theme.colorScheme.primary, size: 20),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${_formatDateTime(item.startedAt)} · ${_formatDuration(item.duration)} · ${item.pointCount}点\n'
                              '${_formatDistance(item.distanceMeters)} · ${_formatSpeed(item.averageSpeedMps)}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<_HistoryAction>(
                              tooltip: '更多操作',
                              icon: const Icon(Icons.more_vert),
                              onSelected: (action) async {
                                Navigator.of(sheetContext).pop();
                                await Future<void>.delayed(Duration.zero);
                                if (!mounted) {
                                  return;
                                }
                                await _handleHistoryAction(item, action);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: _HistoryAction.useForGeotag,
                                  child: Text('用于照片写入'),
                                ),
                                PopupMenuItem(
                                  value: _HistoryAction.export,
                                  child: Text('导出 GPX'),
                                ),
                                PopupMenuItem(
                                  value: _HistoryAction.share,
                                  child: Text('分享'),
                                ),
                                PopupMenuItem(
                                  value: _HistoryAction.rename,
                                  child: Text('重命名'),
                                ),
                                PopupMenuItem(
                                  value: _HistoryAction.delete,
                                  child: Text('删除',
                                      style: TextStyle(
                                          color: theme.colorScheme.error)),
                                ),
                              ],
                            ),
                          );
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

  Widget _buildBottomActions(
      BuildContext context, TrackRecorderController controller) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: controller.recordingState == TrackRecordingState.idle
                    ? _handleStartRecording
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('开始', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: controller.recordingState ==
                        TrackRecordingState.recording
                    ? controller.pauseRecording
                    : controller.recordingState == TrackRecordingState.paused
                        ? controller.resumeRecording
                        : null,
                icon: Icon(
                  controller.recordingState == TrackRecordingState.paused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                label: Text(
                  controller.recordingState == TrackRecordingState.paused
                      ? '继续'
                      : '暂停',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: controller.recordingState == TrackRecordingState.idle
                    ? null
                    : controller.stopRecording,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停止', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusChipLabel(TrackRecordingState state) {
    switch (state) {
      case TrackRecordingState.idle:
        return '待开始';
      case TrackRecordingState.recording:
        return '记录中';
      case TrackRecordingState.paused:
        return '已暂停';
    }
  }

  IconData _statusIcon(TrackRecordingState state) {
    switch (state) {
      case TrackRecordingState.idle:
        return Icons.radio_button_unchecked;
      case TrackRecordingState.recording:
        return Icons.fiber_manual_record;
      case TrackRecordingState.paused:
        return Icons.pause_circle_outline;
    }
  }

  Color _statusColor(BuildContext context, TrackRecordingState state) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (state) {
      case TrackRecordingState.idle:
        return colorScheme.outline;
      case TrackRecordingState.recording:
        return colorScheme.primary;
      case TrackRecordingState.paused:
        return colorScheme.tertiary;
    }
  }

  Future<void> _handleHistoryAction(
    RecordedTrackSession item,
    _HistoryAction action,
  ) async {
    switch (action) {
      case _HistoryAction.useForGeotag:
        await widget.onUseForGeotag(item);
        return;
      case _HistoryAction.export:
        await widget.controller.exportSession(item.id);
        return;
      case _HistoryAction.share:
        await widget.controller.shareSession(item.id);
        return;
      case _HistoryAction.rename:
        await _renameItem(item);
        return;
      case _HistoryAction.delete:
        await widget.controller.deleteSession(item.id);
        return;
    }
  }

  Future<void> _handleStartRecording() async {
    final controller = widget.controller;
    if (!controller.locationPermissionGranted ||
        !controller.backgroundPermissionGranted) {
      await controller.requestPermissions();
      if (!mounted) {
        return;
      }

      if (!controller.locationPermissionGranted) {
        await _showPermissionDeniedDialog();
        return;
      }

      if (!controller.backgroundPermissionGranted) {
        await _showBackgroundPermissionDialog();
        return;
      }
    }

    if (!controller.locationEnabled) {
      await _showLocationGuideDialog();
      return;
    }

    await controller.startRecording();
  }

  Future<void> _handlePermissionRequest() async {
    await widget.controller.requestPermissions();
    if (!mounted) {
      return;
    }

    final controller = widget.controller;
    if (!controller.locationPermissionGranted) {
      await _showPermissionDeniedDialog();
      return;
    }

    if (!controller.backgroundPermissionGranted) {
      await _showBackgroundPermissionDialog();
    }
  }

  Future<void> _showPermissionDeniedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('未获得定位权限'),
          content: const Text(
            '没有定位权限就无法开始轨迹记录。你可以重新点击“开始”或“请求定位权限”再次申请。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBackgroundPermissionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('还缺少后台定位权限'),
          content: const Text(
            '系统已经授予基础定位权限，但后台定位权限仍未开启。\n\n如果现在开始记录，切到后台后系统可能会停止采样。你可以先去系统权限页面补开，再回来点击“已打开定位后刷新”。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLocationGuideDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('请先打开系统定位'),
          content: const Text(
            '当前系统定位服务没有开启。\n\n请在系统设置中打开定位服务，然后回到这里点击“已打开定位后刷新”，再开始记录。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameItem(RecordedTrackSession item) async {
    final controller = TextEditingController(text: item.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (value == null || value.isEmpty) {
      return;
    }

    await widget.controller.renameSession(item.id, value);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDateTime(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatSpeed(double metersPerSecond) {
    final kmh = metersPerSecond * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }
}

class _ElapsedDurationText extends StatefulWidget {
  const _ElapsedDurationText({
    required this.controller,
    required this.style,
  });

  final TrackRecorderController controller;
  final TextStyle? style;

  @override
  State<_ElapsedDurationText> createState() => _ElapsedDurationTextState();
}

class _ElapsedDurationTextState extends State<_ElapsedDurationText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _ElapsedDurationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      _syncTicker();
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _syncTicker();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    _syncTicker();
    setState(() {});
  }

  void _syncTicker() {
    final shouldTick =
        widget.controller.recordingState == TrackRecordingState.recording;
    if (shouldTick && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }
    if (!shouldTick) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    var displayDuration = controller.elapsed;
    if (controller.recordingState == TrackRecordingState.recording) {
      displayDuration +=
          DateTime.now().difference(controller.lastSnapshotReceivedAt);
    }

    final hours = displayDuration.inHours.toString().padLeft(2, '0');
    final minutes = (displayDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (displayDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Text('$hours:$minutes:$seconds', style: widget.style);
  }
}

enum _HistoryAction { useForGeotag, export, share, rename, delete }

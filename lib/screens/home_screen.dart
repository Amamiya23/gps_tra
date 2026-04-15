import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/process_result.dart';
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
  static const int _previewLimit = 8;

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('轨迹写入'),
            actions: [
              IconButton(
                onPressed: _controller.isBusy ? null : _openSettings,
                tooltip: '设置',
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _BottomActionBar(
              statusText: _controller.statusText,
              progress: _controller.progress,
              isBusy: _controller.isBusy,
              canProcess: _controller.canProcess,
              onProcess: _confirmAndProcess,
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final tileWidth = isWide
                  ? (constraints.maxWidth - 52) / 2
                  : constraints.maxWidth;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _HeroPanel(
                    statusText: _controller.statusText,
                    isBusy: _controller.isBusy,
                    matchedCount: _controller.matchedPreviewCount,
                    photoCount: _controller.photos.length,
                  ),
                  const SizedBox(height: 16),
                  _SectionSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeading(
                          title: '处理节奏',
                          subtitle: '三步就能完成，不再把说明堆满首页。',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StageIndicator(
                                label: '轨迹',
                                active: _controller.gpxFileName != null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StageIndicator(
                                label: '照片',
                                active: _controller.photos.isNotEmpty,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StageIndicator(
                                label: '写入',
                                active: _controller.results.isNotEmpty,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _QuickActionTile(
                          title: _controller.gpxFileName ?? '导入 GPX 轨迹',
                          subtitle: '${_controller.trackPoints.length} 个轨迹点',
                          icon: Icons.route_rounded,
                          enabled: !_controller.isBusy,
                          onTap: () => _runAction(_controller.pickGpx),
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _QuickActionTile(
                          title: _controller.photos.isEmpty
                              ? '导入 JPG 照片'
                              : '已选 ${_controller.photos.length} 张照片',
                          subtitle: '${_controller.writablePhotoCount} 张可写入',
                          icon: Icons.photo_library_rounded,
                          enabled: !_controller.isBusy,
                          onTap: () => _runAction(_controller.pickPhotos),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _StatTile(
                          label: '轨迹点',
                          value: _controller.trackPoints.length.toString(),
                          hint: _controller.gpxFileName ?? '等待导入',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _StatTile(
                          label: '可写入照片',
                          value: _controller.writablePhotoCount.toString(),
                          hint: '${_controller.photosWithGpsCount} 张已有 GPS',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeading(
                          title: '当前设置',
                          subtitle: '把次级选项收进设置里，首页只保留结果和动作。',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _SettingChip(
                              icon: Icons.schedule_rounded,
                              label: '偏移 ${_controller.offsetInput}',
                            ),
                            _SettingChip(
                              icon: Icons.timelapse_rounded,
                              label: '时间差 ${_controller.maxGapMinutes} 分钟',
                            ),
                            _SettingChip(
                              icon: _controller.overwriteExistingGps
                                  ? Icons.gps_fixed_rounded
                                  : Icons.gps_off_rounded,
                              label: _controller.overwriteExistingGps
                                  ? '覆盖已有 GPS'
                                  : '跳过已有 GPS',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _controller.isBusy ? null : _openSettings,
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('打开设置'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewSection(),
                  if (_controller.results.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildResultSection(),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPreviewSection() {
    final photos =
        _controller.photos.take(_previewLimit).toList(growable: false);

    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: '预览',
            subtitle: _controller.photos.isEmpty
                ? '导入照片后，这里会显示简洁的匹配状态。'
                : '已匹配 ${_controller.matchedPreviewCount} / ${_controller.photos.length}',
          ),
          if (_controller.photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final photo in photos) ...[
              _PreviewTile(
                photo: photo,
                overwriteExistingGps: _controller.overwriteExistingGps,
                detailText: _buildPreviewDetail(photo),
              ),
              if (photo != photos.last) const SizedBox(height: 10),
            ],
            if (_controller.photos.length > _previewLimit) ...[
              const SizedBox(height: 12),
              Text(
                '仅展示前 $_previewLimit 张，实际处理会覆盖全部已选照片。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return _SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: '结果',
            subtitle:
                '成功 ${_controller.results.where((item) => item.success).length} / ${_controller.results.length}',
          ),
          const SizedBox(height: 16),
          for (final result in _controller.results) ...[
            _ResultTile(result: result),
            if (result != _controller.results.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
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
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SettingsScreen(controller: _controller),
      ),
    );

    if (updated == true) {
      _showPendingMessage();
    }
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.statusText,
    required this.isBusy,
    required this.matchedCount,
    required this.photoCount,
  });

  final String statusText;
  final bool isBusy;
  final int matchedCount;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [AppTheme.surfaceStrong, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isBusy ? '处理中' : '离线模式',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '把轨迹直接补回照片',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '导入 GPX 和 JPG，确认后批量写入 GPS EXIF。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: '已匹配',
                  value: '$matchedCount / $photoCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMetric(
                  label: '状态',
                  value: statusText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _StageIndicator extends StatelessWidget {
  const _StageIndicator({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppTheme.primary : AppTheme.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: active ? Colors.white : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: active ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : AppTheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppTheme.primary.withValues(alpha: 0.10)
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon,
                    color: enabled ? AppTheme.primary : AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                theme.textTheme.labelLarge?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SettingChip extends StatelessWidget {
  const _SettingChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.photo,
    required this.overwriteExistingGps,
    required this.detailText,
  });

  final SelectedPhoto photo;
  final bool overwriteExistingGps;
  final String detailText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = photo.preview;

    final bool hasError = photo.loadError != null;
    final bool matched = preview?.matched == true;
    final bool skippedForGps = photo.hasGps && !overwriteExistingGps;
    final Color accent = hasError
        ? AppTheme.danger
        : matched
            ? AppTheme.success
            : skippedForGps
                ? AppTheme.warning
                : AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  photo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(
                label: hasError
                    ? '读取失败'
                    : matched
                        ? '已匹配'
                        : skippedForGps
                            ? '将跳过'
                            : '待确认',
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (photo.rawOriginalDate != null)
                _MetaPill(label: photo.rawOriginalDate!)
              else
                const _MetaPill(label: '缺少拍摄时间'),
              if (photo.hasGps) const _MetaPill(label: '已有 GPS'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detailText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final ProcessResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = result.success ? AppTheme.success : AppTheme.danger;
    final location = result.location;
    final locationText = location == null
        ? result.message
        : '${result.message} · ${location.latitude.toStringAsFixed(6)}, '
            '${location.longitude.toStringAsFixed(6)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.photoName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  locationText,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.statusText,
    required this.progress,
    required this.isBusy,
    required this.canProcess,
    required this.onProcess,
  });

  final String statusText;
  final double progress;
  final bool isBusy;
  final bool canProcess;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            statusText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          if (isBusy) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: canProcess ? onProcess : null,
            icon: Icon(
                isBusy ? Icons.hourglass_top_rounded : Icons.gps_fixed_rounded),
            label: Text(isBusy ? '处理中...' : '开始写入'),
          ),
        ],
      ),
    );
  }
}

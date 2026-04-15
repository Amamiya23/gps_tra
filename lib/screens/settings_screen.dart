import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _offsetController;
  late double _matchWindow;
  late bool _overwriteExistingGps;

  @override
  void initState() {
    super.initState();
    _offsetController =
        TextEditingController(text: widget.controller.offsetInput);
    _matchWindow = widget.controller.maxGapMinutes.toDouble();
    _overwriteExistingGps = widget.controller.overwriteExistingGps;
  }

  @override
  void dispose() {
    _offsetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _SettingsPanel(
            title: '匹配参数',
            subtitle: '把不常改的选项收在这里，首页只保留主流程。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _offsetController,
                  decoration: const InputDecoration(
                    labelText: '时间偏移',
                    hintText: '例如 -08:00:00',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('最大匹配时间差', style: theme.textTheme.titleSmall),
                    Text(
                      '${_matchWindow.round()} 分钟',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _matchWindow,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${_matchWindow.round()} 分钟',
                  onChanged: (value) {
                    setState(() {
                      _matchWindow = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsPanel(
            title: '写入策略',
            subtitle: '默认保持当前行为，也可以改成更保守的方式。',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _overwriteExistingGps,
              onChanged: (value) {
                setState(() {
                  _overwriteExistingGps = value;
                });
              },
              title: const Text('覆盖已有 GPS 的照片'),
              subtitle: const Text('关闭后会跳过已经包含定位信息的图片'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.done_rounded),
            label: const Text('保存设置'),
          ),
        ],
      ),
    );
  }

  void _save() {
    final error = widget.controller.updateSettings(
      offsetInput: _offsetController.text,
      maxGapMinutes: _matchWindow.round(),
      overwriteExistingGps: _overwriteExistingGps,
    );
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop(true);
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

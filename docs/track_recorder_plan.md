# 轨迹记录功能实施清单

## 目标范围

1. 底部双 tab：`写入照片` / `记录轨迹`
2. 后台持续记录轨迹
3. 轨迹保存在 app 内
4. 写入页可直接选择“应用内轨迹”
5. 支持导出、分享
6. 支持完整历史管理
7. 自动命名，后续可重命名
8. 不做地图预览

## 总体实施顺序

1. 壳层导航重构
2. 状态与职责拆分
3. 历史数据层
4. 记录页 UI 与状态机
5. Android 后台定位与前台服务
6. GPX 导出/分享
7. 写入页联动应用内轨迹
8. 权限与异常流程补齐
9. 验证与回归

## 第一阶段：壳层导航重构

目标：先把单页 app 变成双 tab 容器，不改核心业务。

1. 新增 `lib/screens/shell_screen.dart`
   - 使用 `NavigationBar`
   - 两个 tab：
     - `写入照片`
     - `记录轨迹`
   - 维护当前 index
   - 承载两个一级页面

2. 调整 `lib/main.dart`
   - `home` 从 `HomeScreen` 改为 `ShellScreen`
   - 保留现有主题与动态配色逻辑

3. 重命名/角色调整
   - 当前 `lib/screens/home_screen.dart`
   - 逻辑上转为“写入照片页”
   - 文件名可以先不改，后续稳定后再决定是否改成 `photo_write_screen.dart`

交付结果：
- app 底部出现双导航
- 左 tab 仍是现有写入功能
- 右 tab 先放占位页

## 第二阶段：状态与职责拆分

目标：避免 `AppController` 继续膨胀。

1. 保留 `lib/state/app_controller.dart`
   - 负责全局主题
   - 负责全局页面级状态（必要时可加当前 tab）
   - 不再承载照片写入和轨迹记录全部逻辑

2. 新增 `lib/state/photo_geotag_controller.dart`
   - 从现有 `AppController` 中迁移这些能力：
     - 选 GPX 文件
     - 选照片
     - 预览匹配
     - 写入 EXIF
     - 结果列表
     - 写入设置
   - 增加“从应用内轨迹选择”的入口

3. 新增 `lib/state/track_recorder_controller.dart`
   - 负责：
     - 权限状态
     - GPS 状态
     - 当前录制状态
     - 会话统计
     - 历史列表
     - 导出/分享
     - 把历史轨迹交给写入页使用

交付结果：
- 全局、写入、记录三类状态分离
- 后续新增功能不会污染现有代码

## 第三阶段：历史数据模型与持久化

目标：建立完整历史管理能力。

1. 新增模型文件
   - `lib/models/recorded_track_session.dart`
   - `lib/models/recorded_track_point.dart`
   - 可选：`lib/models/track_recording_state.dart`

2. `RecordedTrackSession` 建议字段
   - `id`
   - `title`
   - `startedAt`
   - `endedAt`
   - `status`
   - `pointCount`
   - `durationSeconds`
   - `distanceMeters`
   - `createdAt`
   - `updatedAt`
   - `exportedGpxPath` 可选

3. `RecordedTrackPoint` 建议字段
   - `id`
   - `sessionId`
   - `latitude`
   - `longitude`
   - `altitude`
   - `accuracy`
   - `speed`
   - `timestamp`

4. 引入本地数据库
   - 推荐：`sqflite` + `path_provider`
   - 需要新增 repository：
     - `lib/repositories/track_history_repository.dart`

5. repository 能力
   - 创建会话
   - 追加轨迹点
   - 结束会话
   - 查询历史列表
   - 查询单次会话详情
   - 重命名
   - 删除会话及其点
   - 标记导出文件路径

自动命名规则：
- 默认标题：`yyyy-MM-dd HH:mm`
- 停止录制时自动生成
- 历史详情页/菜单中允许重命名

交付结果：
- 轨迹历史可持久化
- 关闭 app 后不会丢失
- 支持完整历史管理基础

## 第四阶段：记录页 UI 与状态机

目标：先把“记录轨迹”页交互做完整，再接入原生能力。

1. 新增 `lib/screens/track_recorder_screen.dart`
2. 页面结构建议
   - 顶部：状态区
     - 权限状态
     - 定位服务状态
     - 当前录制状态
   - 中部：当前会话统计
     - 已记录时长
     - 点数
     - 最近更新时间
   - 主操作区
     - 开始记录
     - 暂停/继续
     - 停止
   - 下部：历史列表
     - 最近在上
     - 点击进入详情或打开操作菜单

3. 历史项操作
   - 用于照片写入
   - 导出 GPX
   - 分享
   - 重命名
   - 删除

4. 新增可选页面
   - `lib/screens/track_session_detail_screen.dart`
   - 不做地图，仅展示文本详情和操作

5. 状态机建议
   - `idle`
   - `recording`
   - `paused`
   - `saving`
   - `error`

交付结果：
- 记录页结构完整
- 即使原生后台录制还没接入，也能先完成交互框架

## 第五阶段：Android 后台定位与前台服务

目标：满足“必须后台也能运行”。

1. 更新 `android/app/src/main/AndroidManifest.xml`
   - 增加权限：
     - `ACCESS_FINE_LOCATION`
     - `ACCESS_COARSE_LOCATION`
     - `ACCESS_BACKGROUND_LOCATION`
     - `FOREGROUND_SERVICE`
     - `FOREGROUND_SERVICE_LOCATION`
   - 注册前台服务
   - 配置通知相关元信息（如需要）

2. Android 侧新增原生类
   - `TrackRecordingService.kt`
   - 可选：
     - `LocationRecorder.kt`
     - `TrackDatabaseHelper.kt` 或直接通过 channel 回 Flutter 落库
     - `TrackRecordingPlugin`/通道封装类

3. 定位实现
   - 使用 `FusedLocationProviderClient`
   - 支持：
     - 开始持续更新
     - 暂停停止采样
     - 恢复
     - 停止并结束会话

4. 通信方式
   - `MethodChannel`
     - `requestPermissions`
     - `startRecording`
     - `pauseRecording`
     - `resumeRecording`
     - `stopRecording`
     - `getRecorderStatus`
   - `EventChannel`
     - 推送实时状态
     - 推送新轨迹点
     - 推送错误与权限变化

5. 建议采样策略
   - 时间间隔：5 秒
   - 最小位移：5-10 米
   - 精度过差时丢弃
   - 暂停时不采样

6. 后台约束
   - 常驻通知显示“正在记录轨迹”
   - 处理 app 回到前台/退到后台/被系统回收后的状态恢复

交付结果：
- 轨迹录制可在后台持续工作
- Flutter 页面只负责展示与控制，不依赖页面存活

## 第六阶段：GPX 导出、缓存与分享

目标：把历史轨迹转成可用文件。

1. 新增 `lib/services/gpx_export_service.dart`
   - 输入：`RecordedTrackSession + List<RecordedTrackPoint>`
   - 输出：标准 GPX XML

2. 新增文件管理服务
   - `lib/services/track_file_service.dart`
   - 职责：
     - 获取 app 内存储目录
     - 生成导出文件名
     - 保存 GPX
     - 删除历史附属文件

3. 导出位置
   - 优先保存到 app 内目录
   - 记录 `exportedGpxPath`

4. 分享能力
   - 推荐引入分享插件
   - 历史项支持“分享 GPX”

5. 导出能力
   - 历史项支持“导出到外部”
   - 由系统分享/保存流程处理

交付结果：
- 每条历史记录都能生成 GPX
- 能导出、能分享
- 能在 app 内重复使用

## 第七阶段：写入页接入“应用内轨迹”

目标：不走系统文件 API 也能选轨迹。

1. 改造 `lib/screens/home_screen.dart`
   - 当前“选择 GPX 轨迹”改为“选择轨迹”
   - 点击后弹出底部菜单：
     - 从文件导入
     - 从历史轨迹选择

2. 新增历史选择页面或底部弹层
   - `lib/screens/track_picker_screen.dart` 或 bottom sheet
   - 展示 app 内历史列表
   - 选择后直接把轨迹点交给 `PhotoGeotagController`

3. `PhotoGeotagController` 新增能力
   - `loadTrackFromHistory(sessionId)` 或 `selectRecordedTrack(session)`
   - 不再依赖文件路径解析
   - 可直接注入 `List<GpxTrackPoint>`

4. 历史记录联动
   - 在“记录轨迹”页历史项中支持：
     - `用于照片写入`
   - 执行后直接跳转到写入 tab 并自动选中该轨迹

交付结果：
- 用户可以完全在 app 内闭环完成记录 -> 写入
- 系统文件选择只作为补充入口

## 第八阶段：权限、异常与恢复流程

目标：让功能达到可用级，而不是只在理想环境下工作。

1. 权限场景处理
   - 未授权前台定位
   - 已授权前台但未授权后台定位
   - 定位服务关闭
   - 通知权限不足（如 Android 13+ 相关场景）
   - 被系统限制后台活动

2. 页面状态提示
   - 无权限时给清晰操作入口
   - GPS 关闭时可跳系统设置
   - 录制失败时保留可恢复状态

3. 历史管理异常
   - 删除历史时同步删除点和缓存 GPX
   - 导出失败时提示原因
   - 文件不存在时重新导出

4. 会话恢复
   - app 重启后，如果上次仍在录制/异常退出
   - 记录页应能恢复状态或给出修复提示

交付结果：
- 功能能覆盖主要真实使用场景
- 不容易出现“录了但没存上”之类严重问题

## 第九阶段：验证与回归

目标：控制这个大功能引入后的回归风险。

1. 功能回归
   - 现有照片写入链路是否正常
   - 主题切换是否仍正常
   - 动态配色是否仍正常
   - 设置是否仍自动保存

2. 新功能验证
   - 前台录制
   - 后台录制
   - 暂停/继续
   - 停止后生成历史
   - 重命名
   - 删除
   - 导出
   - 分享
   - 用于照片写入

3. 边界场景
   - 长时间录制
   - 无网络/GPS 弱信号
   - 手机锁屏
   - 切到后台数十分钟
   - 重启 app 后恢复

## 建议新增文件清单

### Dart

1. `lib/screens/shell_screen.dart`
2. `lib/screens/track_recorder_screen.dart`
3. `lib/screens/track_session_detail_screen.dart` 可选
4. `lib/screens/track_picker_screen.dart` 可选
5. `lib/state/photo_geotag_controller.dart`
6. `lib/state/track_recorder_controller.dart`
7. `lib/models/recorded_track_session.dart`
8. `lib/models/recorded_track_point.dart`
9. `lib/models/track_recording_state.dart` 可选
10. `lib/repositories/track_history_repository.dart`
11. `lib/services/gpx_export_service.dart`
12. `lib/services/track_file_service.dart`
13. `lib/services/location_channel_service.dart` 可选

### Android

1. `android/app/src/main/kotlin/.../TrackRecordingService.kt`
2. `LocationRecorder.kt` 可选
3. 通知/服务辅助类 可选
4. 修改 `AndroidManifest.xml`

### 依赖大概率需要新增

1. `sqflite`
2. `path_provider`
3. `share_plus`
4. 定位核心建议 Android 原生实现

## 里程碑拆分

1. **M1：导航与架构拆分**
   - 底部双 tab
   - controller 拆分
   - 写入功能保持正常

2. **M2：历史存储与记录页框架**
   - 记录页 UI
   - 历史列表
   - 自动命名
   - 重命名/删除

3. **M3：后台录制**
   - 前台服务
   - 后台持续采点
   - 状态同步

4. **M4：GPX 导出与 app 内联动**
   - 导出/分享
   - 从历史直接用于照片写入

5. **M5：异常与恢复完善**
   - 权限引导
   - 状态恢复
   - 边界打磨

## 建议优先级

1. 先做壳层 + controller 拆分
2. 再做历史数据层
3. 再做 Android 后台定位
4. 最后做导出分享和写入联动

这样风险最低。

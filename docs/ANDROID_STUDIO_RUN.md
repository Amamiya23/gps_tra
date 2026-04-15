# Android Studio 运行说明

本文档说明如何在本机通过 Android Studio 打开并运行 `gpx_photo_geotagger`。

## 当前本地环境

- 项目目录：`/home/cat/gps_tra`
- Flutter SDK：`/home/cat/flutter`
- 已完成：`flutter create --platforms=android .`
- 已验证：`flutter pub get`、`flutter analyze`、`flutter test`

## 先决条件

请确认 Android Studio 已安装以下插件：

- `Flutter`
- `Dart`

通常安装 `Flutter` 插件时会自动带上 `Dart` 插件。

## 正确的打开方式

不要打开 `android/` 子目录。

应该在 Android Studio 中打开项目根目录：

```text
/home/cat/gps_tra
```

步骤：

1. 打开 Android Studio
2. 选择 `Open`
3. 选择目录 `/home/cat/gps_tra`
4. 等待索引和 Gradle 同步完成

## 配置 Flutter SDK

如果 Android Studio 第一次打开 Flutter 项目，通常会提示配置 Flutter SDK。

SDK 路径填：

```text
/home/cat/flutter
```

如果没有自动弹窗，可以手动设置：

1. `File` -> `Settings`
2. 搜索 `Flutter`
3. 在 `Flutter SDK path` 中填写 `/home/cat/flutter`
4. 应用设置

## 获取依赖

项目打开后，一般 Android Studio 会自动执行 `pub get`。

如果没有自动执行，可手动操作：

1. 打开 `pubspec.yaml`
2. 点击右上角 `Pub get`

或者使用底部 Terminal：

```bash
/home/cat/flutter/bin/flutter pub get
```

## 选择运行设备

你可以使用以下任一方式：

- Android 模拟器
- 已连接并开启 USB 调试的真机

### 使用模拟器

1. 打开 Android Studio
2. 进入 `Tools` -> `Device Manager`
3. 创建或启动一个 Android 虚拟设备
4. 等待模拟器完全启动

### 使用真机

1. 手机打开开发者选项
2. 开启 `USB 调试`
3. 用数据线连接电脑
4. 手机上确认调试授权

可用 Terminal 检查设备：

```bash
/home/cat/flutter/bin/flutter devices
```

## 运行项目

在 Android Studio 中：

1. 顶部设备选择框里选中你的模拟器或手机
2. 运行配置选择 `main.dart`
3. 点击绿色三角形 `Run`

如果没有自动出现运行配置，可手动新建：

1. 顶部选择 `Add Configuration...`
2. 新建 `Flutter`
3. Dart entrypoint 选择：`lib/main.dart`
4. Working directory 选择：`/home/cat/gps_tra`
5. 保存后运行

## 首次运行后你应该看到什么

启动成功后，应用首页会显示：

- `GPX 照片定位器`
- `选择 GPX`
- `选择 JPG`
- `开始写入 GPS EXIF`

## 应用使用流程

1. 点击 `选择 GPX`
2. 选择一个 `.gpx` 文件
3. 点击 `选择 JPG`
4. 选择多张 `.jpg` 或 `.jpeg`
5. 根据需要填写时间偏移，例如 `-08:00:00`
6. 点击 `应用偏移`
7. 确认预览结果
8. 点击 `开始写入 GPS EXIF`
9. 确认覆盖原图

## 重要注意事项

- 本应用当前只支持 `Android`
- 当前只支持 `JPG/JPEG`
- 写入方式是直接覆盖原图，不可撤销
- 建议先拿几张测试照片试跑
- 如果相机时间是中国时区而 GPX 是 UTC，常见偏移是 `-08:00:00`

## 常见问题

### 1. 终端输入 `flutter` 提示 command not found

这是因为系统 `PATH` 没有加 Flutter，不影响 Android Studio 运行，只要 IDE 里配置了 Flutter SDK 即可。

如果你想让终端也能直接用 `flutter`，把这行加入 `~/.zshrc`：

```bash
export PATH="$HOME/flutter/bin:$PATH"
```

然后执行：

```bash
source ~/.zshrc
```

### 2. Android Studio 提示 Flutter SDK 未配置

直接把 SDK 路径设置成：

```text
/home/cat/flutter
```

### 3. 运行时没有设备

先检查：

- 模拟器是否已经启动
- 真机是否已开启 USB 调试
- `flutter devices` 是否能看到设备

### 4. 编译时报 Android 依赖问题

本项目已经在 `android/app/build.gradle.kts` 中加入：

```kotlin
implementation("androidx.exifinterface:exifinterface:1.3.7")
```

如果 Gradle 缓存异常，可执行：

```bash
/home/cat/flutter/bin/flutter clean
/home/cat/flutter/bin/flutter pub get
```

然后重新运行。

### 5. 选择照片后无法写入 GPS

通常是以下原因之一：

- 选中的文件并非 JPG/JPEG
- 照片没有可读取的 EXIF 拍摄时间
- 照片时间与 GPX 时间差太大
- 时间偏移设置不正确

## 推荐排查命令

如果你想在项目根目录手动检查：

```bash
cd /home/cat/gps_tra
/home/cat/flutter/bin/flutter pub get
/home/cat/flutter/bin/flutter analyze
/home/cat/flutter/bin/flutter test
/home/cat/flutter/bin/flutter run
```

## 代码位置

关键代码在这些文件：

- Flutter 入口：`lib/main.dart`
- 主界面：`lib/screens/home_screen.dart`
- 状态控制：`lib/state/app_controller.dart`
- GPX 解析：`lib/services/gpx_parser_service.dart`
- 时间匹配：`lib/services/location_match_service.dart`
- Android EXIF 写入：`android/app/src/main/kotlin/com/example/gpx_photo_geotagger/MainActivity.kt`

## 结论

在 Android Studio 中运行这个项目的关键点只有两个：

1. 打开项目根目录 `/home/cat/gps_tra`
2. Flutter SDK 路径设置为 `/home/cat/flutter`

完成这两步后，选择设备并运行 `lib/main.dart` 即可。

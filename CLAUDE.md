# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指引。

## 构建与开发命令

```bash
# 安装依赖
flutter pub get

# 生成路由和 JSON 序列化代码（新增/修改路由或模型后需运行）
flutter pub run build_runner build

# 持续监听模式自动生成代码
flutter pub run build_runner watch

# 构建 Android 发布包
flutter build apk --release

# 构建 iOS 发布包
flutter pub run flutter_launcher_icons:main
flutter clean
flutter build ipa --release

# 运行所有测试
flutter test

# 运行单个测试文件
flutter test test/widget_test.dart
```

## 架构概览

本项目是一个 Flutter 应用，使用 **GetX** 进行状态管理、路由和依赖注入。

### 基类层级

每个页面/控制器对都继承以下基类：

- `BaseController` (`lib/base/base_controller.dart`) — 继承 GetX `SuperController`，集成 `PageLifeState` mixin 和 `EventBus`，所有控制器继承此类。
- `BasePage<T>` (`lib/base/base_page.dart`) — 继承 `GetView<T>`，提供生命周期钩子，无 Scaffold 的页面继承此类。
- `BaseScaffoldPage<T>` (`lib/base/base_scaffold_page.dart`) — 继承 `BasePage`，通过可重写方法提供 AppBar/Body/BottomNav 结构。
- `PageLifeState` mixin — 提供 `onPageVisible`、`onPageActive`、`onPageInActive`、`onPageInVisible` 钩子。

### 路由

路由通过注解驱动，由 `build_runner` 自动生成：
- 用 `@GetXRoutePage('/路由路径')` 注解页面
- 生成结果输出到 `lib/generated/route_table.dart`
- 修改路由后需运行 `flutter pub run build_runner build`

### 功能模块结构

`lib/page/<feature>/` 下每个功能模块的目录结构：
```
<feature>/
├── model/      # 数据模型（含 JSON 序列化）
├── view/       # 页面组件（简单功能的 Page 和 Controller 常在同一文件）
└── widget/     # 功能专属组件
```

### 网络层

- `DioClient` (`lib/common/net/dio_client.dart`) — Dio HTTP 客户端单例
- `DioInterceptor` — 处理认证头和请求日志
- `DioResponse` — 封装 API 响应，错误自动映射为本地化用户提示

### 分页与刷新

`BaseRefreshView<T>` (`lib/widget/base_easy_refresh.dart`) 是带下拉刷新的分页列表标准通用组件，新增列表页面应直接使用，不要自行实现分页逻辑。

### 主题

`AppThemeExtension` (`lib/common/theme/app_theme_extension.dart`) 为 Material 主题扩展了语义化颜色（success、warning、info、divider、shimmer 等）。通过 `Theme.of(context).extension<AppThemeExtension>()` 访问。

### 国际化

- ARB 文件：`lib/l10n/intl_en.arb`（英文）、`lib/l10n/intl_zh.arb`（中文）
- 通过生成的 `S` 类访问字符串：`S.of(context).someKey`
- 修改 ARB 文件后需运行 `build_runner`

### 状态与事件

- 状态管理：GetX 响应式变量（`.obs`）和 `GetBuilder`
- 跨组件通信：`EventBus` (`lib/utils/event_bus.dart`) — 在 `BaseController` 中订阅，任意位置发布

### 响应式布局

`ScreenUtil` 以 375×812（iPhone 参考尺寸）为设计基准，使用数字扩展 `.w`、`.h`、`.sp` 进行响应式尺寸适配。

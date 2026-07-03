# Omnicast 项目优化建议

本文档基于当前项目结构说明，对 Flutter + GetX + Dio 架构进行优化梳理。建议按优先级逐步推进，先解决稳定性、测试、网络层和状态管理问题，再做性能、工程化和发布质量优化。

## 一、优先级 P0：稳定性与质量基线

### 1. 补齐测试体系

当前项目说明中主要提供了 `flutter test` 和单个测试文件示例，建议优先建立可持续的测试基线。

建议补充：

- `DioClient` 单元测试
- `DioResponse` 错误映射测试
- Repository 层测试
- Controller 状态流转测试
- 分页刷新组件 `BaseRefreshView` 行为测试
- 登录、首页、列表分页、详情页等关键链路集成测试

目标：

- 核心业务逻辑具备单元测试
- 网络错误、鉴权失败、空数据、分页失败等异常场景有覆盖
- `flutter test` 可作为提交前的基础质量门禁

### 2. 优化网络层

重点关注文件：

- `lib/common/net/dio_client.dart`
- `lib/common/net/dio_interceptor.dart`
- `lib/common/net/dio_response.dart`

建议优化：

- 按环境区分 `baseUrl`、timeout、日志开关
- release 环境禁止打印 token、请求头、完整响应体
- 所有请求统一支持取消，避免页面销毁后异步回调更新状态
- 统一错误类型：网络断开、超时、服务端错误、鉴权失效、业务错误
- 页面层不要直接处理原始 Dio 异常
- API 响应统一 envelope，避免页面各自解析零散字段

### 3. Controller 生命周期安全

GetX 项目需要重点关注 controller 生命周期和异步任务。

建议检查：

- `onInit` / `onReady` 中发起的请求是否支持取消
- `Timer`、`StreamSubscription`、`Worker` 是否在 `onClose` 中释放
- 页面销毁后是否仍有异步回调修改 `.obs` 或调用 `update()`
- 全局 controller 是否持有页面级状态
- 是否存在重复注册 controller 或依赖泄漏

建议约定：

- 页面级异步请求应绑定 controller 生命周期
- controller 只维护当前页面所需状态
- 长生命周期状态单独放入 service/store

## 二、优先级 P1：架构与可维护性

### 4. 建立统一 Repository 层

建议每个业务模块形成稳定结构：

```text
lib/page/<feature>/
├── model/
├── repository/
├── view/
└── widget/
```

优化方向：

- Controller 不直接依赖 `DioClient`
- Controller 依赖业务 Repository
- Repository 负责 API 调用、DTO 转换、错误归一
- 页面只处理展示状态，不处理底层网络细节

收益：

- 更容易写测试
- 更容易 mock 数据
- 网络接口变化对页面影响更小
- 业务逻辑边界更清晰

### 5. 拆分大页面和大 Controller

建议控制文件规模：

- Page 文件专注布局
- Controller 文件专注状态和动作
- 复杂 UI 拆到 `widget/`
- 复杂业务逻辑下沉到 repository/service
- 单个文件尽量控制在 200-400 行，避免超过 800 行

检查方向：

- `view/*.dart` 是否存在超过 500 行的页面
- Controller 是否同时处理网络、业务计算、UI 状态和导航
- 是否存在重复 widget 可以抽取
- 是否存在多个页面复制相似布局

### 6. 优化 GetX 响应式粒度

重点检查：

- 是否用一个 `Obx` 包住整页
- 高频状态变化是否导致大面积 rebuild
- 列表 item 是否被不必要地整体刷新
- `GetBuilder` 是否合理使用 `id`
- 是否把临时 UI 状态和业务状态混在一起

建议：

- 哪个小区域依赖状态，就只包哪个小区域
- 列表 item 尽量拆成独立 widget
- 高频变化状态单独拆分
- 避免在 `build` 中创建复杂对象或发起副作用

### 7. 统一主题、尺寸和文案

项目已有 `AppThemeExtension`，建议继续收敛页面中的硬编码。

建议清理：

- 裸 `Color(0x...)`
- 重复字号
- 重复间距
- 重复圆角
- 不走 `S.of(context)` 的硬编码文案
- 不走主题扩展的 success/warning/info/error/divider 等状态色

目标：

- 支持暗色模式更容易
- 品牌色调整成本更低
- 国际化更完整
- UI 风格更统一

## 三、优先级 P2：性能、工程化与发布质量

### 8. 标准化构建与代码生成流程

项目依赖 `build_runner` 生成路由和 JSON 序列化代码，建议统一脚本。

推荐命令：

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

建议在 CI 中检查：

- 生成文件是否遗漏
- `flutter analyze` 是否通过
- `flutter test` 是否通过
- release 构建是否可用

### 9. 加强 lint 规则

建议检查：

- `analysis_options.yaml`
- 是否启用 `flutter_lints`
- 是否启用更严格规则

推荐关注规则：

- `prefer_const_constructors`
- `avoid_print`
- `unawaited_futures`
- `cancel_subscriptions`
- `close_sinks`
- `use_build_context_synchronously`
- `avoid_dynamic_calls`

### 10. 检查依赖升级与安全风险

建议定期运行：

```bash
flutter pub outdated
flutter pub deps
```

重点关注：

- 已停止维护的依赖
- 存在安全风险的依赖
- 与当前 Flutter SDK 不兼容的依赖
- 多个包重复实现相同能力
- 体积较大的非必要依赖

### 11. 发布安全配置

Android/iOS 发布前建议检查：

- release 环境关闭调试日志
- Android 是否启用 R8/ProGuard
- 是否误提交 keystore、证书、API key
- Android 是否允许明文 HTTP
- 权限是否最小化
- iOS `Info.plist` 权限说明是否准确
- 网络请求是否包含敏感信息日志
- 错误提示是否泄露服务端细节

### 12. 分页列表体验优化

项目已有 `BaseRefreshView<T>`，建议统一所有分页列表使用该组件。

分页列表应覆盖：

- 首屏 loading
- 空状态
- 错误重试
- 加载更多
- 加载更多失败重试
- 下拉刷新
- 防重复请求
- 页码和缓存一致性

### 13. 图片和资源优化

建议检查：

- asset 图片是否过大
- 列表图片是否有缓存
- 图片是否有占位和错误态
- 图片展示是否有尺寸约束
- 页面切换时是否存在图片解码卡顿
- 未使用资源是否可以删除

建议封装统一业务图片组件，处理：

- 占位图
- 加载失败
- 缓存策略
- 圆角
- 尺寸约束
- 默认裁剪方式

## 四、建议执行路线图

### 第一阶段：质量基线

目标：先知道项目当前状态。

执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter pub outdated
```

产出：

- 当前 lint 问题清单
- 当前测试结果
- 依赖升级风险清单
- 首批高优先级修复项

### 第二阶段：网络层与错误处理

目标：让 API 调用、错误提示、日志、安全边界统一。

执行：

- 梳理 `DioClient`
- 梳理 interceptor
- 统一 response envelope
- 统一异常类型
- 增加网络层单元测试
- 禁止 release 输出敏感日志

### 第三阶段：选一个复杂页面做样板

目标：形成可复制的模块规范。

执行：

- 选择一个复杂业务页面
- 拆分 Page、Controller、Repository、Widget
- 缩小 Obx/GetBuilder 范围
- 补 Controller 和 Repository 测试
- 固化目录和命名规范

### 第四阶段：推广到其他模块

目标：减少重复实现，降低长期维护成本。

执行：

- 统一分页列表
- 统一图片组件
- 统一空状态和错误状态
- 清理硬编码颜色和文案
- 补齐关键链路测试

## 五、推荐优先落地清单

短期最值得做的 10 项：

1. 运行 `flutter analyze` 并修复高优先级问题
2. 运行 `flutter test`，确保基础测试可用
3. 梳理网络层日志，release 禁止敏感日志
4. 为 `DioResponse` 增加错误映射测试
5. 为主要 Repository 增加单元测试
6. 检查 controller 的异步任务释放
7. 找一个复杂页面拆分成 Page + Controller + Repository + Widget
8. 缩小大范围 `Obx` 的 rebuild 区域
9. 清理页面中的硬编码颜色和文案
10. 建立 CI：`flutter analyze` + `flutter test`

## 六、后续可继续深入检查的文件

建议优先检查：

- `lib/common/net/dio_client.dart`
- `lib/common/net/dio_interceptor.dart`
- `lib/common/net/dio_response.dart`
- `lib/base/base_controller.dart`
- `lib/base/base_page.dart`
- `lib/base/base_scaffold_page.dart`
- `lib/widget/base_easy_refresh.dart`
- `lib/common/theme/app_theme_extension.dart`
- `lib/generated/route_table.dart`
- `pubspec.yaml`
- `analysis_options.yaml`
- `android/app/build.gradle`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

## 七、总结

当前项目已经具备比较清晰的基础结构：GetX 基类、注解路由、统一网络层、主题扩展和分页组件。下一步优化重点不应是引入更多框架，而是把已有基础设施用得更统一：

- 网络错误统一
- 页面状态统一
- 分页体验统一
- Repository 边界统一
- 测试和 CI 补齐
- release 安全配置收紧

优先从网络层、测试和一个复杂页面样板开始，收益最大，也最容易形成后续团队规范。

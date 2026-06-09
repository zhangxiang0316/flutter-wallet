# 沐晨钱包

沐晨钱包是一个基于 Flutter 和 GetX 构建的多链加密钱包应用。当前支持创建钱包、助记词/私钥导入、多钱包切换、链上余额查询、USD 估值、转账、收款二维码、资产显示隐藏、自定义代币、语言切换和主题切换。

## 功能概览

- 多钱包：支持创建、导入、切换、重命名和移除钱包。
- 多链资产：支持 BNB Smart Chain、Ethereum、X Layer、Solana、TRON。
- 资产估值：稳定币直接计价，非稳定币通过实时价格换算为 USD 后汇总。
- 转账收款：支持按链和币种发起转账，收款页可切换链和币种并展示二维码。
- 资产管理：支持隐藏/显示指定币种，并手动添加自定义代币。
- 本地安全：私钥和助记词使用本地加密存储，查看敏感信息需要钱包密码。

## 项目结构

```text
lib/
  base/                 基础页面和控制器
  common/               通用网络、主题和模型
  generated/            路由和国际化生成文件
  l10n/                 ARB 国际化源文件
  page/                 页面、控制器和页面组件
    home/               首页、钱包切换、余额展示
    transfer/           转账页面
    receive/            收款页面
    wallet/             钱包详情页面
    setting/            设置和资产显示管理
  utils/                通用工具方法
  wallet/               钱包模型、链上服务、密钥和转账逻辑
assets/
  icons/ img/ svg/      应用图标和静态资源
test/                   单元测试
```

平台相关配置位于 `android/`、`ios/`、`web/`、`macos/`、`linux/`、`windows/`。除包名、权限、图标、签名等平台事项外，优先在 `lib/` 内实现业务逻辑。

## 环境要求

- Flutter SDK：项目 `pubspec.yaml` 当前要求 Dart SDK `^3.10.7`。
- Android Studio 或 Xcode：用于 Android/iOS 真机和打包。
- 首次拉取后先执行依赖安装：

```bash
flutter pub get
```

## 常用开发命令

```bash
flutter run
```

运行到当前选中的设备。

```bash
flutter analyze
```

执行静态检查，规则来自 `analysis_options.yaml`。

```bash
flutter test
```

运行全部测试。

```bash
flutter test test/wallet_crypto_service_test.dart
```

运行钱包加密服务的单文件测试。

```bash
dart format lib test
```

格式化 Dart 代码。

## 代码生成

修改路由注解、JSON 模型或其他 generator 相关代码后运行：

```bash
flutter pub run build_runner build
```

修改 `lib/l10n/*.arb` 后运行：

```bash
flutter pub run intl_utils:generate
```

如果生成文件冲突，可以在确认无本地手改生成文件后使用：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 打包

Android release APK：

```bash
flutter build apk --release
```

iOS release IPA：

```bash
flutter build ipa --release
```

更新应用图标后可重新生成平台图标：

```bash
flutter pub run flutter_launcher_icons:main
```

## 开发约定

- 使用 GetX 进行路由、状态管理和依赖查找。
- 页面文件放在 `lib/page/<feature>/view/`，控制器放在 `controller/`。
- 页面拆分组件优先放在对应页面的 `view/widgets/` 下。
- UI 文案优先走国际化：同时维护 `lib/l10n/intl_zh.arb` 和 `lib/l10n/intl_en.arb`。
- UI 尺寸继续使用 `flutter_screenutil` 的 `.w`、`.h`、`.sp`。
- 文件命名使用 `snake_case.dart`，类名使用 `UpperCamelCase`，变量和方法使用 `lowerCamelCase`。

## 安全说明

本项目包含私钥、助记词、转账签名等高风险逻辑。不要提交真实私钥、助记词、API 密钥或生产钱包数据。涉及转账、密钥读取、RPC 节点、资产估值的改动需要重点验证地址校验、金额精度、链选择、异常提示和失败回滚。

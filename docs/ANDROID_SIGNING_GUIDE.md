# Android Release 签名指南

## 1. 安全边界

Android Release 使用三类配置：

| 文件 | 是否提交 | 内容 |
| --- | --- | --- |
| `android/keystore/*.jks` | 否 | Release 私钥库 |
| `android/key.properties` | 否 | keystore 路径、别名和密码 |
| `android/release-signing.properties` | 是 | applicationId 和公开的证书 SHA-256 |

`.gitignore` 已忽略 keystore 和 `key.properties`。不要在文档、脚本、命令行参数、
Issue 或聊天记录中写入真实密码，也不要把 keystore 放进 GitHub Release。

## 2. 创建或恢复 keystore

新项目可以交互式创建 keystore：

```bash
mkdir -p android/keystore
keytool -genkeypair \
  -keystore android/keystore/flutter-wallet-release.jks \
  -alias flutter-wallet-release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

`keytool` 会交互式询问密码，避免密码进入终端历史。已有正式版本必须继续使用原
keystore；更换私钥会导致已安装版本无法直接升级，启用 Google Play App Signing
的项目应按 Play Console 的密钥升级流程处理。

## 3. 配置 key.properties

创建被 Git 忽略的 `android/key.properties`：

```properties
storeFile=../keystore/flutter-wallet-release.jks
storePassword=<your-store-password>
keyAlias=<your-key-alias>
keyPassword=<your-key-password>
```

`storeFile` 相对于 `android/app/` 解析。Release 构建会检查：

- `key.properties` 存在；
- 四个字段都不是空值；
- `storeFile` 指向真实文件；
- Gradle 能使用别名和密码完成签名。

任一检查失败都会终止 Release 构建，不会回退到 Debug 签名。Debug/Profile 构建
仍使用 Android Debug 证书。

## 4. 固定正式证书指纹

获取 keystore 的 SHA-256，密码由 `keytool` 交互式询问：

```bash
keytool -list -v \
  -keystore android/keystore/flutter-wallet-release.jks \
  -alias flutter-wallet-release
```

将输出中的 SHA-256 去掉冒号后，保存到已提交的
`android/release-signing.properties`：

```properties
applicationId=com.zx.wallet
certificateSha256=<64-character-certificate-sha256>
```

证书指纹不属于私钥，可以提交。不要在没有确认升级策略的情况下随意修改它。

## 5. 构建与自动验证

构建 APK：

```bash
./scripts/build_android.sh
```

生成：

- `releases/android/flutter-Wallet-vX.X.X.apk`；
- `releases/android/flutter-Wallet-vX.X.X.apk.sha256`。

脚本会自动验证 APK 签名完整性、固定证书 SHA-256、applicationId、versionName、
versionCode 和文件名。

构建 AAB：

```bash
./scripts/build_android_bundle.sh
```

生成：

- `releases/android/flutter-Wallet-vX.X.X.aab`；
- `releases/android/flutter-Wallet-vX.X.X.aab.sha256`。

脚本会使用 `jarsigner` 验证 AAB 完整性，使用 `keytool` 精确匹配固定证书指纹，
并核对 Release manifest 构建元数据中的 applicationId、versionName 和 versionCode。
只有全部校验通过才会显示构建成功。

## 6. 手动复核

查看 APK 证书：

```bash
apksigner verify --verbose --print-certs \
  releases/android/flutter-Wallet-vX.X.X.apk
```

复核下载文件哈希：

```bash
cd releases/android
shasum -a 256 -c flutter-Wallet-vX.X.X.apk.sha256
shasum -a 256 -c flutter-Wallet-vX.X.X.aab.sha256
```

查看 Gradle 各变体使用的证书：

```bash
cd android
./gradlew :app:signingReport
```

Release 和 Debug 的 SHA-256 必须不同，Release 必须与
`android/release-signing.properties` 一致。

## 7. 发布检查清单

- `pubspec.yaml` 的 versionName/versionCode 已更新；
- Release 构建没有 Debug 签名回退；
- APK/AAB 证书指纹匹配固定值；
- APK applicationId 和版本匹配；
- 产物名称包含正确版本；
- APK、AAB 及对应 `.sha256` 一起上传；
- 从 GitHub Release 下载后再次执行哈希校验；
- keystore、密码和 `key.properties` 未被提交或上传。

## 8. 备份与恢复

- keystore 至少保留两份加密备份，存放在不同的受控位置；
- 密码和 alias 存入团队密码管理器；
- 定期验证备份 keystore 可以读取且证书指纹一致；
- 不要用重新生成同名文件的方式“恢复”keystore，新文件拥有不同私钥；
- 怀疑私钥或密码泄露时，立即停止发布并按应用商店密钥升级流程处置。

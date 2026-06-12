# Android APK 签名配置文档

## 📋 签名文件信息

### 密钥库详情

- **文件路径**: `android/app/keystore/muchen-wallet.keystore`
- **密钥库类型**: PKCS12
- **密钥别名**: `muchen-wallet-key`
- **密钥算法**: RSA 2048位
- **有效期**: 10000天 (至 2053-10-29)
- **签名算法**: SHA256withRSA

### 证书信息

- **所有者**: CN=Zhang Xiang, OU=Muchen Wallet Team, O=Muchen, L=Beijing, ST=Beijing, C=CN
- **SHA256指纹**: `6A:9A:23:10:51:33:BD:23:11:16:D1:64:04:64:AD:83:3F:D6:6D:D7:6C:8D:2E:0B:29:50:90:89:E1:CF:94:9D`
- **SHA1指纹**: `60:40:6C:71:55:DC:1F:7F:A7:D6:5A:62:E6:7E:8F:86:92:5E:05:2E`

### 密码信息 (重要 - 请安全保管)

```
密钥库密码: muchen2024
密钥密码: muchen2024
密钥别名: muchen-wallet-key
```

⚠️ **警告**: 这些密码非常重要！
- 丢失后无法恢复
- 用于应用更新时必须使用相同的密钥
- 建议保存到密码管理器中

---

## 🔧 配置步骤

### 1. 密钥库文件已生成

文件位置: `android/app/keystore/muchen-wallet.keystore`

验证命令:
```bash
keytool -list -v -keystore android/app/keystore/muchen-wallet.keystore -storepass muchen2024
```

### 2. 配置文件已创建

文件: `android/key.properties`
```properties
storePassword=muchen2024
keyPassword=muchen2024
keyAlias=muchen-wallet-key
storeFile=keystore/muchen-wallet.keystore
```

### 3. 配置 build.gradle.kts

需要在 `android/app/build.gradle.kts` 中添加签名配置：

在文件顶部添加读取配置:
```kotlin
val keystorePropertiesFile = rootProject.file("../key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

在 `android` 块中添加签名配置:
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
        // 其他配置...
    }
}
```

### 4. 配置 .gitignore

确保密钥文件不会被提交到 Git:

在 `.gitignore` 中添加:
```
# Android signing
android/key.properties
android/app/keystore/
*.keystore
*.jks
```

---

## 🏗️ 构建签名 APK

### 本地构建

```bash
# 构建签名的 Release APK
flutter build apk --release

# 输出位置
# build/app/outputs/flutter-apk/app-release.apk
```

### 验证签名

```bash
# 查看 APK 签名信息
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

---

## 🚀 GitHub Actions 配置

### 添加 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets:

1. **ANDROID_KEYSTORE_BASE64**
   ```bash
   # 将 keystore 文件转为 base64
   base64 android/app/keystore/muchen-wallet.keystore | pbcopy
   ```
   将复制的内容添加到 GitHub Secrets

2. **ANDROID_KEY_ALIAS**
   ```
   muchen-wallet-key
   ```

3. **ANDROID_KEY_PASSWORD**
   ```
   muchen2024
   ```

4. **ANDROID_KEYSTORE_PASSWORD**
   ```
   muchen2024
   ```

### 更新 GitHub Actions 工作流

在 `.github/workflows/build-release.yml` 的 Android 构建任务中添加:

```yaml
- name: Decode keystore
  run: |
    echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode > android/app/keystore/muchen-wallet.keystore

- name: Create key.properties
  run: |
    cat > android/key.properties << EOF
    storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
    keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
    keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
    storeFile=keystore/muchen-wallet.keystore
    EOF

- name: Build signed APK
  run: flutter build apk --release
```

---

## 📝 验证签名

### 本地验证

```bash
# 查看 APK 签名信息
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# 或使用 apksigner
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

### 检查签名匹配

```bash
# 提取 APK 的证书指纹
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk | grep SHA256

# 对比 keystore 的证书指纹
keytool -list -v -keystore android/app/keystore/muchen-wallet.keystore -storepass muchen2024 | grep SHA256
```

两者的 SHA256 指纹应该完全一致。

---

## ⚠️ 安全建议

### 密钥库备份

1. 将 `muchen-wallet.keystore` 备份到安全位置
2. 记录所有密码到密码管理器
3. 建议至少 3 个备份副本（不同位置）

### 密码安全

- ❌ 不要提交到 Git
- ❌ 不要分享给他人
- ❌ 不要使用弱密码
- ✅ 使用密码管理器
- ✅ 定期检查备份
- ✅ 限制访问权限

### 生产环境建议

当前密钥使用的是简单密码 `muchen2024`，仅供开发测试使用。

对于生产环境，建议:
1. 使用更强的密码（至少16位，包含大小写字母、数字、符号）
2. 考虑使用 Google Play App Signing
3. 定期轮换密钥（如果使用 App Signing）

---

## 🔄 重新生成签名（如需要）

如果需要重新生成签名文件:

```bash
# 删除旧的密钥库
rm android/app/keystore/muchen-wallet.keystore

# 生成新的密钥库
keytool -genkey -v \
  -storetype PKCS12 \
  -keystore android/app/keystore/muchen-wallet.keystore \
  -alias muchen-wallet-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass 你的密码 \
  -keypass 你的密码 \
  -dname "CN=你的姓名, OU=组织单位, O=组织, L=城市, ST=省份, C=国家代码"
```

⚠️ **注意**: 更换签名密钥后，用户将无法直接升级应用，需要卸载重装。

---

## 📱 应用发布

### Google Play Store

1. 上传 APK 到 Google Play Console
2. Google 会验证签名
3. 建议使用 Google Play App Signing

### 其他渠道

- 可以直接分发签名的 APK
- 用户需要启用"未知来源"安装
- 确保通过安全渠道分发

---

## 🆘 常见问题

### Q: 忘记密码怎么办？
A: 密钥库密码无法恢复，只能重新生成新的密钥库。但这意味着用户需要卸载重装应用。

### Q: 可以更改密码吗？
A: 可以，使用 keytool 命令可以修改密码:
```bash
keytool -storepasswd -keystore android/app/keystore/muchen-wallet.keystore
keytool -keypasswd -alias muchen-wallet-key -keystore android/app/keystore/muchen-wallet.keystore
```

### Q: 签名文件可以共享吗？
A: 不建议。每个开发者应该有自己的签名密钥。生产环境使用专用的、严格保管的密钥。

### Q: 如何验证 APK 是否正确签名？
A: 使用 `jarsigner -verify` 或 `apksigner verify` 命令验证。

---

## 📚 相关资源

- [Android 应用签名官方文档](https://developer.android.com/studio/publish/app-signing)
- [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Flutter 应用签名文档](https://docs.flutter.dev/deployment/android#signing-the-app)

---

**文档生成时间**: 2026-06-13  
**密钥库生成时间**: 2026-06-13  
**密钥有效期至**: 2053-10-29

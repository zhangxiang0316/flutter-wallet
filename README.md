# omnicast

## 路由生成

```agsl
flutter pub run build_runner build
```


## IOS 打包 ipa

ios生成logo
```
flutter pub get
flutter pub run flutter_launcher_icons:main
```

```
flutter clean
flutter build ipa --release
```


## android 打包
```agsl
flutter build apk --release
```

升级包
flutter pub upgrade flutter_quill






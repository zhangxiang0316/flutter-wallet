# Flutter 主题颜色使用指南

## 📋 颜色分类说明

### 1. 页面级颜色
```dart
scaffoldBackgroundColor  // 整个页面的背景色
```
- **亮色模式**: `Color(0xFFF5F5F5)` - 浅灰色
- **暗色模式**: `Color(0xFF121212)` - 深黑色
- **使用场景**: 整个页面的底色

### 2. ColorScheme 颜色系统

#### Primary（主色调）
```dart
primary          // 主色调
onPrimary        // 主色调上的文字/图标颜色
```
- **亮色模式**: `Colors.blue` / `Colors.white`
- **暗色模式**: `Colors.blueAccent` / `Colors.black`
- **使用场景**: 
  - 主要按钮
  - 底部导航栏选中项
  - FloatingActionButton
  - 进度条
  - 开关选中状态

#### Secondary（次要色）
```dart
secondary        // 次要色
onSecondary      // 次要色上的文字/图标颜色
```
- **亮色模式**: `Colors.blueAccent` / `Colors.white`
- **暗色模式**: `Colors.blue` / `Colors.black`
- **使用场景**: 
  - 次要按钮
  - Chip
  - 辅助性 UI 元素

#### Surface（表面色）
```dart
surface          // 表面颜色
onSurface        // 表面上的文字/图标颜色
```
- **亮色模式**: `Colors.white` / `Colors.black87`
- **暗色模式**: `Color(0xFF1E1E1E)` / `Colors.white70`
- **使用场景**: 
  - Card 卡片
  - Dialog 对话框
  - BottomSheet
  - Menu 菜单
  - 普通文字颜色

#### Error（错误色）
```dart
error            // 错误颜色
onError          // 错误颜色上的文字颜色
```
- **亮色模式**: `Colors.red` / `Colors.white`
- **暗色模式**: `Colors.redAccent` / `Colors.black`
- **使用场景**: 
  - 错误提示
  - 表单验证错误
  - 删除按钮

### 3. 组件专用颜色

#### Card（卡片）
```dart
cardColor        // 卡片背景色
```
- **亮色模式**: `Colors.white`
- **暗色模式**: `Color(0xFF1E1E1E)`

#### BottomNavigationBar（底部导航栏）
```dart
backgroundColor       // 背景色
selectedItemColor     // 选中项颜色
unselectedItemColor   // 未选中项颜色
```

#### AppBar（顶部栏）
```dart
backgroundColor       // 背景色
foregroundColor       // 前景色（文字/图标）
```

---

## 🎨 如何使用这些颜色

### 在代码中获取主题颜色

```dart
// 获取主题
final theme = Theme.of(context);

// 页面背景色
theme.scaffoldBackgroundColor

// 主色调
theme.colorScheme.primary

// 表面色（卡片、对话框）
theme.colorScheme.surface

// 文字颜色
theme.colorScheme.onSurface

// 卡片背景色
theme.cardColor
```

### 常见使用示例

#### 1. 设置容器背景色
```dart
Container(
  color: Theme.of(context).colorScheme.surface,  // 使用表面色
  child: Text(
    'Hello',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,  // 表面上的文字色
    ),
  ),
)
```

#### 2. 按钮颜色
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Theme.of(context).colorScheme.primary,  // 主色调
    foregroundColor: Theme.of(context).colorScheme.onPrimary,  // 主色调上的文字
  ),
  onPressed: () {},
  child: Text('按钮'),
)
```

#### 3. 卡片
```dart
Card(
  color: Theme.of(context).cardColor,  // 自动适配亮色/暗色
  child: ListTile(
    title: Text('标题'),
  ),
)
```

---

## 🔧 如何修改颜色

### 修改主色调（品牌色）
在 `lib/main.dart` 中修改：
```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: Colors.blue,  // 改成你想要的颜色，如 Colors.green
  primary: Colors.blue,    // 或直接指定主色
)
```

### 修改页面背景色
```dart
scaffoldBackgroundColor: const Color(0xFFF5F5F5),  // 改成你想要的颜色
```

### 修改底部导航栏颜色
```dart
bottomNavigationBarTheme: const BottomNavigationBarThemeData(
  backgroundColor: Colors.white,        // 背景色
  selectedItemColor: Colors.blue,       // 选中颜色
  unselectedItemColor: Colors.grey,     // 未选中颜色
),
```

---

## 💡 推荐配色方案

### 方案 1: 蓝色系（当前）
- 主色: `Colors.blue`
- 页面背景: `Color(0xFFF5F5F5)` 浅灰
- 卡片背景: `Colors.white`

### 方案 2: 绿色系
```dart
primary: Colors.green,
secondary: Colors.lightGreen,
```

### 方案 3: 紫色系
```dart
primary: Colors.deepPurple,
secondary: Colors.purpleAccent,
```

### 方案 4: 橙色系
```dart
primary: Colors.deepOrange,
secondary: Colors.orangeAccent,
```

---

## ⚠️ 注意事项

1. **保持对比度**: 确保文字和背景有足够的对比度
2. **统一使用主题**: 不要硬编码颜色，始终使用 `Theme.of(context)`
3. **测试两种模式**: 修改后要在亮色和暗色模式下都测试
4. **语义化使用**: 
   - 主要操作用 `primary`
   - 次要操作用 `secondary`
   - 错误/删除用 `error`


---

## 🎯 ThemeExtension 自定义主题扩展

### 什么是 ThemeExtension？

`ThemeExtension` 允许你在 Flutter 标准主题之外，添加自己的自定义颜色和样式。这对于需要额外颜色（如成功色、警告色等）的应用非常有用。

### 已实现的自定义颜色

在 `lib/common/theme/app_theme_extension.dart` 中定义了以下自定义颜色：

| 颜色名称 | 用途 | 亮色模式 | 暗色模式 |
|---------|------|---------|---------|
| `successColor` | 成功提示 | 绿色 `#4CAF50` | 浅绿 `#66BB6A` |
| `warningColor` | 警告提示 | 橙色 `#FF9800` | 浅橙 `#FFB74D` |
| `infoColor` | 信息提示 | 蓝色 `#2196F3` | 浅蓝 `#42A5F5` |
| `dividerColor` | 分割线 | 浅灰 `#E0E0E0` | 深灰 `#424242` |
| `shadowColor` | 阴影 | 10% 黑色 | 20% 黑色 |
| `shimmerBaseColor` | 骨架屏基础色 | `#E0E0E0` | `#424242` |
| `shimmerHighlightColor` | 骨架屏高亮色 | `#F5F5F5` | `#616161` |
| `inputBackgroundColor` | 输入框背景 | `#FAFAFA` | `#2C2C2C` |
| `inputBorderColor` | 输入框边框 | `#E0E0E0` | `#424242` |
| `tagBackgroundColor` | 标签背景 | 浅蓝 `#E3F2FD` | 深蓝 `#1E3A5F` |
| `tagTextColor` | 标签文字 | 深蓝 `#1976D2` | 浅蓝 `#64B5F6` |
| `bottomNavBarColor` | 底部导航栏 | 白色 | `#1E1E1E` |
| `cardShadowColor` | 卡片阴影 | 5% 黑色 | 10% 黑色 |

### 如何使用 ThemeExtension

#### 方式1: 使用扩展方法（推荐）

```dart
import 'package:omnicast/common/theme/app_theme_extension.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 直接通过 context 获取
    final appTheme = context.appTheme;
    
    return Container(
      color: appTheme.successColor,  // 使用成功色
      child: Text('成功'),
    );
  }
}
```

#### 方式2: 直接获取

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).extension<AppThemeExtension>()!;
    
    return Container(
      color: appTheme.warningColor,  // 使用警告色
      child: Text('警告'),
    );
  }
}
```

### 实际使用示例

#### 1. 成功/警告/错误提示

```dart
// 成功提示
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: context.appTheme.successColor?.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      Icon(Icons.check_circle, color: context.appTheme.successColor),
      SizedBox(width: 8),
      Text('操作成功', style: TextStyle(color: context.appTheme.successColor)),
    ],
  ),
)

// 警告提示
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: context.appTheme.warningColor?.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      Icon(Icons.warning, color: context.appTheme.warningColor),
      SizedBox(width: 8),
      Text('请注意', style: TextStyle(color: context.appTheme.warningColor)),
    ],
  ),
)
```

#### 2. 自定义输入框

```dart
TextField(
  decoration: InputDecoration(
    hintText: '请输入',
    filled: true,
    fillColor: context.appTheme.inputBackgroundColor,
    border: OutlineInputBorder(
      borderSide: BorderSide(color: context.appTheme.inputBorderColor!),
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)
```

#### 3. 标签组件

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: context.appTheme.tagBackgroundColor,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Text(
    'Flutter',
    style: TextStyle(color: context.appTheme.tagTextColor),
  ),
)
```

#### 4. 分割线

```dart
Divider(
  color: context.appTheme.dividerColor,
  thickness: 1,
)
```

#### 5. 带阴影的卡片

```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: context.appTheme.cardShadowColor!,
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: Text('卡片内容'),
)
```

### 如何添加新的自定义颜色

1. 在 `lib/common/theme/app_theme_extension.dart` 中添加新字段：

```dart
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color? myCustomColor;  // 添加新颜色
  
  const AppThemeExtension({
    // ... 其他颜色
    this.myCustomColor,
  });
  
  static AppThemeExtension light() {
    return const AppThemeExtension(
      // ... 其他颜色
      myCustomColor: Colors.purple,  // 亮色模式的值
    );
  }
  
  static AppThemeExtension dark() {
    return const AppThemeExtension(
      // ... 其他颜色
      myCustomColor: Colors.purpleAccent,  // 暗色模式的值
    );
  }
  
  @override
  ThemeExtension<AppThemeExtension> copyWith({
    // ... 其他颜色
    Color? myCustomColor,
  }) {
    return AppThemeExtension(
      // ... 其他颜色
      myCustomColor: myCustomColor ?? this.myCustomColor,
    );
  }
  
  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      // ... 其他颜色
      myCustomColor: Color.lerp(myCustomColor, other.myCustomColor, t),
    );
  }
}
```

2. 在代码中使用：

```dart
Container(
  color: context.appTheme.myCustomColor,
  child: Text('自定义颜色'),
)
```

### 查看完整示例

运行 `lib/page/theme_example_page.dart` 查看所有自定义颜色的使用示例。

### 优势

1. **类型安全**: 编译时检查，避免拼写错误
2. **自动适配**: 亮色/暗色模式自动切换
3. **集中管理**: 所有自定义颜色在一个地方定义
4. **易于维护**: 修改颜色只需改一处
5. **平滑过渡**: `lerp` 方法支持主题切换动画

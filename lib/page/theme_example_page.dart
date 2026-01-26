import 'package:flutter/material.dart';
import 'package:omnicast/common/theme/app_theme_extension.dart';

/// ThemeExtension 使用示例页面
class ThemeExamplePage extends StatelessWidget {
  const ThemeExamplePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 方式1: 使用扩展方法（推荐）
    final appTheme = context.appTheme;

    // 方式2: 直接获取
    // final appTheme = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题扩展示例'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 成功提示
            _buildCard(
              context,
              title: '成功提示',
              color: appTheme.successColor!,
              icon: Icons.check_circle,
            ),
            const SizedBox(height: 16),

            // 警告提示
            _buildCard(
              context,
              title: '警告提示',
              color: appTheme.warningColor!,
              icon: Icons.warning,
            ),
            const SizedBox(height: 16),

            // 信息提示
            _buildCard(
              context,
              title: '信息提示',
              color: appTheme.infoColor!,
              icon: Icons.info,
            ),
            const SizedBox(height: 16),

            // 分割线示例
            const Text('分割线示例：'),
            const SizedBox(height: 8),
            Divider(color: appTheme.dividerColor, thickness: 1),
            const SizedBox(height: 16),

            // 输入框示例
            const Text('输入框示例：'),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: '请输入内容',
                filled: true,
                fillColor: appTheme.inputBackgroundColor,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: appTheme.inputBorderColor!),
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: appTheme.inputBorderColor!),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标签示例
            const Text('标签示例：'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildTag(context, 'Flutter'),
                _buildTag(context, 'Dart'),
                _buildTag(context, 'GetX'),
              ],
            ),
            const SizedBox(height: 16),

            // 卡片阴影示例
            const Text('卡片阴影示例：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: appTheme.cardShadowColor!,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text('这是一个带阴影的卡片'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    final appTheme = context.appTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.tagBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: appTheme.tagTextColor,
          fontSize: 14,
        ),
      ),
    );
  }
}

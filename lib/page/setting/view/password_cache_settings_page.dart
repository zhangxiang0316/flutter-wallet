import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../generated/l10n.dart';
import '../../../utils/password_cache_service.dart';
import '../../../utils/toast_util.dart';

/// 密码缓存设置页面。
///
/// 允许用户配置密码缓存功能：
/// - 开启/关闭密码缓存
/// - 选择缓存过期时间（1/5/10/30分钟）
class PasswordCacheSettingsPage extends StatefulWidget {
  const PasswordCacheSettingsPage({super.key});

  @override
  State<PasswordCacheSettingsPage> createState() =>
      _PasswordCacheSettingsPageState();
}

class _PasswordCacheSettingsPageState extends State<PasswordCacheSettingsPage> {
  bool _isEnabled = true;
  int _expiryMinutes = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await PasswordCacheService.isEnabled();
    final expiry = await PasswordCacheService.getExpiryMinutes();
    setState(() {
      _isEnabled = enabled;
      _expiryMinutes = expiry;
      _isLoading = false;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    await PasswordCacheService.setEnabled(value);
    setState(() => _isEnabled = value);
    Toast.show(value
        ? S.of(context).passwordCacheEnabled
        : S.of(context).passwordCacheDisabled);
  }

  Future<void> _setExpiryMinutes(int minutes) async {
    await PasswordCacheService.setExpiryMinutes(minutes);
    setState(() => _expiryMinutes = minutes);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).securitySettings),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).securitySettings),
      ),
      body: ListView(
        children: [
          // 密码缓存开关
          SwitchListTile(
            title: Text(
              S.of(context).passwordCache,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              S.of(context).passwordCacheDesc,
              style: TextStyle(
                fontSize: 13.sp,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            value: _isEnabled,
            onChanged: _toggleEnabled,
          ),

          const Divider(height: 1),

          // 过期时间选项
          if (_isEnabled) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
              child: Text(
                S.of(context).passwordCacheExpiry,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            _ExpiryOption(
              title: S.of(context).passwordCacheExpiry1,
              minutes: 1,
              selected: _expiryMinutes == 1,
              onTap: () => _setExpiryMinutes(1),
            ),
            _ExpiryOption(
              title: S.of(context).passwordCacheExpiry5,
              minutes: 5,
              selected: _expiryMinutes == 5,
              onTap: () => _setExpiryMinutes(5),
            ),
            _ExpiryOption(
              title: S.of(context).passwordCacheExpiry10,
              minutes: 10,
              selected: _expiryMinutes == 10,
              onTap: () => _setExpiryMinutes(10),
            ),
            _ExpiryOption(
              title: S.of(context).passwordCacheExpiry30,
              minutes: 30,
              selected: _expiryMinutes == 30,
              onTap: () => _setExpiryMinutes(30),
            ),
          ],

          // 说明文字
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              '生物识别成功后，将在${_expiryMinutes}分钟内自动使用缓存的密码解锁，无需重复输入。\n\n'
              '• 密码仅保存在内存中\n'
              '• 应用退出后自动清除\n'
              '• 超过设定时间自动过期',
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 过期时间选项。
class _ExpiryOption extends StatelessWidget {
  const _ExpiryOption({
    required this.title,
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<bool>(
      title: Text(
        title,
        style: TextStyle(fontSize: 15.sp),
      ),
      value: true,
      groupValue: selected,
      onChanged: (_) => onTap(),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}

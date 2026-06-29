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
    if (!mounted) return;
    setState(() {
      _isEnabled = enabled;
      _expiryMinutes = expiry;
      _isLoading = false;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    await PasswordCacheService.setEnabled(value);
    if (!mounted) return;
    setState(() => _isEnabled = value);
    Toast.show(
      value
          ? S.of(context).passwordCacheEnabled
          : S.of(context).passwordCacheDisabled,
    );
  }

  Future<void> _setExpiryMinutes(int minutes) async {
    await PasswordCacheService.setExpiryMinutes(minutes);
    setState(() => _expiryMinutes = minutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageColor = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF7F8FA);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context).securitySettings)),
        backgroundColor: pageColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 50.h,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
          onPressed: Get.back,
        ),
        centerTitle: true,
        title: Text(S.of(context).securitySettings),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _CellGroup(
            children: [
              _SwitchCell(
                title: S.of(context).passwordCache,
                subtitle: S.of(context).passwordCacheDesc,
                value: _isEnabled,
                onChanged: _toggleEnabled,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _isEnabled
                ? _CellGroup(
                    key: const ValueKey('expiry-options'),
                    title: S.of(context).passwordCacheExpiry,
                    children: [
                      _ExpiryOption(
                        title: S.of(context).passwordCacheExpiry1,
                        selected: _expiryMinutes == 1,
                        onTap: () => _setExpiryMinutes(1),
                      ),
                      _ExpiryOption(
                        title: S.of(context).passwordCacheExpiry5,
                        selected: _expiryMinutes == 5,
                        onTap: () => _setExpiryMinutes(5),
                      ),
                      _ExpiryOption(
                        title: S.of(context).passwordCacheExpiry10,
                        selected: _expiryMinutes == 10,
                        onTap: () => _setExpiryMinutes(10),
                      ),
                      _ExpiryOption(
                        title: S.of(context).passwordCacheExpiry30,
                        selected: _expiryMinutes == 30,
                        onTap: () => _setExpiryMinutes(30),
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('expiry-hidden')),
          ),
          SizedBox(height: 12.h),
          _CellGroup(
            title: S.of(context).passwordCacheSecurityNoteTitle,
            children: [
              _NoteCell(text: S.of(context).passwordCacheMemoryOnly),
              _NoteCell(text: S.of(context).passwordCacheClearedOnExit),
              _NoteCell(text: S.of(context).passwordCacheExpiresAutomatically),
            ],
          ),
        ],
      ),
    );
  }
}

class _CellGroup extends StatelessWidget {
  const _CellGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 7.h),
            child: Text(
              title!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(height: 1, indent: 16.w, color: borderColor),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchCell extends StatelessWidget {
  const _SwitchCell({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.35,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            Transform.scale(
              scale: 0.86,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: theme.colorScheme.primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.18,
                ),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCell extends StatelessWidget {
  const _NoteCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 13.w,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.35,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
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
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: selected
                      ? selectedColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.84),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Icon(
                Icons.check_rounded,
                size: 20.w,
                color: selectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

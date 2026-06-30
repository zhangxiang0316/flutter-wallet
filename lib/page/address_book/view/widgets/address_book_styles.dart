import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 地址簿页面统一的卡片装饰样式。
BoxDecoration panelDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
  );
}

/// 将完整钱包地址缩略为前 10 + 后 6 位的可读形式。
String shortAddress(String address) {
  if (address.length <= 18) return address;
  return '${address.substring(0, 10)}...${address.substring(address.length - 6)}';
}

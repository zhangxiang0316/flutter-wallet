import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 增强的提示工具类。
///
/// 提供多种类型的提示：
/// - 成功提示（绿色）
/// - 错误提示（红色）
/// - 警告提示（橙色）
/// - 信息提示（蓝色）
/// - 带操作按钮的提示
class EnhancedToast {
  /// 显示成功提示。
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFF4CAF50),
      icon: Icons.check_circle,
      duration: duration,
    );
  }

  /// 显示错误提示。
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onRetry,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFFF44336),
      icon: Icons.error,
      duration: duration,
      actionLabel: onRetry != null ? '重试' : null,
      onAction: onRetry,
    );
  }

  /// 显示警告提示。
  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFFFF9800),
      icon: Icons.warning,
      duration: duration,
    );
  }

  /// 显示信息提示。
  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: const Color(0xFF2196F3),
      icon: Icons.info,
      duration: duration,
    );
  }

  /// 显示网络错误提示（带重试按钮）。
  static void networkError(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    error(
      context,
      message ?? '网络连接失败，请检查网络设置',
      duration: const Duration(seconds: 4),
      onRetry: onRetry,
    );
  }

  /// 显示验证错误提示。
  static void validationError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    warning(
      context,
      message,
      duration: duration,
    );
  }

  /// 显示系统错误提示。
  static void systemError(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    error(
      context,
      message ?? '系统错误，请稍后重试',
      duration: const Duration(seconds: 4),
      onRetry: onRetry,
    );
  }

  /// 显示自定义 SnackBar。
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// 显示带自定义操作的提示。
  static void custom(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// 错误类型枚举。
enum ErrorType {
  network,
  validation,
  system,
  unknown,
}

/// 错误分类器。
class ErrorClassifier {
  /// 根据错误信息分类错误类型。
  static ErrorType classify(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // 网络错误
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('socket') ||
        errorStr.contains('failed host lookup')) {
      return ErrorType.network;
    }

    // 验证错误
    if (errorStr.contains('invalid') ||
        errorStr.contains('validation') ||
        errorStr.contains('format') ||
        errorStr.contains('required')) {
      return ErrorType.validation;
    }

    // 系统错误
    if (errorStr.contains('exception') ||
        errorStr.contains('error') ||
        errorStr.contains('failed')) {
      return ErrorType.system;
    }

    return ErrorType.unknown;
  }

  /// 获取友好的错误提示文本。
  static String getFriendlyMessage(dynamic error, {String? fallback}) {
    final type = classify(error);

    switch (type) {
      case ErrorType.network:
        return '网络连接失败，请检查网络设置';
      case ErrorType.validation:
        return '输入信息有误，请检查后重试';
      case ErrorType.system:
        return '操作失败，请稍后重试';
      case ErrorType.unknown:
        return fallback ?? '未知错误，请稍后重试';
    }
  }

  /// 显示分类后的错误提示。
  static void showError(
    BuildContext context,
    dynamic error, {
    String? fallback,
    VoidCallback? onRetry,
  }) {
    final type = classify(error);
    final message = getFriendlyMessage(error, fallback: fallback);

    switch (type) {
      case ErrorType.network:
        EnhancedToast.networkError(
          context,
          message: message,
          onRetry: onRetry,
        );
        break;
      case ErrorType.validation:
        EnhancedToast.validationError(context, message);
        break;
      case ErrorType.system:
      case ErrorType.unknown:
        EnhancedToast.systemError(
          context,
          message: message,
          onRetry: onRetry,
        );
        break;
    }
  }
}

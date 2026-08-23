import 'dart:developer' as developer;

/// 日志脱敏工具。
///
/// 日志可能被 IDE、崩溃收集器或浏览器控制台持久化，默认不允许把请求凭据、钱包
/// 地址或私钥样式的字符串写入日志。业务日志只应记录脱敏后的错误摘要。
abstract final class SafeLog {
  static final RegExp _querySecret = RegExp(
    r'((?:api[-_]?key|apikey|access[_-]?token|authorization|password|secret|private[_-]?key)[=:]\s*)([^\s&,;}]+)',
    caseSensitive: false,
  );
  static final RegExp _hexAddress = RegExp(r'0x[a-fA-F0-9]{40}');
  static final RegExp _privateKey = RegExp(
    r'(?<![a-fA-F0-9])[a-fA-F0-9]{64}(?![a-fA-F0-9])',
  );

  /// 将异常或文本转换为可安全写入日志的摘要。
  static String sanitize(Object? value) {
    if (value == null) return '';
    var text = value.toString();
    text = text.replaceAllMapped(_querySecret, (match) {
      return '${match.group(1)}[REDACTED]';
    });
    text = text.replaceAllMapped(_privateKey, (_) => '[REDACTED_HEX]');
    text = text.replaceAllMapped(_hexAddress, (match) {
      final address = match.group(0)!;
      return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
    });
    return text;
  }

  /// 统一记录脱敏后的错误，避免直接把 Dio 异常（可能含 query API key）传给日志。
  static void error(
    String message, {
    required String name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      sanitize(message),
      name: name,
      error: error == null ? null : sanitize(error),
      stackTrace: stackTrace,
    );
  }
}

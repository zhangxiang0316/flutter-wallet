import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../utils/log_util.dart';
import '../../utils/storage.dart';
import 'dio_response.dart';

/// Dio拦截器
class DioInterceptor extends InterceptorsWrapper {
  /// 请求发起前，调用的方法
  /// 可以在这里动态修改Header里信息，从options里获取原来的Header信息，进行修改
  /// 常见的场景有：弹出加载loading、添加Token
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    late var intlLocalization = Intl.defaultLocale; // 获取当前语言环境
    options.headers['token'] = await Storage().getString('token') ?? '';
    options.headers['Accept-Language'] = intlLocalization;

    _logRequest(options);

    /// 必须要写的代码，表示进入下一步
    handler.next(options);
  }

  /// 请求成功后，执行的响应方法
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logResponse(response);

    if (response.statusCode == 200) {
      /// 有返回值的情况，转实体
      if (response.data is Map) {
        ResponseData responseData = ResponseData.fromJson(response.data);

        /// 成功
        if (responseData.success) {
          response.statusCode = responseData.statusCode;
          response.data = responseData.data;
        } else if (responseData.statusCode == 401) {
          // NavigatorUtil.push(navigatorKey.currentContext!, Routers.login);
        } else {
          /// 走到这，说明访问成功，但业务不允许，比如没有权限
          response.statusCode = responseData.statusCode;
          response.statusMessage = responseData.statusMessage;
          // Fluttertoast.showToast(
          //   msg: response.statusMessage ?? "服务异常",
          //   toastLength: Toast.LENGTH_SHORT,
          //   gravity: ToastGravity.CENTER,
          // );
          // EasyLoading.dismiss();
          final error = DioException(
            requestOptions: RequestOptions(),
            error: responseData.statusMessage,
            response: response,
            type: DioExceptionType.badResponse,
          );
          return handler.reject(error);
        }
      }
    }

    /// 必须要写的代码，表示进入下一步
    return handler.resolve(response);
  }

  /// 这里的异常，属于Dio自身的异常
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logError(err);
    handler.next(err);
  }

  void _logRequest(RequestOptions options) {
    if (!isDebug) return;
    logD({
      'type': 'http_request',
      'method': options.method,
      'uri': _safeUri(options),
      'headers': _sanitizeValue(options.headers),
      'data': _sanitizeValue(options.data),
    });
  }

  void _logResponse(Response<dynamic> response) {
    if (!isDebug) return;
    logD({
      'type': 'http_response',
      'method': response.requestOptions.method,
      'uri': _safeUri(response.requestOptions),
      'statusCode': response.statusCode,
      'data': _summarizeResponseData(response.data),
    });
  }

  void _logError(DioException error) {
    if (!isDebug) return;
    logW({
      'type': 'http_error',
      'method': error.requestOptions.method,
      'uri': _safeUri(error.requestOptions),
      'errorType': error.type.name,
      'statusCode': error.response?.statusCode,
      'message': _sanitizeText(error.message ?? error.error?.toString() ?? ''),
    });
  }

  String _safeUri(RequestOptions options) {
    final uri = options.uri;
    final sanitizedQuery = _sanitizeValue(uri.queryParameters);
    if (sanitizedQuery is! Map || sanitizedQuery.isEmpty) {
      return uri.replace(query: '').toString();
    }
    return uri
        .replace(
          queryParameters: sanitizedQuery.map(
            (key, value) => MapEntry(key.toString(), value?.toString()),
          ),
        )
        .toString();
  }

  Object? _summarizeResponseData(Object? data) {
    final sanitized = _sanitizeValue(data);
    if (sanitized is Map) {
      return {
        'type': 'map',
        'keys': sanitized.keys.take(12).toList(),
        'size': sanitized.length,
      };
    }
    if (sanitized is List) {
      return {'type': 'list', 'size': sanitized.length};
    }
    if (sanitized is String) {
      return _truncate(sanitized, 160);
    }
    return sanitized;
  }

  Object? _sanitizeValue(Object? value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map((key, nestedValue) {
        final keyText = key.toString();
        return MapEntry(
          keyText,
          _isSensitiveKey(keyText) ? '***' : _sanitizeValue(nestedValue),
        );
      });
    }
    if (value is Iterable) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    if (value is String) {
      return _sanitizeText(value);
    }
    return value;
  }

  bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('apikey') ||
        normalized.contains('api_key') ||
        normalized.contains('api-key') ||
        normalized.contains('authorization') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('private') ||
        normalized.contains('signature') ||
        normalized.contains('signed') ||
        normalized == 'key';
  }

  String _sanitizeText(String value) {
    var sanitized = value;
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'0x[a-fA-F0-9]{32,}'),
      _maskMatchedValue,
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\bT[1-9A-HJ-NP-Za-km-z]{25,}\b'),
      _maskMatchedValue,
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b[A-HJ-NP-Za-km-z1-9]{32,44}\b'),
      _maskMatchedValue,
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b'),
      '***',
    );
    return _truncate(sanitized, 500);
  }

  String _maskMatchedValue(Match match) {
    final value = match.group(0) ?? '';
    if (value.length <= 12) return '***';
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }
}

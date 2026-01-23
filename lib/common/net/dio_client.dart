import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dio_interceptor.dart';

/// 默认超时时间
const defaultTimeout = 60 * 1000;
const baseUrl = "";

class DioClient extends DioForNative {
  /// 单例
  static DioClient? _instance;

  factory DioClient() => _instance ??= DioClient._init();

  /// 初始化方法
  DioClient._init() {
    options = BaseOptions(
      // 设置基础配置
      connectTimeout: Duration(milliseconds: defaultTimeout), // 连接超时时间
      receiveTimeout: Duration(milliseconds: defaultTimeout), // 接收超时时间
      sendTimeout: Duration(milliseconds: defaultTimeout), // 发送超时时间
      baseUrl: baseUrl,
    );
    // 拦截器
    interceptors.add(DioInterceptor()); // 拦截器
  }

  /// Get请求
  Future<Response> doGet(
    path, {
    String? baseUrl,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    Object? data,
    Map<String, dynamic>? params,
    Options? cOptions,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    updateBaseOptions(baseUrl, headers, responseType); // 动态修改默认BaseOptions
    options.contentType = Headers.jsonContentType;
    return get(
      path,
      data: data,
      queryParameters: params,
      options: cOptions,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  /// Post 请求
  Future<Response> doPost(
    path, {
    String? baseUrl,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    Object? data,
    Map<String, dynamic>? params,
    Options? cOptions,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    updateBaseOptions(baseUrl, headers, responseType); // 动态修改默认BaseOptions
    options.contentType = Headers.jsonContentType;
    return post(
      path,
      data: data,
      queryParameters: params,
      options: cOptions,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Put 请求
  Future<Response> doPut(
    path, {
    String? baseUrl,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    Object? data,
    Map<String, dynamic>? params,
    Options? cOptions,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    updateBaseOptions(baseUrl, headers, responseType); // 动态修改默认BaseOptions
    return put(
      path,
      data: data,
      queryParameters: params,
      options: cOptions,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Patch 请求
  Future<Response> doPatch(
    path, {
    String? baseUrl,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    Object? data,
    Map<String, dynamic>? params,
    Options? cOptions,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    updateBaseOptions(baseUrl, headers, responseType); // 动态修改默认BaseOptions
    return path(
      path,
      listData: data,
      queryParameters: params,
      options: cOptions,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Delete 请求
  Future<Response> doDelete(
    path, {
    String? baseUrl,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    Object? data,
    Map<String, dynamic>? params,
    Options? cOptions,
    CancelToken? cancelToken,
  }) {
    updateBaseOptions(baseUrl, headers, responseType); // 动态修改默认BaseOptions
    return delete(
      path,
      data: data,
      queryParameters: params,
      options: cOptions,
      cancelToken: cancelToken,
    );
  }

  /// 上传文件
  Future<Response> uploadFile(
    path, {
    String? baseUrl,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    Object? data,
    Map<String, dynamic>? params,
    Options? cOptions,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    updateBaseOptions(baseUrl, headers, responseType); // 动态修改默认BaseOptions
    options.contentType = Headers.multipartFormDataContentType;
    return post(
      path,
      data: data,
      queryParameters: params,
      options: cOptions,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 动态修改 BaseOptions
  void updateBaseOptions(
    String? baseUrl,
    Map<String, dynamic>? headers,
    ResponseType responseType,
  ) {
    if (baseUrl != null) {
      options.baseUrl = baseUrl;
    }
    if (headers != null) {
      options.headers = headers;
    }
    if (responseType != ResponseType.json) {
      options.responseType = responseType;
    }
  }
}

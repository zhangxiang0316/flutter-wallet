import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/storage.dart';
import 'dio_response.dart';

final DateTime dateTime = DateTime.now();

/// Dio拦截器
class DioInterceptor extends InterceptorsWrapper {
  /// 请求发起前，调用的方法
  /// 可以在这里动态修改Header里信息，从options里获取原来的Header信息，进行修改
  /// 常见的场景有：弹出加载loading、添加Token
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    late var intlLocalization = Intl.defaultLocale; // 获取当前语言环境
    options.headers['token'] = await Storage().getStorage('token');
    options.headers['Accept-Language'] = intlLocalization;
    // 打印请求日志信息
    assert(() {
      debugPrint(
          'method:${options.method} Language:${options.headers['Accept-Language']} request：${options.baseUrl + options.path}');
      debugPrint('data：${options.method == "POST" ? options.data : options.queryParameters}');
      return true;
    }());
    /// 必须要写的代码，表示进入下一步
    handler.next(options);
  }

  /// 请求成功后，执行的响应方法
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // 打印响应日志信息

    // 打印请求日志信息
    assert(() {
        log('response：${response}');
      return true;
    }());

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
    print('err:$err}');
    // throw DioException(requestOptions: err.requestOptions, type: err.type, error: err, response: err.response);
  }
}

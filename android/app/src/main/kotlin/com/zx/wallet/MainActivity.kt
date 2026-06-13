package com.zx.wallet

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "screen_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    enableScreenSecurity()
                    result.success(null)
                }
                "disable" -> {
                    disableScreenSecurity()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * 启用截屏保护。
     *
     * 设置 FLAG_SECURE 标志，防止截屏和录屏。
     */
    private fun enableScreenSecurity() {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    /**
     * 禁用截屏保护。
     *
     * 清除 FLAG_SECURE 标志，恢复正常的截屏功能。
     */
    private fun disableScreenSecurity() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}

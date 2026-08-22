import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pointycastle/digests/sha256.dart';

/// 剪贴板读写抽象，便于验证延时清理逻辑。
abstract class ClipboardGateway {
  Future<String?> readText();

  Future<void> writeText(String text);
}

/// 系统剪贴板实现。
class SystemClipboardGateway implements ClipboardGateway {
  const SystemClipboardGateway();

  @override
  Future<String?> readText() async {
    return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  }

  @override
  Future<void> writeText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}

/// 敏感剪贴板服务。
///
/// 复制私钥或助记词后定时检查剪贴板内容。只有内容仍与本次复制值一致时才清空，
/// 避免覆盖用户随后从其它应用复制的新内容。定时器仅保留摘要，不额外保留明文。
class SensitiveClipboard {
  SensitiveClipboard({ClipboardGateway? gateway})
    : _gateway = gateway ?? const SystemClipboardGateway();

  static final SensitiveClipboard instance = SensitiveClipboard();

  static const Duration defaultClearDelay = Duration(seconds: 60);

  final ClipboardGateway _gateway;
  Timer? _clearTimer;
  int _copyGeneration = 0;

  /// 复制敏感文本，并安排一次条件清理。
  Future<void> copy(
    String text, {
    Duration clearAfter = defaultClearDelay,
  }) async {
    _clearTimer?.cancel();
    final generation = ++_copyGeneration;
    await _gateway.writeText(text);
    final expectedDigest = _digest(text);
    _clearTimer = Timer(clearAfter, () {
      unawaited(_clearIfUnchanged(expectedDigest, generation));
    });
  }

  /// 取消尚未执行的清理任务。
  void cancelScheduledClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _copyGeneration++;
  }

  Future<void> _clearIfUnchanged(
    Uint8List expectedDigest,
    int generation,
  ) async {
    try {
      if (generation != _copyGeneration) return;
      final currentText = await _gateway.readText();
      if (generation != _copyGeneration || currentText == null) return;
      if (!_constantTimeEquals(_digest(currentText), expectedDigest)) return;
      await _gateway.writeText('');
      if (generation == _copyGeneration) {
        _clearTimer = null;
      }
    } on PlatformException {
      // 剪贴板可能在应用进入后台后暂时不可读，不让定时清理异常影响应用。
    }
  }

  Uint8List _digest(String value) {
    return SHA256Digest().process(Uint8List.fromList(utf8.encode(value)));
  }

  bool _constantTimeEquals(Uint8List first, Uint8List second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

/// WebView 对导航请求的处理方式。
enum BlockExplorerNavigationDisposition {
  /// 在当前 WebView 中继续加载。
  navigate,

  /// 阻止 WebView 加载，并交给系统浏览器。
  openExternally,

  /// 直接阻止导航。
  block,
}

/// WebView 阻止导航的原因。
enum BlockExplorerNavigationBlockReason {
  /// URL 无法解析，或缺少必要的 host。
  invalidUrl,

  /// URL 使用了 HTTP 或其它非 HTTPS 协议。
  nonHttps,

  /// URL 使用了可执行脚本、访问本地内容等危险协议。
  dangerousScheme,

  /// 子页面尝试加载配置域名之外的页面。
  crossOriginSubframe,
}

/// 区块浏览器导航策略的判断结果。
class BlockExplorerNavigationDecision {
  const BlockExplorerNavigationDecision._({
    required this.disposition,
    this.uri,
    this.blockReason,
  });

  /// 允许在 WebView 中继续加载。
  const BlockExplorerNavigationDecision.navigate(Uri uri)
    : this._(
        disposition: BlockExplorerNavigationDisposition.navigate,
        uri: uri,
      );

  /// 在系统浏览器中打开。
  const BlockExplorerNavigationDecision.openExternally(Uri uri)
    : this._(
        disposition: BlockExplorerNavigationDisposition.openExternally,
        uri: uri,
      );

  /// 阻止导航。
  const BlockExplorerNavigationDecision.block(
    BlockExplorerNavigationBlockReason reason,
  ) : this._(
        disposition: BlockExplorerNavigationDisposition.block,
        blockReason: reason,
      );

  /// 本次请求应采取的处理方式。
  final BlockExplorerNavigationDisposition disposition;

  /// 已通过基础安全校验的 URL。
  final Uri? uri;

  /// 导航被阻止时的原因。
  final BlockExplorerNavigationBlockReason? blockReason;
}

/// 区块浏览器 WebView 的统一 URL 安全策略。
///
/// WebView 仅允许加载初始化时配置的 HTTPS origin。跨域主页面链接可交给
/// 系统浏览器；跨域子页面和所有非 HTTPS、危险 scheme 均直接阻止。
class BlockExplorerNavigationPolicy {
  BlockExplorerNavigationPolicy._({
    required String allowedHost,
    required int allowedPort,
  }) : _allowedHost = allowedHost,
       _allowedPort = allowedPort;

  /// 根据区块浏览器配置创建策略。
  ///
  /// 配置地址自身不安全时抛出 [ArgumentError]，调用方不得创建 WebView。
  factory BlockExplorerNavigationPolicy(Uri configuredUrl) {
    if (!isSafeHttpsUri(configuredUrl)) {
      throw ArgumentError.value(
        configuredUrl,
        'configuredUrl',
        'Block explorer URL must use HTTPS and include a valid host.',
      );
    }
    return BlockExplorerNavigationPolicy._(
      allowedHost: _normalizeHost(configuredUrl.host),
      allowedPort: _effectivePort(configuredUrl),
    );
  }

  static const Set<String> _dangerousSchemes = {
    'about',
    'blob',
    'content',
    'data',
    'file',
    'intent',
    'javascript',
  };
  static final RegExp _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):');

  final String _allowedHost;
  final int _allowedPort;

  /// 判断某个请求是否可以留在 WebView、需要外部打开或必须阻止。
  BlockExplorerNavigationDecision evaluate(
    String rawUrl, {
    required bool isMainFrame,
  }) {
    final normalizedUrl = rawUrl.trim();
    final rawScheme = _schemePattern.firstMatch(normalizedUrl)?.group(1);
    if (rawScheme != null &&
        _dangerousSchemes.contains(rawScheme.toLowerCase())) {
      return const BlockExplorerNavigationDecision.block(
        BlockExplorerNavigationBlockReason.dangerousScheme,
      );
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return const BlockExplorerNavigationDecision.block(
        BlockExplorerNavigationBlockReason.invalidUrl,
      );
    }

    if (uri.host.isEmpty) {
      return const BlockExplorerNavigationDecision.block(
        BlockExplorerNavigationBlockReason.invalidUrl,
      );
    }
    if (!isSafeHttpsUri(uri)) {
      return const BlockExplorerNavigationDecision.block(
        BlockExplorerNavigationBlockReason.nonHttps,
      );
    }

    if (_isAllowedOrigin(uri)) {
      return BlockExplorerNavigationDecision.navigate(uri);
    }
    if (isMainFrame) {
      return BlockExplorerNavigationDecision.openExternally(uri);
    }
    return const BlockExplorerNavigationDecision.block(
      BlockExplorerNavigationBlockReason.crossOriginSubframe,
    );
  }

  /// 系统浏览器入口只接受具有有效 host 的 HTTPS URL。
  static bool isSafeHttpsUri(Uri uri) {
    return uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _isAllowedOrigin(Uri uri) {
    return _normalizeHost(uri.host) == _allowedHost &&
        _effectivePort(uri) == _allowedPort;
  }

  static String _normalizeHost(String host) {
    final normalized = host.toLowerCase();
    return normalized.endsWith('.')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static int _effectivePort(Uri uri) => uri.hasPort ? uri.port : 443;
}

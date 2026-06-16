import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// WalletConnect 服务 (简化版)
///
/// 提供基础的配对和会话管理功能
class WalletConnectService {
  WalletConnectService._();
  static final WalletConnectService instance = WalletConnectService._();

  bool _initialized = false;
  final List<String> _activeSessions = [];

  /// 会话提案事件流
  final _sessionProposalController = StreamController<SessionProposal>.broadcast();
  Stream<SessionProposal> get onSessionProposal => _sessionProposalController.stream;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('✅ WalletConnect Service initialized (simplified version)');
      _initialized = true;
    } catch (e) {
      debugPrint('❌ WalletConnect initialization failed: $e');
      rethrow;
    }
  }

  /// 通过 URI 配对
  Future<void> pair(String uri) async {
    if (!_initialized) {
      throw Exception('WalletConnect not initialized');
    }

    try {
      debugPrint('📨 Pairing with URI: ${uri.substring(0, 20)}...');

      // 模拟配对过程
      await Future.delayed(Duration(milliseconds: 500));

      // 触发会话提案
      final proposal = SessionProposal(
        id: DateTime.now().millisecondsSinceEpoch,
        name: 'Demo DApp',
        description: 'A demo DApp for testing',
        url: 'https://example.com',
        icons: ['https://example.com/icon.png'],
      );

      _sessionProposalController.add(proposal);
      debugPrint('✅ Pairing initiated');
    } catch (e) {
      debugPrint('❌ Pairing failed: $e');
      rethrow;
    }
  }

  /// 批准会话
  Future<void> approveSession({
    required int proposalId,
    required String address,
  }) async {
    try {
      await Future.delayed(Duration(milliseconds: 300));
      _activeSessions.add('session_$proposalId');
      debugPrint('✅ Session approved: $proposalId');
    } catch (e) {
      debugPrint('❌ Approve session failed: $e');
      rethrow;
    }
  }

  /// 拒绝会话
  Future<void> rejectSession({
    required int proposalId,
    String reason = 'User rejected',
  }) async {
    try {
      await Future.delayed(Duration(milliseconds: 200));
      debugPrint('✅ Session rejected: $proposalId - $reason');
    } catch (e) {
      debugPrint('❌ Reject session failed: $e');
      rethrow;
    }
  }

  /// 获取活动会话
  List<String> getActiveSessions() {
    return List.unmodifiable(_activeSessions);
  }

  /// 断开会话
  Future<void> disconnectSession(String sessionId) async {
    try {
      _activeSessions.remove(sessionId);
      debugPrint('✅ Session disconnected: $sessionId');
    } catch (e) {
      debugPrint('❌ Disconnect session failed: $e');
      rethrow;
    }
  }

  /// 清理资源
  void dispose() {
    _sessionProposalController.close();
  }
}

/// 会话提案数据模型
class SessionProposal {
  final int id;
  final String name;
  final String description;
  final String url;
  final List<String> icons;

  SessionProposal({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.icons,
  });
}

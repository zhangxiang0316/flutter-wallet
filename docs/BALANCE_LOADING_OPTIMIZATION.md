# 🚀 首页余额加载性能优化方案

## 📊 当前性能分析

### 性能瓶颈识别

根据代码和日志分析，主要瓶颈：

| 问题 | 影响 | 严重度 |
|------|------|--------|
| **Solana 节点超时** | 经常 6 秒超时，拖慢整体加载 | 🔴 高 |
| **串行 Token 查询** | 每个 Token 逐个查询，未批量化 | 🟡 中 |
| **公共节点慢** | 免费节点高峰期拥堵 | 🟡 中 |
| **无缓存预热** | 每次都从零开始加载 | 🟡 中 |
| **无渐进式加载** | 必须等所有链完成才显示 | 🟡 中 |

---

## 💡 优化方案（无需自建节点）

### 方案 1：优先显示缓存 + 后台更新 ⭐⭐⭐⭐⭐

**原理**: 立即显示上次缓存的余额，同时在后台更新最新数据

**实现**:
```dart
Future<void> refreshBalances() async {
  // 1. 立即显示缓存数据（< 50ms）
  final cachedBalances = await _loadCachedBalances();
  if (cachedBalances.isNotEmpty) {
    balances = cachedBalances;
    _applyAssetVisibility();
    update(); // 立即显示
  }
  
  // 2. 后台更新真实数据
  final freshBalances = await _balanceService.loadBalances(...);
  balances = freshBalances;
  await _saveCachedBalances(freshBalances); // 保存缓存
  _applyAssetVisibility();
  update(); // 更新为最新数据
}
```

**优势**:
- ✅ 用户感知速度提升 10x+
- ✅ 实现简单，改动小
- ✅ 离线也能看到上次余额

**效果**: 首屏加载从 3-5 秒降低到 < 100ms

---

### 方案 2：渐进式加载 ⭐⭐⭐⭐

**原理**: 按链并行加载，每条链完成立即显示，不等待慢链

**实现**:
```dart
Future<void> refreshBalances() async {
  isLoading = true;
  balances = [];
  update();
  
  final streams = [
    _loadEvmBalancesStream(...),   // 快：1-2秒
    _loadTronBalancesStream(...),  // 快：1-2秒
    _loadSolanaBalancesStream(...), // 慢：可能超时
  ];
  
  // 每条链完成立即显示
  await for (final chainBalances in Stream.merge(streams)) {
    balances.addAll(chainBalances);
    _applyAssetVisibility();
    update(); // 渐进式更新 UI
  }
  
  isLoading = false;
  update();
}
```

**优势**:
- ✅ 快链优先显示（BSC、TRON）
- ✅ 慢链不阻塞（Solana）
- ✅ 更好的用户体验

**效果**: 主流资产（BSC USDT）1-2 秒显示

---

### 方案 3：RPC 批量查询优化 ⭐⭐⭐⭐

**原理**: 使用 JSON-RPC 批量请求，一次查多个余额

**EVM 批量查询**:
```dart
Future<List<ChainBalance>> _loadEvmBalancesBatch({
  required WalletChainConfig chain,
  required List<WalletAsset> assets,
  required String address,
}) async {
  // 构建批量 RPC 请求
  final batchRequests = assets.asMap().entries.map((entry) {
    final index = entry.key;
    final asset = entry.value;
    
    if (asset.isNative) {
      return {
        'jsonrpc': '2.0',
        'id': index,
        'method': 'eth_getBalance',
        'params': [address, 'latest'],
      };
    } else {
      return {
        'jsonrpc': '2.0',
        'id': index,
        'method': 'eth_call',
        'params': [
          {
            'to': asset.contractAddress,
            'data': _encodeBalanceOf(address),
          },
          'latest',
        ],
      };
    }
  }).toList();
  
  // 一次请求查所有余额
  final response = await _dio.post(rpcUrl, data: batchRequests);
  
  // 解析批量响应
  return _parseBatchBalances(response.data, assets);
}
```

**Solana 批量查询**:
```dart
// 使用 getMultipleAccounts 一次查多个
final response = await solanaClient.rpcClient.call(
  'getMultipleAccounts',
  [
    [account1, account2, account3, ...], // 最多 100 个
    {'encoding': 'jsonParsed'},
  ],
);
```

**优势**:
- ✅ 减少网络往返次数
- ✅ 降低总耗时 50%+
- ✅ 节省网络流量

**效果**: 单链 5 个 Token 从 5 秒降到 1 秒

---

### 方案 4：更换更快的 RPC 节点 ⭐⭐⭐⭐⭐

**免费快速节点**:

```dart
// Solana - 使用更快的节点
static const List<String> _solanaRpcFallbacks = [
  'https://solana-mainnet.rpc.extrnode.com',  // 更快
  'https://rpc.ankr.com/solana',               // Ankr 免费节点
  'https://solana-api.projectserum.com',       // Serum 节点
  'https://api.mainnet-beta.solana.com',       // 官方备用
];

// BSC - 使用更快的节点
static const List<String> _bscRpcFallbacks = [
  'https://bsc.rpc.blxrbdn.com',              // bloXroute
  'https://rpc.ankr.com/bsc',                  // Ankr
  'https://bsc-dataseed.bnbchain.org',         // 官方
];

// Ethereum - 使用更快的节点
static const List<String> _ethereumRpcFallbacks = [
  'https://eth.rpc.blxrbdn.com',              // bloXroute
  'https://rpc.ankr.com/eth',                  // Ankr
  'https://ethereum-rpc.publicnode.com',       // PublicNode
];
```

**优质免费 RPC 提供商**:
- [Ankr](https://www.ankr.com/rpc/) - 稳定快速，每天 500M 免费
- [bloXroute](https://bloxroute.com/) - 超快，有免费额度
- [1RPC](https://www.1rpc.io/) - 隐私友好，免费
- [LlamaRPC](https://llamarpc.com/) - 社区节点，免费

**优势**:
- ✅ 立即生效，无需代码改动
- ✅ 显著提升速度 2-3x
- ✅ 完全免费

**效果**: Solana 请求从 6 秒超时降到 2-3 秒

---

### 方案 5：智能超时和降级 ⭐⭐⭐

**原理**: 快速失败，显示部分数据，避免全局等待

**实现**:
```dart
Future<List<ChainBalance>> _loadSolanaBalancesWithFastFail({
  required WalletChainConfig chain,
  required String address,
}) async {
  try {
    // 先尝试快速节点（3秒超时）
    return await _loadSolanaBalances(...)
        .timeout(Duration(seconds: 3));
  } catch (e) {
    developer.log('Solana fast request failed, showing cached/zero');
    
    // 降级：返回缓存或零值
    final cached = await _loadCachedSolanaBalances(address);
    if (cached != null) return cached;
    
    return _fallbackSolanaBalances(...);
  }
}
```

**超时策略**:
- 快速节点：3 秒超时
- 备用节点：5 秒超时
- 总超时：10 秒（而非 14 秒）

**优势**:
- ✅ 避免慢节点拖累整体
- ✅ 快速失败，不卡 UI
- ✅ 有降级方案

---

### 方案 6：预加载和预测 ⭐⭐⭐

**原理**: 在用户打开首页前就开始加载

**实现**:
```dart
class HomeController extends BaseController {
  @override
  void onReady() {
    super.onReady();
    // 启动时预加载
    _preloadBalances();
  }
  
  Future<void> _preloadBalances() async {
    if (wallet == null) return;
    
    // 静默加载，不显示 loading
    final freshBalances = await _balanceService.loadBalances(...)
        .catchError((_) => <ChainBalance>[]);
    
    if (freshBalances.isNotEmpty) {
      await _saveCachedBalances(freshBalances);
    }
  }
}
```

**优势**:
- ✅ 用户打开时数据已准备好
- ✅ 感知速度提升显著

---

## 🎯 推荐实施优先级

### 阶段 1：立即实施（1-2 小时）⚡

1. **更换快速 RPC 节点** （方案 4）
   - 改动小，效果明显
   - 预期提升：2-3x 速度

2. **优先显示缓存** （方案 1）
   - 用户感知提升最大
   - 预期：首屏 < 100ms

### 阶段 2：短期优化（1 天）📈

3. **渐进式加载** （方案 2）
   - 快链优先显示
   - 预期：主流资产 1-2 秒显示

4. **智能超时** （方案 5）
   - 避免慢链拖累
   - 预期：减少卡顿 50%

### 阶段 3：中期优化（2-3 天）🚀

5. **RPC 批量查询** （方案 3）
   - 技术难度较高
   - 预期：单链速度提升 50%

6. **预加载机制** （方案 6）
   - 需要生命周期配合
   - 预期：打开即显示

---

## 📊 预期性能提升

### 优化前 vs 优化后

| 场景 | 当前 | 方案 1+4 | 方案 1+2+4 | 全部方案 |
|------|------|----------|------------|----------|
| **首屏显示** | 3-5秒 | < 100ms ⚡ | < 100ms ⚡ | < 50ms ⚡ |
| **BSC 主流币** | 3-5秒 | 1-2秒 | 1-2秒 | < 1秒 |
| **Solana（慢链）** | 6-14秒 | 2-3秒 | 2-3秒 | 1-2秒 |
| **全部数据加载** | 5-14秒 | 3-5秒 | 2-4秒 | 1-3秒 |
| **用户感知速度** | 慢 😟 | 快 😊 | 很快 😄 | 极快 🚀 |

---

## 💻 方案 1+4 快速实施代码

### 1. 添加余额缓存

```dart
// lib/wallet/services/chain_balance_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chain_balance.dart';

class ChainBalanceCache {
  static const String _key = 'cached_balances_v1';
  static const Duration _maxAge = Duration(minutes: 30);
  
  Future<List<ChainBalance>?> load(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('${_key}_$walletId');
    if (json == null) return null;
    
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);
      
      // 超过 30 分钟的缓存视为过期
      if (DateTime.now().difference(timestamp) > _maxAge) {
        return null;
      }
      
      final balances = (data['balances'] as List)
          .map((item) => ChainBalance.fromJson(item))
          .toList();
      
      return balances;
    } catch (_) {
      return null;
    }
  }
  
  Future<void> save(String walletId, List<ChainBalance> balances) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'balances': balances.map((b) => b.toJson()).toList(),
    };
    await prefs.setString('${_key}_$walletId', jsonEncode(data));
  }
  
  Future<void> clear(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_key}_$walletId');
  }
}
```

### 2. 更新 HomeController

```dart
// 在 HomeController 中添加
final ChainBalanceCache _balanceCache = ChainBalanceCache();

Future<void> refreshBalances() async {
  final currentWallet = wallet;
  if (currentWallet == null || isLoading) return;
  final requestId = ++_balanceRequestId;
  
  // ✅ 立即显示缓存（如果有）
  final cachedBalances = await _balanceCache.load(currentWallet.id);
  if (cachedBalances != null && cachedBalances.isNotEmpty) {
    balances = cachedBalances;
    _applyAssetVisibility();
    _refreshTotalAssetsFromCachedPrices();
    update(); // 立即显示缓存数据
  }
  
  isLoading = true;
  update();

  try {
    // 后台加载最新数据
    final nextBalances = await _balanceService.loadBalances(
      bscAddress: currentWallet.bscAddress,
      tronAddress: currentWallet.tronAddress,
      solanaAddress: currentWallet.solanaAddress,
    );
    
    if (requestId != _balanceRequestId || wallet?.id != currentWallet.id) {
      return;
    }
    
    balances = nextBalances;
    
    // ✅ 保存缓存
    await _balanceCache.save(currentWallet.id, nextBalances);
    
    // ... 后续代码保持不变
  } catch (_) {
    // ... 错误处理
  }
}
```

### 3. 更新 RPC 节点列表

```dart
// 在 chain_balance_service.dart 中更新
static const List<String> _solanaRpcFallbacks = [
  'https://solana-mainnet.rpc.extrnode.com',  // ⚡ 新增：更快
  'https://rpc.ankr.com/solana',               // ⚡ 新增：Ankr
  'https://api.mainnet-beta.solana.com',       // 保留官方
  'https://solana-rpc.publicnode.com',         // 保留备用
];

static const Map<WalletChain, List<String>> _evmRpcFallbacks = {
  WalletChain.bsc: [
    'https://bsc.rpc.blxrbdn.com',            // ⚡ 新增：bloXroute
    'https://rpc.ankr.com/bsc',                // ⚡ 新增：Ankr
    'https://bsc-dataseed.bnbchain.org',
    'https://bsc-rpc.publicnode.com',
  ],
  WalletChain.ethereum: [
    'https://eth.rpc.blxrbdn.com',            // ⚡ 新增：bloXroute
    'https://rpc.ankr.com/eth',                // ⚡ 新增：Ankr
    'https://ethereum-rpc.publicnode.com',
    'https://eth.llamarpc.com',
  ],
  // ... 其他链
};
```

---

## ✅ 实施检查清单

### 阶段 1（立即）
- [ ] 添加 `ChainBalanceCache` 类
- [ ] 更新 `HomeController.refreshBalances()`
- [ ] 更新 RPC 节点列表
- [ ] 测试缓存加载速度
- [ ] 测试新节点稳定性

### 阶段 2（可选）
- [ ] 实现渐进式加载
- [ ] 优化超时策略
- [ ] 添加性能监控

### 阶段 3（可选）
- [ ] 实现 RPC 批量查询
- [ ] 添加预加载机制

---

## 🎯 预期效果

实施方案 1+4 后：
- ✅ **首屏显示**: 5 秒 → < 100ms（**50x 提升**）
- ✅ **用户感知**: 从"慢"到"很快"
- ✅ **离线体验**: 可以看到上次余额
- ✅ **节点速度**: 提升 2-3x
- ✅ **实施成本**: 1-2 小时

---

**建议**: 先实施方案 1+4，效果显著且实施简单，可以立即改善用户体验！

如需帮助实施，我可以立即开始编写代码。

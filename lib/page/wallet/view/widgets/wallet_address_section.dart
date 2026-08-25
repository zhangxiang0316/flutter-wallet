import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/adapters/chain_adapter.dart';
import '../../../../wallet/adapters/default_chain_adapter_registry.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';
import '../../../../widget/chain_presentation_scope.dart';
import 'wallet_detail_common.dart';

/// 各链地址列表区域。
///
/// EVM 兼容链复用同一个地址；Solana 和 TRON 展示各自派生地址。
class WalletAddressSection extends StatelessWidget {
  const WalletAddressSection({super.key, required this.wallet});

  /// 当前钱包账户。
  final WalletAccount wallet;

  @override
  Widget build(BuildContext context) {
    final registry = createDefaultChainAdapterRegistry();
    final addresses = ChainWalletAddresses.fromWallet(wallet);
    final entries = WalletChain.values.map((chain) {
      final adapter = registry.find(chain);
      if (adapter == null ||
          !adapter.capabilities.supports(ChainCapability.receive)) {
        return null;
      }
      final address = adapter.walletAddress(addresses);
      if (address.isEmpty) return null;
      return (chain: chain, address: address);
    }).whereType<({String address, WalletChain chain})>();
    return WalletDetailSectionPanel(
      title: S.of(context).walletAddresses,
      children: entries
          .map(
            (entry) => _AddressTile(
              chain: entry.chain,
              label: entry.chain.name,
              address: entry.address,
            ),
          )
          .toList(growable: false),
    );
  }
}

/// 单条链地址行。
class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.chain,
    required this.label,
    required this.address,
  });

  /// 当前行对应的链。
  final WalletChain chain;

  /// 链展示名称。
  final String label;

  /// 当前链钱包地址。
  final String address;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return WalletDetailPlainTile(
      leading: _ChainBadge(chain: chain),
      title: label,
      subtitle: address,
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints.tight(Size(34.w, 34.w)),
        padding: EdgeInsets.zero,
        onPressed: () => copyWalletDetailValue(context, address),
        icon: Icon(
          Icons.content_copy_rounded,
          size: 17.w,
          color: colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        tooltip: S.of(context).copied,
      ),
    );
  }
}

/// 链地址行左侧的链标识。
class _ChainBadge extends StatelessWidget {
  const _ChainBadge({required this.chain});

  /// 当前标识对应的链。
  final WalletChain chain;

  @override
  Widget build(BuildContext context) {
    final presentation = ChainPresentationScope.of(context).presentation(chain);
    final color = Color(presentation.colorValue);
    return Container(
      width: 32.w,
      height: 32.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        presentation.label,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

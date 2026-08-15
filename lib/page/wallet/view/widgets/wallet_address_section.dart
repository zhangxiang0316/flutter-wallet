import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';
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
    return WalletDetailSectionPanel(
      title: S.of(context).walletAddresses,
      children: [
        _AddressTile(
          chain: WalletChain.bsc,
          label: WalletChain.bsc.name,
          address: wallet.bscAddress,
        ),
        _AddressTile(
          chain: WalletChain.ethereum,
          label: WalletChain.ethereum.name,
          address: wallet.bscAddress,
        ),
        _AddressTile(
          chain: WalletChain.xLayer,
          label: WalletChain.xLayer.name,
          address: wallet.bscAddress,
        ),
        _AddressTile(
          chain: WalletChain.arbitrum,
          label: WalletChain.arbitrum.name,
          address: wallet.bscAddress,
        ),
        _AddressTile(
          chain: WalletChain.bitcoin,
          label: WalletChain.bitcoin.name,
          address: wallet.bitcoinAddress,
        ),
        _AddressTile(
          chain: WalletChain.solana,
          label: WalletChain.solana.name,
          address: wallet.solanaAddress,
        ),
        _AddressTile(
          chain: WalletChain.sui,
          label: WalletChain.sui.name,
          address: wallet.suiAddress,
        ),
        _AddressTile(
          chain: WalletChain.aptos,
          label: WalletChain.aptos.name,
          address: wallet.aptosAddress,
        ),
        _AddressTile(
          chain: WalletChain.tron,
          label: WalletChain.tron.name,
          address: wallet.tronAddress,
        ),
      ],
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
    return Container(
      width: 32.w,
      height: 32.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _chainColor(chain).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        chain.symbol.characters.first,
        style: TextStyle(
          color: _chainColor(chain),
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// 获取链在详情页中的品牌色。
  Color _chainColor(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return const Color(0xFFF0B90B);
      case WalletChain.ethereum:
        return const Color(0xFF627EEA);
      case WalletChain.xLayer:
        return const Color(0xFF10B981);
      case WalletChain.arbitrum:
        return const Color(0xFF28A0F0);
      case WalletChain.bitcoin:
        return const Color(0xFFF7931A);
      case WalletChain.solana:
        return const Color(0xFF14F195);
      case WalletChain.sui:
        return const Color(0xFF4DA2FF);
      case WalletChain.aptos:
        return const Color(0xFF13B5A4);
      case WalletChain.tron:
        return const Color(0xFFE11D48);
    }
  }
}

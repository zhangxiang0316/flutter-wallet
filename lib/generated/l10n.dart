// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `phone`
  String get phone {
    return Intl.message('phone', name: 'phone', desc: '', args: []);
  }

  /// `email`
  String get email {
    return Intl.message('email', name: 'email', desc: '', args: []);
  }

  /// `login`
  String get login {
    return Intl.message('login', name: 'login', desc: '', args: []);
  }

  /// `沐晨钱包`
  String get appName {
    return Intl.message('沐晨钱包', name: 'appName', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Theme`
  String get theme {
    return Intl.message('Theme', name: 'theme', desc: '', args: []);
  }

  /// `Asset display`
  String get assetVisibility {
    return Intl.message(
      'Asset display',
      name: 'assetVisibility',
      desc: '',
      args: [],
    );
  }

  /// `Turn an asset off to hide it from the home balance list and valuation. On-chain balances are not deleted and can be shown again anytime.`
  String get assetVisibilityTip {
    return Intl.message(
      'Turn an asset off to hide it from the home balance list and valuation. On-chain balances are not deleted and can be shown again anytime.',
      name: 'assetVisibilityTip',
      desc: '',
      args: [],
    );
  }

  /// `Add asset`
  String get addCustomAsset {
    return Intl.message(
      'Add asset',
      name: 'addCustomAsset',
      desc: '',
      args: [],
    );
  }

  /// `Remove asset`
  String get removeCustomAsset {
    return Intl.message(
      'Remove asset',
      name: 'removeCustomAsset',
      desc: '',
      args: [],
    );
  }

  /// `Remove "{symbol}"? The home page will no longer query this asset balance.`
  String removeCustomAssetConfirmMessage(Object symbol) {
    return Intl.message(
      'Remove "$symbol"? The home page will no longer query this asset balance.',
      name: 'removeCustomAssetConfirmMessage',
      desc: '',
      args: [symbol],
    );
  }

  /// `Contract address`
  String get customAssetContractAddress {
    return Intl.message(
      'Contract address',
      name: 'customAssetContractAddress',
      desc: '',
      args: [],
    );
  }

  /// `Enter the token contract or mint address on this chain`
  String get customAssetContractHint {
    return Intl.message(
      'Enter the token contract or mint address on this chain',
      name: 'customAssetContractHint',
      desc: '',
      args: [],
    );
  }

  /// `Symbol`
  String get customAssetSymbol {
    return Intl.message(
      'Symbol',
      name: 'customAssetSymbol',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get customAssetName {
    return Intl.message('Name', name: 'customAssetName', desc: '', args: []);
  }

  /// `Decimals`
  String get customAssetDecimals {
    return Intl.message(
      'Decimals',
      name: 'customAssetDecimals',
      desc: '',
      args: [],
    );
  }

  /// `Detect token info`
  String get fetchTokenInfo {
    return Intl.message(
      'Detect token info',
      name: 'fetchTokenInfo',
      desc: '',
      args: [],
    );
  }

  /// `Token info is unavailable. Fill it in manually.`
  String get customAssetMetadataUnavailable {
    return Intl.message(
      'Token info is unavailable. Fill it in manually.',
      name: 'customAssetMetadataUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `This asset already exists`
  String get customAssetDuplicate {
    return Intl.message(
      'This asset already exists',
      name: 'customAssetDuplicate',
      desc: '',
      args: [],
    );
  }

  /// `Check the contract address, symbol, name, and decimals`
  String get customAssetInvalid {
    return Intl.message(
      'Check the contract address, symbol, name, and decimals',
      name: 'customAssetInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Asset added`
  String get customAssetAdded {
    return Intl.message(
      'Asset added',
      name: 'customAssetAdded',
      desc: '',
      args: [],
    );
  }

  /// `System`
  String get themeSystem {
    return Intl.message('System', name: 'themeSystem', desc: '', args: []);
  }

  /// `Light`
  String get themeLight {
    return Intl.message('Light', name: 'themeLight', desc: '', args: []);
  }

  /// `Dark`
  String get themeDark {
    return Intl.message('Dark', name: 'themeDark', desc: '', args: []);
  }

  /// `Create or import a wallet`
  String get walletEmptyTitle {
    return Intl.message(
      'Create or import a wallet',
      name: 'walletEmptyTitle',
      desc: '',
      args: [],
    );
  }

  /// `Supports address management and multi-asset on-chain balance lookup for BNB Smart Chain, Ethereum, X Layer, Solana, and TRON.`
  String get walletEmptySubtitle {
    return Intl.message(
      'Supports address management and multi-asset on-chain balance lookup for BNB Smart Chain, Ethereum, X Layer, Solana, and TRON.',
      name: 'walletEmptySubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Create wallet`
  String get createWallet {
    return Intl.message(
      'Create wallet',
      name: 'createWallet',
      desc: '',
      args: [],
    );
  }

  /// `Import wallet`
  String get importWallet {
    return Intl.message(
      'Import wallet',
      name: 'importWallet',
      desc: '',
      args: [],
    );
  }

  /// `Add wallet`
  String get addWallet {
    return Intl.message('Add wallet', name: 'addWallet', desc: '', args: []);
  }

  /// `Switch wallet`
  String get switchWallet {
    return Intl.message(
      'Switch wallet',
      name: 'switchWallet',
      desc: '',
      args: [],
    );
  }

  /// `EVM / SOL / TRX multi-chain wallet`
  String get primaryMultiChainWallet {
    return Intl.message(
      'EVM / SOL / TRX multi-chain wallet',
      name: 'primaryMultiChainWallet',
      desc: '',
      args: [],
    );
  }

  /// `Copy wallet address`
  String get copyWalletAddress {
    return Intl.message(
      'Copy wallet address',
      name: 'copyWalletAddress',
      desc: '',
      args: [],
    );
  }

  /// `Wallet details`
  String get walletDetails {
    return Intl.message(
      'Wallet details',
      name: 'walletDetails',
      desc: '',
      args: [],
    );
  }

  /// `Wallet name`
  String get walletName {
    return Intl.message('Wallet name', name: 'walletName', desc: '', args: []);
  }

  /// `Edit wallet name`
  String get editWalletName {
    return Intl.message(
      'Edit wallet name',
      name: 'editWalletName',
      desc: '',
      args: [],
    );
  }

  /// `Save name`
  String get saveWalletName {
    return Intl.message(
      'Save name',
      name: 'saveWalletName',
      desc: '',
      args: [],
    );
  }

  /// `Enter a wallet name`
  String get walletNameRequired {
    return Intl.message(
      'Enter a wallet name',
      name: 'walletNameRequired',
      desc: '',
      args: [],
    );
  }

  /// `Wallet name updated`
  String get walletNameUpdated {
    return Intl.message(
      'Wallet name updated',
      name: 'walletNameUpdated',
      desc: '',
      args: [],
    );
  }

  /// `Chain addresses`
  String get walletAddresses {
    return Intl.message(
      'Chain addresses',
      name: 'walletAddresses',
      desc: '',
      args: [],
    );
  }

  /// `Wallet secrets`
  String get walletSecrets {
    return Intl.message(
      'Wallet secrets',
      name: 'walletSecrets',
      desc: '',
      args: [],
    );
  }

  /// `View private key`
  String get viewPrivateKey {
    return Intl.message(
      'View private key',
      name: 'viewPrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `View mnemonic`
  String get viewMnemonic {
    return Intl.message(
      'View mnemonic',
      name: 'viewMnemonic',
      desc: '',
      args: [],
    );
  }

  /// `Unlock with wallet password to view`
  String get unlockToView {
    return Intl.message(
      'Unlock with wallet password to view',
      name: 'unlockToView',
      desc: '',
      args: [],
    );
  }

  /// `Total assets`
  String get totalAssets {
    return Intl.message(
      'Total assets',
      name: 'totalAssets',
      desc: '',
      args: [],
    );
  }

  /// `Refresh`
  String get refreshBalance {
    return Intl.message('Refresh', name: 'refreshBalance', desc: '', args: []);
  }

  /// `Remove wallet`
  String get removeWallet {
    return Intl.message(
      'Remove wallet',
      name: 'removeWallet',
      desc: '',
      args: [],
    );
  }

  /// `Remove "{name}"? The wallet data saved on this device will be deleted.`
  String removeWalletConfirmMessage(Object name) {
    return Intl.message(
      'Remove "$name"? The wallet data saved on this device will be deleted.',
      name: 'removeWalletConfirmMessage',
      desc: '',
      args: [name],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Some balance lookups failed`
  String get balanceLoadFailed {
    return Intl.message(
      'Some balance lookups failed',
      name: 'balanceLoadFailed',
      desc: '',
      args: [],
    );
  }

  /// `Loading...`
  String get loading {
    return Intl.message('Loading...', name: 'loading', desc: '', args: []);
  }

  /// `Security notice`
  String get securityNotice {
    return Intl.message(
      'Security notice',
      name: 'securityNotice',
      desc: '',
      args: [],
    );
  }

  /// `Private keys are encrypted with your wallet password and saved in secure device storage. Keep the password safe; this is not hardware-wallet grade security.`
  String get securityNoticeDetail {
    return Intl.message(
      'Private keys are encrypted with your wallet password and saved in secure device storage. Keep the password safe; this is not hardware-wallet grade security.',
      name: 'securityNoticeDetail',
      desc: '',
      args: [],
    );
  }

  /// `Import private key`
  String get importPrivateKey {
    return Intl.message(
      'Import private key',
      name: 'importPrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `Enter a 64-character hex private key, optionally prefixed with 0x`
  String get privateKeyHint {
    return Intl.message(
      'Enter a 64-character hex private key, optionally prefixed with 0x',
      name: 'privateKeyHint',
      desc: '',
      args: [],
    );
  }

  /// `Import mnemonic`
  String get importMnemonic {
    return Intl.message(
      'Import mnemonic',
      name: 'importMnemonic',
      desc: '',
      args: [],
    );
  }

  /// `Mnemonic`
  String get mnemonic {
    return Intl.message('Mnemonic', name: 'mnemonic', desc: '', args: []);
  }

  /// `Enter 12 English words separated by spaces`
  String get mnemonicHint {
    return Intl.message(
      'Enter 12 English words separated by spaces',
      name: 'mnemonicHint',
      desc: '',
      args: [],
    );
  }

  /// `Back up mnemonic`
  String get backupMnemonic {
    return Intl.message(
      'Back up mnemonic',
      name: 'backupMnemonic',
      desc: '',
      args: [],
    );
  }

  /// `Write these words down in order and keep them offline. Anyone with these words can control your assets.`
  String get backupMnemonicTip {
    return Intl.message(
      'Write these words down in order and keep them offline. Anyone with these words can control your assets.',
      name: 'backupMnemonicTip',
      desc: '',
      args: [],
    );
  }

  /// `I have backed up the mnemonic`
  String get mnemonicBackupConfirm {
    return Intl.message(
      'I have backed up the mnemonic',
      name: 'mnemonicBackupConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Invalid mnemonic`
  String get invalidMnemonic {
    return Intl.message(
      'Invalid mnemonic',
      name: 'invalidMnemonic',
      desc: '',
      args: [],
    );
  }

  /// `Import`
  String get confirmImport {
    return Intl.message('Import', name: 'confirmImport', desc: '', args: []);
  }

  /// `Wallet password`
  String get walletPassword {
    return Intl.message(
      'Wallet password',
      name: 'walletPassword',
      desc: '',
      args: [],
    );
  }

  /// `At least 6 characters. Used to encrypt local private keys and unlock transfers.`
  String get walletPasswordHint {
    return Intl.message(
      'At least 6 characters. Used to encrypt local private keys and unlock transfers.',
      name: 'walletPasswordHint',
      desc: '',
      args: [],
    );
  }

  /// `Confirm wallet password`
  String get confirmWalletPassword {
    return Intl.message(
      'Confirm wallet password',
      name: 'confirmWalletPassword',
      desc: '',
      args: [],
    );
  }

  /// `Enter the wallet password`
  String get walletPasswordRequired {
    return Intl.message(
      'Enter the wallet password',
      name: 'walletPasswordRequired',
      desc: '',
      args: [],
    );
  }

  /// `Wallet password must be at least 6 characters`
  String get walletPasswordTooShort {
    return Intl.message(
      'Wallet password must be at least 6 characters',
      name: 'walletPasswordTooShort',
      desc: '',
      args: [],
    );
  }

  /// `Wallet passwords do not match`
  String get walletPasswordMismatch {
    return Intl.message(
      'Wallet passwords do not match',
      name: 'walletPasswordMismatch',
      desc: '',
      args: [],
    );
  }

  /// `Unlock wallet`
  String get unlockWallet {
    return Intl.message(
      'Unlock wallet',
      name: 'unlockWallet',
      desc: '',
      args: [],
    );
  }

  /// `Enter the wallet password to unlock the local private key for this transaction.`
  String get unlockWalletForTransfer {
    return Intl.message(
      'Enter the wallet password to unlock the local private key for this transaction.',
      name: 'unlockWalletForTransfer',
      desc: '',
      args: [],
    );
  }

  /// `Incorrect wallet password`
  String get invalidWalletPassword {
    return Intl.message(
      'Incorrect wallet password',
      name: 'invalidWalletPassword',
      desc: '',
      args: [],
    );
  }

  /// `Encrypted private key was not found for this wallet`
  String get walletSecretMissing {
    return Intl.message(
      'Encrypted private key was not found for this wallet',
      name: 'walletSecretMissing',
      desc: '',
      args: [],
    );
  }

  /// `Upgrade wallet security`
  String get walletSecurityUpgrade {
    return Intl.message(
      'Upgrade wallet security',
      name: 'walletSecurityUpgrade',
      desc: '',
      args: [],
    );
  }

  /// `Encrypt wallet`
  String get encryptWallet {
    return Intl.message(
      'Encrypt wallet',
      name: 'encryptWallet',
      desc: '',
      args: [],
    );
  }

  /// `Wallet private key encrypted`
  String get walletSecurityMigrated {
    return Intl.message(
      'Wallet private key encrypted',
      name: 'walletSecurityMigrated',
      desc: '',
      args: [],
    );
  }

  /// `Failed to encrypt wallet private key. Try again.`
  String get walletSecurityMigrationFailed {
    return Intl.message(
      'Failed to encrypt wallet private key. Try again.',
      name: 'walletSecurityMigrationFailed',
      desc: '',
      args: [],
    );
  }

  /// `Complete Solana Address`
  String get walletSolanaAddressUpgrade {
    return Intl.message(
      'Complete Solana Address',
      name: 'walletSolanaAddressUpgrade',
      desc: '',
      args: [],
    );
  }

  /// `This wallet was created before Solana support. Enter the wallet password to unlock the local private key and derive the Solana address.`
  String get walletSolanaAddressUpgradeDetail {
    return Intl.message(
      'This wallet was created before Solana support. Enter the wallet password to unlock the local private key and derive the Solana address.',
      name: 'walletSolanaAddressUpgradeDetail',
      desc: '',
      args: [],
    );
  }

  /// `Complete Address`
  String get walletSolanaAddressUpgradeAction {
    return Intl.message(
      'Complete Address',
      name: 'walletSolanaAddressUpgradeAction',
      desc: '',
      args: [],
    );
  }

  /// `Solana address completed`
  String get walletSolanaAddressUpgraded {
    return Intl.message(
      'Solana address completed',
      name: 'walletSolanaAddressUpgraded',
      desc: '',
      args: [],
    );
  }

  /// `Solana address completion failed. Please try again.`
  String get walletSolanaAddressUpgradeFailed {
    return Intl.message(
      'Solana address completion failed. Please try again.',
      name: 'walletSolanaAddressUpgradeFailed',
      desc: '',
      args: [],
    );
  }

  /// `Wallet created`
  String get walletCreated {
    return Intl.message(
      'Wallet created',
      name: 'walletCreated',
      desc: '',
      args: [],
    );
  }

  /// `Import successful`
  String get walletImported {
    return Intl.message(
      'Import successful',
      name: 'walletImported',
      desc: '',
      args: [],
    );
  }

  /// `Wallet removed`
  String get walletRemoved {
    return Intl.message(
      'Wallet removed',
      name: 'walletRemoved',
      desc: '',
      args: [],
    );
  }

  /// `Invalid private key`
  String get invalidPrivateKey {
    return Intl.message(
      'Invalid private key',
      name: 'invalidPrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `Transfer`
  String get transfer {
    return Intl.message('Transfer', name: 'transfer', desc: '', args: []);
  }

  /// `Transfer {symbol}`
  String transferAsset(Object symbol) {
    return Intl.message(
      'Transfer $symbol',
      name: 'transferAsset',
      desc: '',
      args: [symbol],
    );
  }

  /// `Recipient address`
  String get recipientAddress {
    return Intl.message(
      'Recipient address',
      name: 'recipientAddress',
      desc: '',
      args: [],
    );
  }

  /// `Amount`
  String get transferAmount {
    return Intl.message('Amount', name: 'transferAmount', desc: '', args: []);
  }

  /// `Transfer`
  String get confirmTransfer {
    return Intl.message(
      'Transfer',
      name: 'confirmTransfer',
      desc: '',
      args: [],
    );
  }

  /// `Transaction submitted`
  String get transferSubmitted {
    return Intl.message(
      'Transaction submitted',
      name: 'transferSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `Transfer failed. Check the address, amount, and on-chain balance.`
  String get transferFailed {
    return Intl.message(
      'Transfer failed. Check the address, amount, and on-chain balance.',
      name: 'transferFailed',
      desc: '',
      args: [],
    );
  }

  /// `Transfer details are unavailable`
  String get transferUnavailable {
    return Intl.message(
      'Transfer details are unavailable',
      name: 'transferUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Available balance`
  String get availableBalance {
    return Intl.message(
      'Available balance',
      name: 'availableBalance',
      desc: '',
      args: [],
    );
  }

  /// `Transfer details`
  String get transferDetails {
    return Intl.message(
      'Transfer details',
      name: 'transferDetails',
      desc: '',
      args: [],
    );
  }

  /// `Network fee`
  String get networkFee {
    return Intl.message('Network fee', name: 'networkFee', desc: '', args: []);
  }

  /// `Estimated network fee`
  String get estimatedNetworkFee {
    return Intl.message(
      'Estimated network fee',
      name: 'estimatedNetworkFee',
      desc: '',
      args: [],
    );
  }

  /// `The network fee is paid in {symbol}. Make sure this wallet has enough balance.`
  String networkFeeAsset(Object symbol) {
    return Intl.message(
      'The network fee is paid in $symbol. Make sure this wallet has enough balance.',
      name: 'networkFeeAsset',
      desc: '',
      args: [symbol],
    );
  }

  /// `Estimating fee...`
  String get feeEstimating {
    return Intl.message(
      'Estimating fee...',
      name: 'feeEstimating',
      desc: '',
      args: [],
    );
  }

  /// `Fee estimate is unavailable. Try again later.`
  String get feeUnavailable {
    return Intl.message(
      'Fee estimate is unavailable. Try again later.',
      name: 'feeUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Up to {amount}`
  String feeFallback(Object amount) {
    return Intl.message(
      'Up to $amount',
      name: 'feeFallback',
      desc: '',
      args: [amount],
    );
  }

  /// `Transaction hash`
  String get transactionHash {
    return Intl.message(
      'Transaction hash',
      name: 'transactionHash',
      desc: '',
      args: [],
    );
  }

  /// `Copy hash`
  String get copyHash {
    return Intl.message('Copy hash', name: 'copyHash', desc: '', args: []);
  }

  /// `Back to wallet`
  String get backToWallet {
    return Intl.message(
      'Back to wallet',
      name: 'backToWallet',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid recipient address and transfer amount`
  String get transferInputInvalid {
    return Intl.message(
      'Enter a valid recipient address and transfer amount',
      name: 'transferInputInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Copied`
  String get copied {
    return Intl.message('Copied', name: 'copied', desc: '', args: []);
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}

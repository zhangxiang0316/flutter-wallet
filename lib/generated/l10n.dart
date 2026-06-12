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
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
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
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `phone`
  String get phone {
    return Intl.message(
      'phone',
      name: 'phone',
      desc: '',
      args: [],
    );
  }

  /// `email`
  String get email {
    return Intl.message(
      'email',
      name: 'email',
      desc: '',
      args: [],
    );
  }

  /// `login`
  String get login {
    return Intl.message(
      'login',
      name: 'login',
      desc: '',
      args: [],
    );
  }

  /// `沐晨钱包`
  String get appName {
    return Intl.message(
      '沐晨钱包',
      name: 'appName',
      desc: '',
      args: [],
    );
  }

  /// `Secure multi-chain assets`
  String get splashTagline {
    return Intl.message(
      'Secure multi-chain assets',
      name: 'splashTagline',
      desc: '',
      args: [],
    );
  }

  /// `Opening wallet`
  String get splashLoading {
    return Intl.message(
      'Opening wallet',
      name: 'splashLoading',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get language {
    return Intl.message(
      'Language',
      name: 'language',
      desc: '',
      args: [],
    );
  }

  /// `Theme`
  String get theme {
    return Intl.message(
      'Theme',
      name: 'theme',
      desc: '',
      args: [],
    );
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

  /// `Networks`
  String get networkManagement {
    return Intl.message(
      'Networks',
      name: 'networkManagement',
      desc: '',
      args: [],
    );
  }

  /// `Add EVM-compatible networks only. Custom networks reuse the wallet EVM address and support native coin and token balance lookup.`
  String get networkManagementTip {
    return Intl.message(
      'Add EVM-compatible networks only. Custom networks reuse the wallet EVM address and support native coin and token balance lookup.',
      name: 'networkManagementTip',
      desc: '',
      args: [],
    );
  }

  /// `Add network`
  String get addNetwork {
    return Intl.message(
      'Add network',
      name: 'addNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Edit network`
  String get editNetwork {
    return Intl.message(
      'Edit network',
      name: 'editNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Save network`
  String get saveNetwork {
    return Intl.message(
      'Save network',
      name: 'saveNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Remove network`
  String get removeNetwork {
    return Intl.message(
      'Remove network',
      name: 'removeNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Remove "{name}"? Assets on this custom network will no longer be queried.`
  String removeNetworkConfirm(Object name) {
    return Intl.message(
      'Remove "$name"? Assets on this custom network will no longer be queried.',
      name: 'removeNetworkConfirm',
      desc: '',
      args: [name],
    );
  }

  /// `Network name`
  String get networkName {
    return Intl.message(
      'Network name',
      name: 'networkName',
      desc: '',
      args: [],
    );
  }

  /// `Native symbol`
  String get networkSymbol {
    return Intl.message(
      'Native symbol',
      name: 'networkSymbol',
      desc: '',
      args: [],
    );
  }

  /// `Chain ID`
  String get networkChainId {
    return Intl.message(
      'Chain ID',
      name: 'networkChainId',
      desc: '',
      args: [],
    );
  }

  /// `RPC URL`
  String get networkRpcUrl {
    return Intl.message(
      'RPC URL',
      name: 'networkRpcUrl',
      desc: '',
      args: [],
    );
  }

  /// `One RPC URL per line, or separate them with commas`
  String get networkRpcUrlHelper {
    return Intl.message(
      'One RPC URL per line, or separate them with commas',
      name: 'networkRpcUrlHelper',
      desc: '',
      args: [],
    );
  }

  /// `Explorer API URL`
  String get networkExplorerApiUrl {
    return Intl.message(
      'Explorer API URL',
      name: 'networkExplorerApiUrl',
      desc: '',
      args: [],
    );
  }

  /// `Explorer API key`
  String get networkExplorerApiKey {
    return Intl.message(
      'Explorer API key',
      name: 'networkExplorerApiKey',
      desc: '',
      args: [],
    );
  }

  /// `Used for EVM transaction history. Supports Etherscan-compatible APIs.`
  String get networkExplorerApiUrlHelper {
    return Intl.message(
      'Used for EVM transaction history. Supports Etherscan-compatible APIs.',
      name: 'networkExplorerApiUrlHelper',
      desc: '',
      args: [],
    );
  }

  /// `Network added`
  String get networkAdded {
    return Intl.message(
      'Network added',
      name: 'networkAdded',
      desc: '',
      args: [],
    );
  }

  /// `Network updated`
  String get networkUpdated {
    return Intl.message(
      'Network updated',
      name: 'networkUpdated',
      desc: '',
      args: [],
    );
  }

  /// `Network removed`
  String get networkRemoved {
    return Intl.message(
      'Network removed',
      name: 'networkRemoved',
      desc: '',
      args: [],
    );
  }

  /// `This network already exists`
  String get networkDuplicate {
    return Intl.message(
      'This network already exists',
      name: 'networkDuplicate',
      desc: '',
      args: [],
    );
  }

  /// `Check the network name, symbol, chain ID, and RPC URL`
  String get networkInvalid {
    return Intl.message(
      'Check the network name, symbol, chain ID, and RPC URL',
      name: 'networkInvalid',
      desc: '',
      args: [],
    );
  }

  /// `RPC chain ID does not match`
  String get networkRpcMismatch {
    return Intl.message(
      'RPC chain ID does not match',
      name: 'networkRpcMismatch',
      desc: '',
      args: [],
    );
  }

  /// `RPC is unavailable`
  String get networkRpcUnavailable {
    return Intl.message(
      'RPC is unavailable',
      name: 'networkRpcUnavailable',
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
    return Intl.message(
      'Name',
      name: 'customAssetName',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'System',
      name: 'themeSystem',
      desc: '',
      args: [],
    );
  }

  /// `Light`
  String get themeLight {
    return Intl.message(
      'Light',
      name: 'themeLight',
      desc: '',
      args: [],
    );
  }

  /// `Dark`
  String get themeDark {
    return Intl.message(
      'Dark',
      name: 'themeDark',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Add wallet',
      name: 'addWallet',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Wallet name',
      name: 'walletName',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Refresh',
      name: 'refreshBalance',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Loading...',
      name: 'loading',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Mnemonic',
      name: 'mnemonic',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Import',
      name: 'confirmImport',
      desc: '',
      args: [],
    );
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

  /// `Receive`
  String get receive {
    return Intl.message(
      'Receive',
      name: 'receive',
      desc: '',
      args: [],
    );
  }

  /// `Receive {symbol}`
  String receiveAsset(Object symbol) {
    return Intl.message(
      'Receive $symbol',
      name: 'receiveAsset',
      desc: '',
      args: [symbol],
    );
  }

  /// `Receive details are unavailable`
  String get receiveUnavailable {
    return Intl.message(
      'Receive details are unavailable',
      name: 'receiveUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Select network`
  String get selectReceiveChain {
    return Intl.message(
      'Select network',
      name: 'selectReceiveChain',
      desc: '',
      args: [],
    );
  }

  /// `Select asset`
  String get selectReceiveAsset {
    return Intl.message(
      'Select asset',
      name: 'selectReceiveAsset',
      desc: '',
      args: [],
    );
  }

  /// `Scan to receive`
  String get receiveQrTitle {
    return Intl.message(
      'Scan to receive',
      name: 'receiveQrTitle',
      desc: '',
      args: [],
    );
  }

  /// `Only send this asset on the selected network.`
  String get receiveQrTip {
    return Intl.message(
      'Only send this asset on the selected network.',
      name: 'receiveQrTip',
      desc: '',
      args: [],
    );
  }

  /// `Receive address`
  String get receiveAddress {
    return Intl.message(
      'Receive address',
      name: 'receiveAddress',
      desc: '',
      args: [],
    );
  }

  /// `Copy address`
  String get copyReceiveAddress {
    return Intl.message(
      'Copy address',
      name: 'copyReceiveAddress',
      desc: '',
      args: [],
    );
  }

  /// `This wallet does not have an address for this network`
  String get receiveAddressEmpty {
    return Intl.message(
      'This wallet does not have an address for this network',
      name: 'receiveAddressEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Transfer`
  String get transfer {
    return Intl.message(
      'Transfer',
      name: 'transfer',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Amount',
      name: 'transferAmount',
      desc: '',
      args: [],
    );
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

  /// `Transfer network`
  String get selectTransferChain {
    return Intl.message(
      'Transfer network',
      name: 'selectTransferChain',
      desc: '',
      args: [],
    );
  }

  /// `Transfer asset`
  String get selectTransferAsset {
    return Intl.message(
      'Transfer asset',
      name: 'selectTransferAsset',
      desc: '',
      args: [],
    );
  }

  /// `From address`
  String get transferFromAddress {
    return Intl.message(
      'From address',
      name: 'transferFromAddress',
      desc: '',
      args: [],
    );
  }

  /// `Scan address`
  String get scanRecipientAddress {
    return Intl.message(
      'Scan address',
      name: 'scanRecipientAddress',
      desc: '',
      args: [],
    );
  }

  /// `Align the QR code inside the frame to fill the recipient address.`
  String get scanRecipientAddressTip {
    return Intl.message(
      'Align the QR code inside the frame to fill the recipient address.',
      name: 'scanRecipientAddressTip',
      desc: '',
      args: [],
    );
  }

  /// `No wallet address found in this QR code`
  String get scanNoAddressFound {
    return Intl.message(
      'No wallet address found in this QR code',
      name: 'scanNoAddressFound',
      desc: '',
      args: [],
    );
  }

  /// `Camera is unavailable. Check camera permission and try again.`
  String get scanCameraError {
    return Intl.message(
      'Camera is unavailable. Check camera permission and try again.',
      name: 'scanCameraError',
      desc: '',
      args: [],
    );
  }

  /// `Toggle flash`
  String get scanToggleFlash {
    return Intl.message(
      'Toggle flash',
      name: 'scanToggleFlash',
      desc: '',
      args: [],
    );
  }

  /// `Switch camera`
  String get scanSwitchCamera {
    return Intl.message(
      'Switch camera',
      name: 'scanSwitchCamera',
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
    return Intl.message(
      'Network fee',
      name: 'networkFee',
      desc: '',
      args: [],
    );
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

  /// `Transactions`
  String get transactionHistory {
    return Intl.message(
      'Transactions',
      name: 'transactionHistory',
      desc: '',
      args: [],
    );
  }

  /// `No transactions`
  String get transactionHistoryEmpty {
    return Intl.message(
      'No transactions',
      name: 'transactionHistoryEmpty',
      desc: '',
      args: [],
    );
  }

  /// `No in-app records found. View this address in a block explorer.`
  String get transactionHistoryExplorerHint {
    return Intl.message(
      'No in-app records found. View this address in a block explorer.',
      name: 'transactionHistoryExplorerHint',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load transactions. Try again later.`
  String get transactionLoadFailed {
    return Intl.message(
      'Failed to load transactions. Try again later.',
      name: 'transactionLoadFailed',
      desc: '',
      args: [],
    );
  }

  /// `Transaction details are unavailable`
  String get transactionNoAsset {
    return Intl.message(
      'Transaction details are unavailable',
      name: 'transactionNoAsset',
      desc: '',
      args: [],
    );
  }

  /// `Received`
  String get transactionIncoming {
    return Intl.message(
      'Received',
      name: 'transactionIncoming',
      desc: '',
      args: [],
    );
  }

  /// `Sent`
  String get transactionOutgoing {
    return Intl.message(
      'Sent',
      name: 'transactionOutgoing',
      desc: '',
      args: [],
    );
  }

  /// `Self transfer`
  String get transactionSelfTransfer {
    return Intl.message(
      'Self transfer',
      name: 'transactionSelfTransfer',
      desc: '',
      args: [],
    );
  }

  /// `Transaction`
  String get transactionUnknownDirection {
    return Intl.message(
      'Transaction',
      name: 'transactionUnknownDirection',
      desc: '',
      args: [],
    );
  }

  /// `Success`
  String get transactionStatusSuccess {
    return Intl.message(
      'Success',
      name: 'transactionStatusSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed`
  String get transactionStatusFailed {
    return Intl.message(
      'Failed',
      name: 'transactionStatusFailed',
      desc: '',
      args: [],
    );
  }

  /// `Pending`
  String get transactionStatusPending {
    return Intl.message(
      'Pending',
      name: 'transactionStatusPending',
      desc: '',
      args: [],
    );
  }

  /// `Unknown`
  String get transactionStatusUnknown {
    return Intl.message(
      'Unknown',
      name: 'transactionStatusUnknown',
      desc: '',
      args: [],
    );
  }

  /// `Local`
  String get transactionSourceLocal {
    return Intl.message(
      'Local',
      name: 'transactionSourceLocal',
      desc: '',
      args: [],
    );
  }

  /// `On-chain`
  String get transactionSourceRemote {
    return Intl.message(
      'On-chain',
      name: 'transactionSourceRemote',
      desc: '',
      args: [],
    );
  }

  /// `From`
  String get transactionFrom {
    return Intl.message(
      'From',
      name: 'transactionFrom',
      desc: '',
      args: [],
    );
  }

  /// `To`
  String get transactionTo {
    return Intl.message(
      'To',
      name: 'transactionTo',
      desc: '',
      args: [],
    );
  }

  /// `Unknown time`
  String get transactionTimeUnknown {
    return Intl.message(
      'Unknown time',
      name: 'transactionTimeUnknown',
      desc: '',
      args: [],
    );
  }

  /// `View explorer`
  String get openBlockExplorer {
    return Intl.message(
      'View explorer',
      name: 'openBlockExplorer',
      desc: '',
      args: [],
    );
  }

  /// `Block explorer`
  String get blockExplorer {
    return Intl.message(
      'Block explorer',
      name: 'blockExplorer',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get blockExplorerBack {
    return Intl.message(
      'Back',
      name: 'blockExplorerBack',
      desc: '',
      args: [],
    );
  }

  /// `Forward`
  String get blockExplorerForward {
    return Intl.message(
      'Forward',
      name: 'blockExplorerForward',
      desc: '',
      args: [],
    );
  }

  /// `Open externally`
  String get openInExternalBrowser {
    return Intl.message(
      'Open externally',
      name: 'openInExternalBrowser',
      desc: '',
      args: [],
    );
  }

  /// `Copy link`
  String get copyLink {
    return Intl.message(
      'Copy link',
      name: 'copyLink',
      desc: '',
      args: [],
    );
  }

  /// `More`
  String get more {
    return Intl.message(
      'More',
      name: 'more',
      desc: '',
      args: [],
    );
  }

  /// `Explorer is unavailable for this network`
  String get blockExplorerUnavailable {
    return Intl.message(
      'Explorer is unavailable for this network',
      name: 'blockExplorerUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Unable to open block explorer`
  String get blockExplorerOpenFailed {
    return Intl.message(
      'Unable to open block explorer',
      name: 'blockExplorerOpenFailed',
      desc: '',
      args: [],
    );
  }

  /// `Copy hash`
  String get copyHash {
    return Intl.message(
      'Copy hash',
      name: 'copyHash',
      desc: '',
      args: [],
    );
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
    return Intl.message(
      'Copied',
      name: 'copied',
      desc: '',
      args: [],
    );
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

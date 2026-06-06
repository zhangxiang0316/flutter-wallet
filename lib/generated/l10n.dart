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
    final name =
        (locale.countryCode?.isEmpty ?? false)
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

  /// `Create or import a wallet`
  String get walletEmptyTitle {
    return Intl.message(
      'Create or import a wallet',
      name: 'walletEmptyTitle',
      desc: '',
      args: [],
    );
  }

  /// `This first version supports address management and multi-asset on-chain balance lookup for BNB Smart Chain and TRON.`
  String get walletEmptySubtitle {
    return Intl.message(
      'This first version supports address management and multi-asset on-chain balance lookup for BNB Smart Chain and TRON.',
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

  /// `This version stores private keys locally and is only suitable for testing. Do not import wallets with real assets.`
  String get securityNoticeDetail {
    return Intl.message(
      'This version stores private keys locally and is only suitable for testing. Do not import wallets with real assets.',
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

  /// `Import`
  String get confirmImport {
    return Intl.message('Import', name: 'confirmImport', desc: '', args: []);
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

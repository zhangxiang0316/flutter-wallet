// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(amount) => "Up to ${amount}";

  static String m1(symbol) =>
      "The network fee is paid in ${symbol}. Make sure this wallet has enough balance.";

  static String m2(name) =>
      "Remove \"${name}\"? The wallet data saved on this device will be deleted.";

  static String m3(symbol) => "Transfer ${symbol}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "addWallet": MessageLookupByLibrary.simpleMessage("Add wallet"),
    "appName": MessageLookupByLibrary.simpleMessage("沐晨钱包"),
    "availableBalance": MessageLookupByLibrary.simpleMessage(
      "Available balance",
    ),
    "backToWallet": MessageLookupByLibrary.simpleMessage("Back to wallet"),
    "balanceLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Some balance lookups failed",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "confirmImport": MessageLookupByLibrary.simpleMessage("Import"),
    "confirmTransfer": MessageLookupByLibrary.simpleMessage("Transfer"),
    "confirmWalletPassword": MessageLookupByLibrary.simpleMessage(
      "Confirm wallet password",
    ),
    "copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "copyHash": MessageLookupByLibrary.simpleMessage("Copy hash"),
    "copyWalletAddress": MessageLookupByLibrary.simpleMessage(
      "Copy wallet address",
    ),
    "createWallet": MessageLookupByLibrary.simpleMessage("Create wallet"),
    "email": MessageLookupByLibrary.simpleMessage("email"),
    "encryptWallet": MessageLookupByLibrary.simpleMessage("Encrypt wallet"),
    "estimatedNetworkFee": MessageLookupByLibrary.simpleMessage(
      "Estimated network fee",
    ),
    "feeEstimating": MessageLookupByLibrary.simpleMessage("Estimating fee..."),
    "feeFallback": m0,
    "feeUnavailable": MessageLookupByLibrary.simpleMessage(
      "Fee estimate is unavailable. Try again later.",
    ),
    "importPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Import private key",
    ),
    "importWallet": MessageLookupByLibrary.simpleMessage("Import wallet"),
    "invalidPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Invalid private key",
    ),
    "invalidWalletPassword": MessageLookupByLibrary.simpleMessage(
      "Incorrect wallet password",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
    "login": MessageLookupByLibrary.simpleMessage("login"),
    "networkFee": MessageLookupByLibrary.simpleMessage("Network fee"),
    "networkFeeAsset": m1,
    "phone": MessageLookupByLibrary.simpleMessage("phone"),
    "primaryMultiChainWallet": MessageLookupByLibrary.simpleMessage(
      "EVM / TRX multi-chain wallet",
    ),
    "privateKeyHint": MessageLookupByLibrary.simpleMessage(
      "Enter a 64-character hex private key, optionally prefixed with 0x",
    ),
    "recipientAddress": MessageLookupByLibrary.simpleMessage(
      "Recipient address",
    ),
    "refreshBalance": MessageLookupByLibrary.simpleMessage("Refresh"),
    "removeWallet": MessageLookupByLibrary.simpleMessage("Remove wallet"),
    "removeWalletConfirmMessage": m2,
    "securityNotice": MessageLookupByLibrary.simpleMessage("Security notice"),
    "securityNoticeDetail": MessageLookupByLibrary.simpleMessage(
      "Private keys are encrypted with your wallet password and saved in secure device storage. Keep the password safe; this is not hardware-wallet grade security.",
    ),
    "switchWallet": MessageLookupByLibrary.simpleMessage("Switch wallet"),
    "totalAssets": MessageLookupByLibrary.simpleMessage("Total assets"),
    "transactionHash": MessageLookupByLibrary.simpleMessage("Transaction hash"),
    "transfer": MessageLookupByLibrary.simpleMessage("Transfer"),
    "transferAmount": MessageLookupByLibrary.simpleMessage("Amount"),
    "transferAsset": m3,
    "transferDetails": MessageLookupByLibrary.simpleMessage("Transfer details"),
    "transferFailed": MessageLookupByLibrary.simpleMessage(
      "Transfer failed. Check the address, amount, and on-chain balance.",
    ),
    "transferInputInvalid": MessageLookupByLibrary.simpleMessage(
      "Enter a valid recipient address and transfer amount",
    ),
    "transferSubmitted": MessageLookupByLibrary.simpleMessage(
      "Transaction submitted",
    ),
    "transferUnavailable": MessageLookupByLibrary.simpleMessage(
      "Transfer details are unavailable",
    ),
    "unlockWallet": MessageLookupByLibrary.simpleMessage("Unlock wallet"),
    "unlockWalletForTransfer": MessageLookupByLibrary.simpleMessage(
      "Enter the wallet password to unlock the local private key for this transaction.",
    ),
    "walletCreated": MessageLookupByLibrary.simpleMessage("Wallet created"),
    "walletEmptySubtitle": MessageLookupByLibrary.simpleMessage(
      "Supports address management and multi-asset on-chain balance lookup for BNB Smart Chain, Ethereum, X Layer, and TRON.",
    ),
    "walletEmptyTitle": MessageLookupByLibrary.simpleMessage(
      "Create or import a wallet",
    ),
    "walletImported": MessageLookupByLibrary.simpleMessage("Import successful"),
    "walletPassword": MessageLookupByLibrary.simpleMessage("Wallet password"),
    "walletPasswordHint": MessageLookupByLibrary.simpleMessage(
      "At least 6 characters. Used to encrypt local private keys and unlock transfers.",
    ),
    "walletPasswordMismatch": MessageLookupByLibrary.simpleMessage(
      "Wallet passwords do not match",
    ),
    "walletPasswordRequired": MessageLookupByLibrary.simpleMessage(
      "Enter the wallet password",
    ),
    "walletPasswordTooShort": MessageLookupByLibrary.simpleMessage(
      "Wallet password must be at least 6 characters",
    ),
    "walletRemoved": MessageLookupByLibrary.simpleMessage("Wallet removed"),
    "walletSecretMissing": MessageLookupByLibrary.simpleMessage(
      "Encrypted private key was not found for this wallet",
    ),
    "walletSecurityMigrated": MessageLookupByLibrary.simpleMessage(
      "Wallet private key encrypted",
    ),
    "walletSecurityMigrationFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to encrypt wallet private key. Try again.",
    ),
    "walletSecurityUpgrade": MessageLookupByLibrary.simpleMessage(
      "Upgrade wallet security",
    ),
  };
}

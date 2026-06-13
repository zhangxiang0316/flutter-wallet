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

  static String m2(symbol) => "Receive ${symbol}";

  static String m3(symbol) =>
      "Remove \"${symbol}\"? The home page will no longer query this asset balance.";

  static String m4(name) =>
      "Remove \"${name}\"? Assets on this custom network will no longer be queried.";

  static String m5(name) =>
      "Remove \"${name}\"? The wallet data saved on this device will be deleted.";

  static String m6(symbol) => "Transfer ${symbol}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "addCustomAsset": MessageLookupByLibrary.simpleMessage("Add asset"),
        "addNetwork": MessageLookupByLibrary.simpleMessage("Add network"),
        "addWallet": MessageLookupByLibrary.simpleMessage("Add wallet"),
        "appName": MessageLookupByLibrary.simpleMessage("沐晨钱包"),
        "assetVisibility":
            MessageLookupByLibrary.simpleMessage("Asset display"),
        "assetVisibilityTip": MessageLookupByLibrary.simpleMessage(
            "Turn an asset off to hide it from the home balance list and valuation. On-chain balances are not deleted and can be shown again anytime."),
        "authenticateToUnlock": MessageLookupByLibrary.simpleMessage(
            "Authenticate to view sensitive information"),
        "availableBalance":
            MessageLookupByLibrary.simpleMessage("Available balance"),
        "backToWallet": MessageLookupByLibrary.simpleMessage("Back to wallet"),
        "backupMnemonic":
            MessageLookupByLibrary.simpleMessage("Back up mnemonic"),
        "backupMnemonicTip": MessageLookupByLibrary.simpleMessage(
            "Write these words down in order and keep them offline. Anyone with these words can control your assets."),
        "balanceLoadFailed":
            MessageLookupByLibrary.simpleMessage("Some balance lookups failed"),
        "biometricAuthFailed": MessageLookupByLibrary.simpleMessage(
            "Biometric authentication failed, please use password"),
        "biometricAuthTitle":
            MessageLookupByLibrary.simpleMessage("Biometric Authentication"),
        "blockExplorer": MessageLookupByLibrary.simpleMessage("Block explorer"),
        "blockExplorerBack": MessageLookupByLibrary.simpleMessage("Back"),
        "blockExplorerForward": MessageLookupByLibrary.simpleMessage("Forward"),
        "blockExplorerOpenFailed": MessageLookupByLibrary.simpleMessage(
            "Unable to open block explorer"),
        "blockExplorerUnavailable": MessageLookupByLibrary.simpleMessage(
            "Explorer is unavailable for this network"),
        "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "confirmImport": MessageLookupByLibrary.simpleMessage("Import"),
        "confirmTransfer": MessageLookupByLibrary.simpleMessage("Transfer"),
        "confirmWalletPassword":
            MessageLookupByLibrary.simpleMessage("Confirm wallet password"),
        "copied": MessageLookupByLibrary.simpleMessage("Copied"),
        "copyHash": MessageLookupByLibrary.simpleMessage("Copy hash"),
        "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
        "copyReceiveAddress":
            MessageLookupByLibrary.simpleMessage("Copy address"),
        "copyWalletAddress":
            MessageLookupByLibrary.simpleMessage("Copy wallet address"),
        "createWallet": MessageLookupByLibrary.simpleMessage("Create wallet"),
        "customAssetAdded": MessageLookupByLibrary.simpleMessage("Asset added"),
        "customAssetContractAddress":
            MessageLookupByLibrary.simpleMessage("Contract address"),
        "customAssetContractHint": MessageLookupByLibrary.simpleMessage(
            "Enter the token contract or mint address on this chain"),
        "customAssetDecimals": MessageLookupByLibrary.simpleMessage("Decimals"),
        "customAssetDuplicate":
            MessageLookupByLibrary.simpleMessage("This asset already exists"),
        "customAssetInvalid": MessageLookupByLibrary.simpleMessage(
            "Check the contract address, symbol, name, and decimals"),
        "customAssetMetadataUnavailable": MessageLookupByLibrary.simpleMessage(
            "Token info is unavailable. Fill it in manually."),
        "customAssetName": MessageLookupByLibrary.simpleMessage("Name"),
        "customAssetSymbol": MessageLookupByLibrary.simpleMessage("Symbol"),
        "editNetwork": MessageLookupByLibrary.simpleMessage("Edit network"),
        "editWalletName":
            MessageLookupByLibrary.simpleMessage("Edit wallet name"),
        "email": MessageLookupByLibrary.simpleMessage("email"),
        "encryptWallet": MessageLookupByLibrary.simpleMessage("Encrypt wallet"),
        "estimatedNetworkFee":
            MessageLookupByLibrary.simpleMessage("Estimated network fee"),
        "feeEstimating":
            MessageLookupByLibrary.simpleMessage("Estimating fee..."),
        "feeFallback": m0,
        "feeUnavailable": MessageLookupByLibrary.simpleMessage(
            "Fee estimate is unavailable. Try again later."),
        "fetchTokenInfo":
            MessageLookupByLibrary.simpleMessage("Detect token info"),
        "importMnemonic":
            MessageLookupByLibrary.simpleMessage("Import mnemonic"),
        "importPrivateKey":
            MessageLookupByLibrary.simpleMessage("Import private key"),
        "importWallet": MessageLookupByLibrary.simpleMessage("Import wallet"),
        "invalidMnemonic":
            MessageLookupByLibrary.simpleMessage("Invalid mnemonic"),
        "invalidPrivateKey":
            MessageLookupByLibrary.simpleMessage("Invalid private key"),
        "invalidWalletPassword":
            MessageLookupByLibrary.simpleMessage("Incorrect wallet password"),
        "language": MessageLookupByLibrary.simpleMessage("Language"),
        "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
        "login": MessageLookupByLibrary.simpleMessage("login"),
        "mnemonic": MessageLookupByLibrary.simpleMessage("Mnemonic"),
        "mnemonicBackupConfirm": MessageLookupByLibrary.simpleMessage(
            "I have backed up the mnemonic"),
        "mnemonicHint": MessageLookupByLibrary.simpleMessage(
            "Enter 12 English words separated by spaces"),
        "more": MessageLookupByLibrary.simpleMessage("More"),
        "networkAdded": MessageLookupByLibrary.simpleMessage("Network added"),
        "networkChainId": MessageLookupByLibrary.simpleMessage("Chain ID"),
        "networkDuplicate":
            MessageLookupByLibrary.simpleMessage("This network already exists"),
        "networkExplorerApiKey":
            MessageLookupByLibrary.simpleMessage("Explorer API key"),
        "networkExplorerApiUrl":
            MessageLookupByLibrary.simpleMessage("Explorer API URL"),
        "networkExplorerApiUrlHelper": MessageLookupByLibrary.simpleMessage(
            "Used for EVM transaction history. Supports Etherscan-compatible APIs."),
        "networkFee": MessageLookupByLibrary.simpleMessage("Network fee"),
        "networkFeeAsset": m1,
        "networkInvalid": MessageLookupByLibrary.simpleMessage(
            "Check the network name, symbol, chain ID, and RPC URL"),
        "networkManagement": MessageLookupByLibrary.simpleMessage("Networks"),
        "networkManagementTip": MessageLookupByLibrary.simpleMessage(
            "Add EVM-compatible networks only. Custom networks reuse the wallet EVM address and support native coin and token balance lookup."),
        "networkName": MessageLookupByLibrary.simpleMessage("Network name"),
        "networkRemoved":
            MessageLookupByLibrary.simpleMessage("Network removed"),
        "networkRpcMismatch":
            MessageLookupByLibrary.simpleMessage("RPC chain ID does not match"),
        "networkRpcUnavailable":
            MessageLookupByLibrary.simpleMessage("RPC is unavailable"),
        "networkRpcUrl": MessageLookupByLibrary.simpleMessage("RPC URL"),
        "networkRpcUrlHelper": MessageLookupByLibrary.simpleMessage(
            "One RPC URL per line, or separate them with commas"),
        "networkSymbol": MessageLookupByLibrary.simpleMessage("Native symbol"),
        "networkUpdated":
            MessageLookupByLibrary.simpleMessage("Network updated"),
        "openBlockExplorer":
            MessageLookupByLibrary.simpleMessage("View explorer"),
        "openInExternalBrowser":
            MessageLookupByLibrary.simpleMessage("Open externally"),
        "orUsePassword":
            MessageLookupByLibrary.simpleMessage("Or use password"),
        "phone": MessageLookupByLibrary.simpleMessage("phone"),
        "primaryMultiChainWallet": MessageLookupByLibrary.simpleMessage(
            "EVM / SOL / TRX multi-chain wallet"),
        "privateKeyHint": MessageLookupByLibrary.simpleMessage(
            "Enter a 64-character hex private key, optionally prefixed with 0x"),
        "receive": MessageLookupByLibrary.simpleMessage("Receive"),
        "receiveAddress":
            MessageLookupByLibrary.simpleMessage("Receive address"),
        "receiveAddressEmpty": MessageLookupByLibrary.simpleMessage(
            "This wallet does not have an address for this network"),
        "receiveAsset": m2,
        "receiveQrTip": MessageLookupByLibrary.simpleMessage(
            "Only send this asset on the selected network."),
        "receiveQrTitle":
            MessageLookupByLibrary.simpleMessage("Scan to receive"),
        "receiveUnavailable": MessageLookupByLibrary.simpleMessage(
            "Receive details are unavailable"),
        "recipientAddress":
            MessageLookupByLibrary.simpleMessage("Recipient address"),
        "refreshBalance": MessageLookupByLibrary.simpleMessage("Refresh"),
        "removeCustomAsset":
            MessageLookupByLibrary.simpleMessage("Remove asset"),
        "removeCustomAssetConfirmMessage": m3,
        "removeNetwork": MessageLookupByLibrary.simpleMessage("Remove network"),
        "removeNetworkConfirm": m4,
        "removeWallet": MessageLookupByLibrary.simpleMessage("Remove wallet"),
        "removeWalletConfirmMessage": m5,
        "saveNetwork": MessageLookupByLibrary.simpleMessage("Save network"),
        "saveWalletName": MessageLookupByLibrary.simpleMessage("Save name"),
        "scanCameraError": MessageLookupByLibrary.simpleMessage(
            "Camera is unavailable. Check camera permission and try again."),
        "scanNoAddressFound": MessageLookupByLibrary.simpleMessage(
            "No wallet address found in this QR code"),
        "scanRecipientAddress":
            MessageLookupByLibrary.simpleMessage("Scan address"),
        "scanRecipientAddressTip": MessageLookupByLibrary.simpleMessage(
            "Align the QR code inside the frame to fill the recipient address."),
        "scanSwitchCamera":
            MessageLookupByLibrary.simpleMessage("Switch camera"),
        "scanToggleFlash": MessageLookupByLibrary.simpleMessage("Toggle flash"),
        "screenshotNotAllowed": MessageLookupByLibrary.simpleMessage(
            "Screenshots are not allowed on this page for your security"),
        "screenshotProtectionEnabled": MessageLookupByLibrary.simpleMessage(
            "🔒 Screenshot protection enabled for your security"),
        "securityNotice":
            MessageLookupByLibrary.simpleMessage("Security notice"),
        "securityNoticeDetail": MessageLookupByLibrary.simpleMessage(
            "Private keys are encrypted with your wallet password and saved in secure device storage. Keep the password safe; this is not hardware-wallet grade security."),
        "selectReceiveAsset":
            MessageLookupByLibrary.simpleMessage("Select asset"),
        "selectReceiveChain":
            MessageLookupByLibrary.simpleMessage("Select network"),
        "selectTransferAsset":
            MessageLookupByLibrary.simpleMessage("Transfer asset"),
        "selectTransferChain":
            MessageLookupByLibrary.simpleMessage("Transfer network"),
        "settings": MessageLookupByLibrary.simpleMessage("Settings"),
        "splashLoading": MessageLookupByLibrary.simpleMessage("Opening wallet"),
        "splashTagline":
            MessageLookupByLibrary.simpleMessage("Secure multi-chain assets"),
        "switchWallet": MessageLookupByLibrary.simpleMessage("Switch wallet"),
        "theme": MessageLookupByLibrary.simpleMessage("Theme"),
        "themeDark": MessageLookupByLibrary.simpleMessage("Dark"),
        "themeLight": MessageLookupByLibrary.simpleMessage("Light"),
        "themeSystem": MessageLookupByLibrary.simpleMessage("System"),
        "totalAssets": MessageLookupByLibrary.simpleMessage("Total assets"),
        "transactionFrom": MessageLookupByLibrary.simpleMessage("From"),
        "transactionHash":
            MessageLookupByLibrary.simpleMessage("Transaction hash"),
        "transactionHistory":
            MessageLookupByLibrary.simpleMessage("Transactions"),
        "transactionHistoryEmpty":
            MessageLookupByLibrary.simpleMessage("No transactions"),
        "transactionHistoryExplorerHint": MessageLookupByLibrary.simpleMessage(
            "No in-app records found. View this address in a block explorer."),
        "transactionIncoming": MessageLookupByLibrary.simpleMessage("Received"),
        "transactionLoadFailed": MessageLookupByLibrary.simpleMessage(
            "Failed to load transactions. Try again later."),
        "transactionNoAsset": MessageLookupByLibrary.simpleMessage(
            "Transaction details are unavailable"),
        "transactionOutgoing": MessageLookupByLibrary.simpleMessage("Sent"),
        "transactionSelfTransfer":
            MessageLookupByLibrary.simpleMessage("Self transfer"),
        "transactionSourceLocal": MessageLookupByLibrary.simpleMessage("Local"),
        "transactionSourceRemote":
            MessageLookupByLibrary.simpleMessage("On-chain"),
        "transactionStatusFailed":
            MessageLookupByLibrary.simpleMessage("Failed"),
        "transactionStatusPending":
            MessageLookupByLibrary.simpleMessage("Pending"),
        "transactionStatusSuccess":
            MessageLookupByLibrary.simpleMessage("Success"),
        "transactionStatusUnknown":
            MessageLookupByLibrary.simpleMessage("Unknown"),
        "transactionTimeUnknown":
            MessageLookupByLibrary.simpleMessage("Unknown time"),
        "transactionTo": MessageLookupByLibrary.simpleMessage("To"),
        "transactionUnknownDirection":
            MessageLookupByLibrary.simpleMessage("Transaction"),
        "transfer": MessageLookupByLibrary.simpleMessage("Transfer"),
        "transferAmount": MessageLookupByLibrary.simpleMessage("Amount"),
        "transferAsset": m6,
        "transferDetails":
            MessageLookupByLibrary.simpleMessage("Transfer details"),
        "transferFailed": MessageLookupByLibrary.simpleMessage(
            "Transfer failed. Check the address, amount, and on-chain balance."),
        "transferFromAddress":
            MessageLookupByLibrary.simpleMessage("From address"),
        "transferInputInvalid": MessageLookupByLibrary.simpleMessage(
            "Enter a valid recipient address and transfer amount"),
        "transferSubmitted":
            MessageLookupByLibrary.simpleMessage("Transaction submitted"),
        "transferUnavailable": MessageLookupByLibrary.simpleMessage(
            "Transfer details are unavailable"),
        "unlockToView": MessageLookupByLibrary.simpleMessage(
            "Unlock with wallet password to view"),
        "unlockWallet": MessageLookupByLibrary.simpleMessage("Unlock wallet"),
        "unlockWalletForTransfer": MessageLookupByLibrary.simpleMessage(
            "Enter the wallet password to unlock the local private key for this transaction."),
        "useBiometric": MessageLookupByLibrary.simpleMessage("Use biometric"),
        "viewMnemonic": MessageLookupByLibrary.simpleMessage("View mnemonic"),
        "viewPrivateKey":
            MessageLookupByLibrary.simpleMessage("View private key"),
        "walletAddresses":
            MessageLookupByLibrary.simpleMessage("Chain addresses"),
        "walletCreated": MessageLookupByLibrary.simpleMessage("Wallet created"),
        "walletDetails": MessageLookupByLibrary.simpleMessage("Wallet details"),
        "walletEmptySubtitle": MessageLookupByLibrary.simpleMessage(
            "Supports address management and multi-asset on-chain balance lookup for BNB Smart Chain, Ethereum, X Layer, Solana, and TRON."),
        "walletEmptyTitle":
            MessageLookupByLibrary.simpleMessage("Create or import a wallet"),
        "walletImported":
            MessageLookupByLibrary.simpleMessage("Import successful"),
        "walletName": MessageLookupByLibrary.simpleMessage("Wallet name"),
        "walletNameRequired":
            MessageLookupByLibrary.simpleMessage("Enter a wallet name"),
        "walletNameUpdated":
            MessageLookupByLibrary.simpleMessage("Wallet name updated"),
        "walletPassword":
            MessageLookupByLibrary.simpleMessage("Wallet password"),
        "walletPasswordHint": MessageLookupByLibrary.simpleMessage(
            "At least 6 characters. Used to encrypt local private keys and unlock transfers."),
        "walletPasswordMismatch": MessageLookupByLibrary.simpleMessage(
            "Wallet passwords do not match"),
        "walletPasswordRequired":
            MessageLookupByLibrary.simpleMessage("Enter the wallet password"),
        "walletPasswordTooShort": MessageLookupByLibrary.simpleMessage(
            "Wallet password must be at least 6 characters"),
        "walletRemoved": MessageLookupByLibrary.simpleMessage("Wallet removed"),
        "walletSecretMissing": MessageLookupByLibrary.simpleMessage(
            "Encrypted private key was not found for this wallet"),
        "walletSecrets": MessageLookupByLibrary.simpleMessage("Wallet secrets"),
        "walletSecurityMigrated": MessageLookupByLibrary.simpleMessage(
            "Wallet private key encrypted"),
        "walletSecurityMigrationFailed": MessageLookupByLibrary.simpleMessage(
            "Failed to encrypt wallet private key. Try again."),
        "walletSecurityUpgrade":
            MessageLookupByLibrary.simpleMessage("Upgrade wallet security"),
        "walletSolanaAddressUpgrade":
            MessageLookupByLibrary.simpleMessage("Complete Solana Address"),
        "walletSolanaAddressUpgradeAction":
            MessageLookupByLibrary.simpleMessage("Complete Address"),
        "walletSolanaAddressUpgradeDetail": MessageLookupByLibrary.simpleMessage(
            "This wallet was created before Solana support. Enter the wallet password to unlock the local private key and derive the Solana address."),
        "walletSolanaAddressUpgradeFailed":
            MessageLookupByLibrary.simpleMessage(
                "Solana address completion failed. Please try again."),
        "walletSolanaAddressUpgraded":
            MessageLookupByLibrary.simpleMessage("Solana address completed")
      };
}

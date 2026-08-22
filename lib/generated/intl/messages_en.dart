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

  static String m0(network) => "${network} network fee estimate";

  static String m1(amount) => "Up to ${amount}";

  static String m2(index) => "Word #${index}";

  static String m3(network, symbol) =>
      "${network} network fees are paid in ${symbol}.";

  static String m4(ms) => "Backup available · ${ms} ms";

  static String m5(ms) => "${ms} ms";

  static String m6(current, target) =>
      "This request is for ${target}. Continuing will switch from ${current}.";

  static String m7(asset) => "The requested asset is unavailable: ${asset}";

  static String m8(current, target) =>
      "This request uses ${target}. Continuing will switch from ${current}.";

  static String m9(network) =>
      "The requested network is unavailable: ${network}";

  static String m10(network) =>
      "This QR code contains only an address. It will be used on ${network}.";

  static String m11(symbol) => "Receive ${symbol}";

  static String m12(network) =>
      "This QR code is for ${network}. Verify the network before sending.";

  static String m13(name) => "Remove \"${name}\" from the address book?";

  static String m14(symbol) =>
      "Remove \"${symbol}\"? The home page will no longer query this asset balance.";

  static String m15(name) =>
      "Remove \"${name}\"? Assets on this custom network will no longer be queried.";

  static String m16(name) =>
      "Remove \"${name}\"? The wallet data saved on this device will be deleted.";

  static String m17(seconds) => "Hides in ${seconds}s";

  static String m18(seconds) => "Copied. Clipboard will clear in ${seconds}s";

  static String m19(count) => "${count} networks";

  static String m20(symbol) => "Transfer ${symbol}";

  static String m21(symbol) => "Insufficient ${symbol} balance";

  static String m22(symbol) => "Insufficient ${symbol} to pay the network fee";

  static String m23(network) =>
      "EVM addresses can be reused across networks. Confirm the recipient expects funds on ${network}.";

  static String m24(percentage) =>
      "The network fee is ${percentage}% of the transfer value, which is unusually high.";

  static String m25(percentage) =>
      "You are transferring ${percentage}% of this asset balance.";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "addAddressBookEntry":
            MessageLookupByLibrary.simpleMessage("Add contact"),
        "addCustomAsset": MessageLookupByLibrary.simpleMessage("Add asset"),
        "addNetwork": MessageLookupByLibrary.simpleMessage("Add network"),
        "addWallet": MessageLookupByLibrary.simpleMessage("Add wallet"),
        "addressBook": MessageLookupByLibrary.simpleMessage("Address book"),
        "addressBookTip": MessageLookupByLibrary.simpleMessage(
            "Save trusted recipient addresses by network. Transfer pages can pick contacts from the current network only."),
        "appName": MessageLookupByLibrary.simpleMessage("沐晨钱包"),
        "asset": MessageLookupByLibrary.simpleMessage("Asset"),
        "assetVisibility":
            MessageLookupByLibrary.simpleMessage("Asset display"),
        "assetVisibilityTip": MessageLookupByLibrary.simpleMessage(
            "Turn an asset off to hide it from the home balance list and valuation. On-chain balances are not deleted and can be shown again anytime."),
        "authenticateToUnlock": MessageLookupByLibrary.simpleMessage(
            "Authenticate to view sensitive information"),
        "availableBalance":
            MessageLookupByLibrary.simpleMessage("Available balance"),
        "backToMnemonic": MessageLookupByLibrary.simpleMessage("Back"),
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
        "blockNumber": MessageLookupByLibrary.simpleMessage("Block number"),
        "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "chooseFromAddressBook":
            MessageLookupByLibrary.simpleMessage("Choose from address book"),
        "confirmImport": MessageLookupByLibrary.simpleMessage("Import"),
        "confirmMnemonicBackup":
            MessageLookupByLibrary.simpleMessage("Confirm mnemonic backup"),
        "confirmMnemonicBackupTip": MessageLookupByLibrary.simpleMessage(
            "Enter the requested words to confirm you saved the mnemonic in the correct order."),
        "confirmTransfer": MessageLookupByLibrary.simpleMessage("Transfer"),
        "confirmWalletPassword":
            MessageLookupByLibrary.simpleMessage("Confirm wallet password"),
        "contactAddress":
            MessageLookupByLibrary.simpleMessage("Wallet address"),
        "contactInvalid": MessageLookupByLibrary.simpleMessage(
            "Check the contact name, network, and address"),
        "contactName": MessageLookupByLibrary.simpleMessage("Contact name"),
        "contactNameHint": MessageLookupByLibrary.simpleMessage(
            "Exchange, friend, or cold wallet"),
        "contactNote": MessageLookupByLibrary.simpleMessage("Note"),
        "contactNoteHint":
            MessageLookupByLibrary.simpleMessage("Optional label or reminder"),
        "contactRemoved":
            MessageLookupByLibrary.simpleMessage("Contact removed"),
        "contactSaved": MessageLookupByLibrary.simpleMessage("Contact saved"),
        "contractAddress":
            MessageLookupByLibrary.simpleMessage("Contract address"),
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
        "customAssetLogoUrl": MessageLookupByLibrary.simpleMessage("Logo URL"),
        "customAssetMergeOnHome": MessageLookupByLibrary.simpleMessage(
            "Merge with the same token on Home"),
        "customAssetMergeOnHomeTip": MessageLookupByLibrary.simpleMessage(
            "Enable only after verifying the contract. Assets are never merged by symbol automatically."),
        "customAssetMetadataUnavailable": MessageLookupByLibrary.simpleMessage(
            "Token info is unavailable. Fill it in manually."),
        "customAssetName": MessageLookupByLibrary.simpleMessage("Name"),
        "customAssetSymbol": MessageLookupByLibrary.simpleMessage("Symbol"),
        "editAddressBookEntry":
            MessageLookupByLibrary.simpleMessage("Edit contact"),
        "editNetwork": MessageLookupByLibrary.simpleMessage("Edit network"),
        "editWalletName":
            MessageLookupByLibrary.simpleMessage("Edit wallet name"),
        "email": MessageLookupByLibrary.simpleMessage("email"),
        "encryptWallet": MessageLookupByLibrary.simpleMessage("Encrypt wallet"),
        "estimatedNetworkFeeOnNetwork": m0,
        "feeEstimating":
            MessageLookupByLibrary.simpleMessage("Estimating fee..."),
        "feeFallback": m1,
        "feeUnavailable": MessageLookupByLibrary.simpleMessage(
            "Fee estimate is unavailable. Try again later."),
        "fetchTokenInfo":
            MessageLookupByLibrary.simpleMessage("Detect token info"),
        "getStarted": MessageLookupByLibrary.simpleMessage("Get Started"),
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
        "mnemonicBackedUp":
            MessageLookupByLibrary.simpleMessage("Mnemonic backup confirmed"),
        "mnemonicBackedUpStatus":
            MessageLookupByLibrary.simpleMessage("Backed up"),
        "mnemonicBackupConfirm": MessageLookupByLibrary.simpleMessage(
            "I have backed up the mnemonic"),
        "mnemonicBackupNext":
            MessageLookupByLibrary.simpleMessage("I wrote it down"),
        "mnemonicBackupVerifyFailed": MessageLookupByLibrary.simpleMessage(
            "Mnemonic words do not match. Check your backup and try again."),
        "mnemonicHint": MessageLookupByLibrary.simpleMessage(
            "Enter 12 English words separated by spaces"),
        "mnemonicNotBackedUpStatus":
            MessageLookupByLibrary.simpleMessage("Not backed up"),
        "mnemonicWordNumber": m2,
        "more": MessageLookupByLibrary.simpleMessage("More"),
        "nativeAsset": MessageLookupByLibrary.simpleMessage("Native asset"),
        "network": MessageLookupByLibrary.simpleMessage("Network"),
        "networkAdded": MessageLookupByLibrary.simpleMessage("Network added"),
        "networkChainId": MessageLookupByLibrary.simpleMessage("Chain ID"),
        "networkDistribution":
            MessageLookupByLibrary.simpleMessage("Network distribution"),
        "networkDuplicate":
            MessageLookupByLibrary.simpleMessage("This network already exists"),
        "networkErrorMessage": MessageLookupByLibrary.simpleMessage(
            "Network connection failed, please check your network settings"),
        "networkExplorerApiKey":
            MessageLookupByLibrary.simpleMessage("Explorer API key"),
        "networkExplorerApiUrl":
            MessageLookupByLibrary.simpleMessage("Explorer API URL"),
        "networkExplorerApiUrlHelper": MessageLookupByLibrary.simpleMessage(
            "Used for EVM transaction history. Supports Etherscan-compatible APIs."),
        "networkFee": MessageLookupByLibrary.simpleMessage("Network fee"),
        "networkFeeAssetOnNetwork": m3,
        "networkInvalid": MessageLookupByLibrary.simpleMessage(
            "Check the network name, symbol, chain ID, and RPC URL"),
        "networkManagement": MessageLookupByLibrary.simpleMessage("Networks"),
        "networkManagementTip": MessageLookupByLibrary.simpleMessage(
            "Add EVM-compatible networks only. Custom networks reuse the wallet EVM address and support native coin and token balance lookup."),
        "networkName": MessageLookupByLibrary.simpleMessage("Network name"),
        "networkRemoved":
            MessageLookupByLibrary.simpleMessage("Network removed"),
        "networkRpcBackupAvailable": MessageLookupByLibrary.simpleMessage(
            "Primary RPC is unavailable. A backup RPC is available."),
        "networkRpcBackupHint": m4,
        "networkRpcDown": MessageLookupByLibrary.simpleMessage("Unavailable"),
        "networkRpcLatency": m5,
        "networkRpcMismatch":
            MessageLookupByLibrary.simpleMessage("RPC chain ID does not match"),
        "networkRpcNotTested":
            MessageLookupByLibrary.simpleMessage("Not tested"),
        "networkRpcSwitch": MessageLookupByLibrary.simpleMessage("Switch"),
        "networkRpcSwitched":
            MessageLookupByLibrary.simpleMessage("Primary RPC switched"),
        "networkRpcTest": MessageLookupByLibrary.simpleMessage("Test"),
        "networkRpcTestAvailable":
            MessageLookupByLibrary.simpleMessage("Primary RPC is available"),
        "networkRpcTesting": MessageLookupByLibrary.simpleMessage("Testing"),
        "networkRpcUnavailable":
            MessageLookupByLibrary.simpleMessage("RPC is unavailable"),
        "networkRpcUrl": MessageLookupByLibrary.simpleMessage("RPC URL"),
        "networkRpcUrlHelper": MessageLookupByLibrary.simpleMessage(
            "One RPC URL per line, or separate them with commas"),
        "networkSymbol": MessageLookupByLibrary.simpleMessage("Native symbol"),
        "networkUpdated":
            MessageLookupByLibrary.simpleMessage("Network updated"),
        "next": MessageLookupByLibrary.simpleMessage("Next"),
        "noContacts": MessageLookupByLibrary.simpleMessage("No contacts yet"),
        "onboardingDesc1": MessageLookupByLibrary.simpleMessage(
            "Supports Ethereum, Solana, TRON and other mainstream blockchains, manage all assets in one wallet"),
        "onboardingDesc2": MessageLookupByLibrary.simpleMessage(
            "Private keys are encrypted and stored locally with screenshot protection, never uploaded to servers"),
        "onboardingDesc3": MessageLookupByLibrary.simpleMessage(
            "Support fingerprint and Face ID for quick access to private keys and mnemonics"),
        "onboardingDesc4": MessageLookupByLibrary.simpleMessage(
            "Clean interface design and smooth user experience make digital asset management easier"),
        "onboardingTitle1":
            MessageLookupByLibrary.simpleMessage("Multi-Chain Wallet"),
        "onboardingTitle2":
            MessageLookupByLibrary.simpleMessage("Secure & Reliable"),
        "onboardingTitle3":
            MessageLookupByLibrary.simpleMessage("Quick Unlock"),
        "onboardingTitle4":
            MessageLookupByLibrary.simpleMessage("Simple & Easy"),
        "openBlockExplorer":
            MessageLookupByLibrary.simpleMessage("View explorer"),
        "openInExternalBrowser":
            MessageLookupByLibrary.simpleMessage("Open externally"),
        "orUsePassword":
            MessageLookupByLibrary.simpleMessage("Or use password"),
        "partialNetworkError": MessageLookupByLibrary.simpleMessage(
            "Some network balances are temporarily unavailable. Totals include available networks only."),
        "passwordCache": MessageLookupByLibrary.simpleMessage("Password Cache"),
        "passwordCacheClearedOnExit": MessageLookupByLibrary.simpleMessage(
            "Cache is cleared automatically after app exit"),
        "passwordCacheDesc": MessageLookupByLibrary.simpleMessage(
            "Auto-use cached password after biometric authentication"),
        "passwordCacheDisabled":
            MessageLookupByLibrary.simpleMessage("Password cache disabled"),
        "passwordCacheEnabled":
            MessageLookupByLibrary.simpleMessage("Password cache enabled"),
        "passwordCacheExpiresAutomatically":
            MessageLookupByLibrary.simpleMessage(
                "Cache expires after the selected duration"),
        "passwordCacheExpiry":
            MessageLookupByLibrary.simpleMessage("Cache Expiry Time"),
        "passwordCacheExpiry1":
            MessageLookupByLibrary.simpleMessage("1 minute"),
        "passwordCacheExpiry10":
            MessageLookupByLibrary.simpleMessage("10 minutes"),
        "passwordCacheExpiry30":
            MessageLookupByLibrary.simpleMessage("30 minutes"),
        "passwordCacheExpiry5":
            MessageLookupByLibrary.simpleMessage("5 minutes (Recommended)"),
        "passwordCacheMemoryOnly": MessageLookupByLibrary.simpleMessage(
            "The password is only cached in memory"),
        "passwordCacheSecurityNoteTitle":
            MessageLookupByLibrary.simpleMessage("Security Notes"),
        "paymentRequestAmountOverwrite": MessageLookupByLibrary.simpleMessage(
            "The requested amount will replace the amount already entered."),
        "paymentRequestApply":
            MessageLookupByLibrary.simpleMessage("Use request"),
        "paymentRequestAssetSwitch": m6,
        "paymentRequestAssetUnavailable": m7,
        "paymentRequestConfirmTip": MessageLookupByLibrary.simpleMessage(
            "Nothing will be filled until you confirm these details."),
        "paymentRequestConfirmTitle":
            MessageLookupByLibrary.simpleMessage("Review payment request"),
        "paymentRequestInvalid": MessageLookupByLibrary.simpleMessage(
            "Unsupported or invalid payment QR code"),
        "paymentRequestMemoReferenceOnly": MessageLookupByLibrary.simpleMessage(
            "The memo is shown for reference and is not written to the blockchain."),
        "paymentRequestNetworkSwitch": m8,
        "paymentRequestNetworkUnavailable": m9,
        "paymentRequestPlainAddressNetwork": m10,
        "phone": MessageLookupByLibrary.simpleMessage("phone"),
        "popularTokens": MessageLookupByLibrary.simpleMessage("Popular tokens"),
        "primaryMultiChainWallet": MessageLookupByLibrary.simpleMessage(
            "EVM / SOL / TRX multi-chain wallet"),
        "privateKeyHint": MessageLookupByLibrary.simpleMessage(
            "Enter a 64-character hex private key, optionally prefixed with 0x"),
        "receive": MessageLookupByLibrary.simpleMessage("Receive"),
        "receiveAddress":
            MessageLookupByLibrary.simpleMessage("Receive address"),
        "receiveAddressEmpty": MessageLookupByLibrary.simpleMessage(
            "This wallet does not have an address for this network"),
        "receiveAmount": MessageLookupByLibrary.simpleMessage("Amount"),
        "receiveAmountHint": MessageLookupByLibrary.simpleMessage("Optional"),
        "receiveAmountInvalid": MessageLookupByLibrary.simpleMessage(
            "Enter a valid amount within the asset precision"),
        "receiveAsset": m11,
        "receiveMemo": MessageLookupByLibrary.simpleMessage("Memo"),
        "receiveMemoHint": MessageLookupByLibrary.simpleMessage(
            "Optional, up to 80 characters"),
        "receiveQrNetworkTip": m12,
        "receiveQrTitle":
            MessageLookupByLibrary.simpleMessage("Scan to receive"),
        "receiveRequestTip": MessageLookupByLibrary.simpleMessage(
            "Adding an amount or memo creates a network-aware payment request. Otherwise the QR code stays a plain address."),
        "receiveRequestTitle":
            MessageLookupByLibrary.simpleMessage("Payment request"),
        "receiveUnavailable": MessageLookupByLibrary.simpleMessage(
            "Receive details are unavailable"),
        "recipientAddress":
            MessageLookupByLibrary.simpleMessage("Recipient address"),
        "refreshBalance": MessageLookupByLibrary.simpleMessage("Refresh"),
        "removeContact": MessageLookupByLibrary.simpleMessage("Remove contact"),
        "removeContactConfirm": m13,
        "removeCustomAsset":
            MessageLookupByLibrary.simpleMessage("Remove asset"),
        "removeCustomAssetConfirmMessage": m14,
        "removeNetwork": MessageLookupByLibrary.simpleMessage("Remove network"),
        "removeNetworkConfirm": m15,
        "removeWallet": MessageLookupByLibrary.simpleMessage("Remove wallet"),
        "removeWalletConfirmMessage": m16,
        "retry": MessageLookupByLibrary.simpleMessage("Retry"),
        "reviewTransfer":
            MessageLookupByLibrary.simpleMessage("Review transfer"),
        "saveContact": MessageLookupByLibrary.simpleMessage("Save contact"),
        "saveNetwork": MessageLookupByLibrary.simpleMessage("Save network"),
        "saveWalletName": MessageLookupByLibrary.simpleMessage("Save name"),
        "scanCameraError": MessageLookupByLibrary.simpleMessage(
            "Camera is unavailable. Check camera permission and try again."),
        "scanRecipientAddress":
            MessageLookupByLibrary.simpleMessage("Scan address"),
        "scanRecipientAddressTip": MessageLookupByLibrary.simpleMessage(
            "Align the QR code inside the frame, then review the network and payment details."),
        "scanSwitchCamera":
            MessageLookupByLibrary.simpleMessage("Switch camera"),
        "scanToggleFlash": MessageLookupByLibrary.simpleMessage("Toggle flash"),
        "screenshotNotAllowed": MessageLookupByLibrary.simpleMessage(
            "Screenshots are not allowed on this page for your security"),
        "screenshotProtectionEnabled": MessageLookupByLibrary.simpleMessage(
            "🔒 Screenshot protection enabled for your security"),
        "secretAutoHideCountdown": m17,
        "securityNotice":
            MessageLookupByLibrary.simpleMessage("Security notice"),
        "securityNoticeDetail": MessageLookupByLibrary.simpleMessage(
            "Private keys are encrypted with your wallet password and saved in secure device storage. Keep the password safe; this is not hardware-wallet grade security."),
        "securitySettings":
            MessageLookupByLibrary.simpleMessage("Security Settings"),
        "selectContact": MessageLookupByLibrary.simpleMessage("Select contact"),
        "selectReceiveAsset":
            MessageLookupByLibrary.simpleMessage("Select asset"),
        "selectReceiveChain":
            MessageLookupByLibrary.simpleMessage("Select network"),
        "selectTransferAsset":
            MessageLookupByLibrary.simpleMessage("Transfer asset"),
        "selectTransferChain":
            MessageLookupByLibrary.simpleMessage("Transfer network"),
        "sensitiveClipboardClearNotice": m18,
        "settings": MessageLookupByLibrary.simpleMessage("Settings"),
        "skip": MessageLookupByLibrary.simpleMessage("Skip"),
        "splashLoading": MessageLookupByLibrary.simpleMessage("Opening wallet"),
        "splashTagline":
            MessageLookupByLibrary.simpleMessage("Secure multi-chain assets"),
        "switchWallet": MessageLookupByLibrary.simpleMessage("Switch wallet"),
        "systemErrorMessage": MessageLookupByLibrary.simpleMessage(
            "Operation failed, please try again later"),
        "theme": MessageLookupByLibrary.simpleMessage("Theme"),
        "themeDark": MessageLookupByLibrary.simpleMessage("Dark"),
        "themeLight": MessageLookupByLibrary.simpleMessage("Light"),
        "themeSettings": MessageLookupByLibrary.simpleMessage("Theme Settings"),
        "themeSystem": MessageLookupByLibrary.simpleMessage("System"),
        "tokenAssets": MessageLookupByLibrary.simpleMessage("Tokens"),
        "tokenAssetsEmpty":
            MessageLookupByLibrary.simpleMessage("No assets yet"),
        "tokenContractAsset":
            MessageLookupByLibrary.simpleMessage("Token contract"),
        "tokenDetails": MessageLookupByLibrary.simpleMessage("Token details"),
        "tokenNetworkCount": m19,
        "totalAssets": MessageLookupByLibrary.simpleMessage("Total assets"),
        "totalTransferCost": MessageLookupByLibrary.simpleMessage("Total"),
        "transactionAddresses":
            MessageLookupByLibrary.simpleMessage("Addresses"),
        "transactionAmount": MessageLookupByLibrary.simpleMessage("Amount"),
        "transactionChainInfo":
            MessageLookupByLibrary.simpleMessage("Network details"),
        "transactionDetail":
            MessageLookupByLibrary.simpleMessage("Transaction details"),
        "transactionDirection":
            MessageLookupByLibrary.simpleMessage("Direction"),
        "transactionFrom": MessageLookupByLibrary.simpleMessage("From"),
        "transactionHash":
            MessageLookupByLibrary.simpleMessage("Transaction hash"),
        "transactionHistory":
            MessageLookupByLibrary.simpleMessage("Transactions"),
        "transactionHistoryApiKeyInvalid": MessageLookupByLibrary.simpleMessage(
            "Transaction history API key is invalid or lacks permission. Check the configuration."),
        "transactionHistoryApiKeyMissing": MessageLookupByLibrary.simpleMessage(
            "Transaction history API key is not configured. Check environment variables."),
        "transactionHistoryEmpty":
            MessageLookupByLibrary.simpleMessage("No transactions"),
        "transactionHistoryExplorerHint": MessageLookupByLibrary.simpleMessage(
            "No in-app records found. View this address in a block explorer."),
        "transactionHistoryNoRecords": MessageLookupByLibrary.simpleMessage(
            "No on-chain transactions yet"),
        "transactionHistoryProviderFailed": MessageLookupByLibrary.simpleMessage(
            "Transaction history provider is unavailable. Try again later or view the block explorer."),
        "transactionHistoryRateLimited": MessageLookupByLibrary.simpleMessage(
            "Transaction history API is rate limited. Try again later."),
        "transactionHistoryTimeout": MessageLookupByLibrary.simpleMessage(
            "Transaction history API timed out. Try again later."),
        "transactionIncoming": MessageLookupByLibrary.simpleMessage("Received"),
        "transactionLoadFailed": MessageLookupByLibrary.simpleMessage(
            "Failed to load transactions. Try again later."),
        "transactionLoadMore":
            MessageLookupByLibrary.simpleMessage("Load more"),
        "transactionLoadMoreFailed": MessageLookupByLibrary.simpleMessage(
            "Failed to load more transactions"),
        "transactionNoAsset": MessageLookupByLibrary.simpleMessage(
            "Transaction details are unavailable"),
        "transactionNoMoreRecords":
            MessageLookupByLibrary.simpleMessage("No more transactions"),
        "transactionOutgoing": MessageLookupByLibrary.simpleMessage("Sent"),
        "transactionOverview": MessageLookupByLibrary.simpleMessage("Overview"),
        "transactionRefreshStatus":
            MessageLookupByLibrary.simpleMessage("Refresh status"),
        "transactionSelfTransfer":
            MessageLookupByLibrary.simpleMessage("Self transfer"),
        "transactionSource": MessageLookupByLibrary.simpleMessage("Source"),
        "transactionSourceLocal": MessageLookupByLibrary.simpleMessage("Local"),
        "transactionSourceRemote":
            MessageLookupByLibrary.simpleMessage("On-chain"),
        "transactionStatus": MessageLookupByLibrary.simpleMessage("Status"),
        "transactionStatusFailed":
            MessageLookupByLibrary.simpleMessage("Failed"),
        "transactionStatusPending":
            MessageLookupByLibrary.simpleMessage("Pending"),
        "transactionStatusRefreshFailed": MessageLookupByLibrary.simpleMessage(
            "Failed to refresh transaction status"),
        "transactionStatusSuccess":
            MessageLookupByLibrary.simpleMessage("Success"),
        "transactionStatusUnknown":
            MessageLookupByLibrary.simpleMessage("Unknown"),
        "transactionSummary":
            MessageLookupByLibrary.simpleMessage("Transaction summary"),
        "transactionTime": MessageLookupByLibrary.simpleMessage("Time"),
        "transactionTimeUnknown":
            MessageLookupByLibrary.simpleMessage("Unknown time"),
        "transactionTo": MessageLookupByLibrary.simpleMessage("To"),
        "transactionUnknownDirection":
            MessageLookupByLibrary.simpleMessage("Transaction"),
        "transactionWalletAddress":
            MessageLookupByLibrary.simpleMessage("Wallet address"),
        "transfer": MessageLookupByLibrary.simpleMessage("Transfer"),
        "transferAmount": MessageLookupByLibrary.simpleMessage("Amount"),
        "transferAsset": m20,
        "transferBalanceInsufficient": m21,
        "transferBalanceRefreshFailed": MessageLookupByLibrary.simpleMessage(
            "Unable to refresh the latest on-chain balance. Try again."),
        "transferDetails":
            MessageLookupByLibrary.simpleMessage("Transfer details"),
        "transferFailed": MessageLookupByLibrary.simpleMessage(
            "Transfer failed. Check the address, amount, and on-chain balance."),
        "transferFeeRequired": MessageLookupByLibrary.simpleMessage(
            "Wait for the network fee estimate before continuing."),
        "transferFromAddress":
            MessageLookupByLibrary.simpleMessage("From address"),
        "transferInputInvalid": MessageLookupByLibrary.simpleMessage(
            "Enter a valid recipient address and transfer amount"),
        "transferMax": MessageLookupByLibrary.simpleMessage("Max"),
        "transferNativeFeeBalanceInsufficient": m22,
        "transferRiskBurnAddress": MessageLookupByLibrary.simpleMessage(
            "The recipient is a known burn or system address. Funds sent there are likely unrecoverable."),
        "transferRiskClipboardMismatch": MessageLookupByLibrary.simpleMessage(
            "Your clipboard contains a different address. Recheck that the recipient was not changed unexpectedly."),
        "transferRiskEvmNetworkConfirm": m23,
        "transferRiskFeeUnavailable": MessageLookupByLibrary.simpleMessage(
            "Network fee is not available yet. Confirm you still have enough native balance before continuing."),
        "transferRiskHighFee": m24,
        "transferRiskLargeAmount": m25,
        "transferRiskNewRecipient": MessageLookupByLibrary.simpleMessage(
            "This is the first transfer from this wallet on the selected network to this recipient."),
        "transferRiskSelfTransfer": MessageLookupByLibrary.simpleMessage(
            "The recipient is the same as your current wallet address."),
        "transferRiskTokenContract": MessageLookupByLibrary.simpleMessage(
            "The recipient matches this token contract address. Sending tokens to a contract address may permanently lose funds."),
        "transferSubmitted":
            MessageLookupByLibrary.simpleMessage("Transaction submitted"),
        "transferUnavailable": MessageLookupByLibrary.simpleMessage(
            "Transfer details are unavailable"),
        "unknownErrorMessage": MessageLookupByLibrary.simpleMessage(
            "Unknown error, please try again later"),
        "unlockToView": MessageLookupByLibrary.simpleMessage(
            "Unlock with wallet password to view"),
        "unlockWallet": MessageLookupByLibrary.simpleMessage("Unlock wallet"),
        "unlockWalletForTransfer": MessageLookupByLibrary.simpleMessage(
            "Enter the wallet password to unlock the local private key for this transaction."),
        "useBiometric": MessageLookupByLibrary.simpleMessage("Use biometric"),
        "validationErrorMessage": MessageLookupByLibrary.simpleMessage(
            "Invalid input, please check and try again"),
        "viewMnemonic": MessageLookupByLibrary.simpleMessage("View mnemonic"),
        "viewPrivateKey":
            MessageLookupByLibrary.simpleMessage("View private key"),
        "walletAddresses":
            MessageLookupByLibrary.simpleMessage("Chain addresses"),
        "walletCreated": MessageLookupByLibrary.simpleMessage("Wallet created"),
        "walletDetails": MessageLookupByLibrary.simpleMessage("Wallet details"),
        "walletEmptySubtitle": MessageLookupByLibrary.simpleMessage(
            "Supports address management and multi-asset on-chain balance lookup across EVM, Bitcoin, Solana, Sui, Aptos, and TRON networks."),
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
            MessageLookupByLibrary.simpleMessage("Complete Wallet Addresses"),
        "walletSolanaAddressUpgradeAction":
            MessageLookupByLibrary.simpleMessage("Complete Addresses"),
        "walletSolanaAddressUpgradeDetail": MessageLookupByLibrary.simpleMessage(
            "This wallet was created before support for all current networks. Enter the wallet password to derive the missing Solana, Sui, Aptos, or Bitcoin address."),
        "walletSolanaAddressUpgradeFailed":
            MessageLookupByLibrary.simpleMessage(
                "Wallet address completion failed. Please try again."),
        "walletSolanaAddressUpgraded":
            MessageLookupByLibrary.simpleMessage("Wallet addresses completed")
      };
}

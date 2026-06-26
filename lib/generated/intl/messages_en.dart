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

  static String m1(index) => "Word #${index}";

  static String m2(symbol) =>
      "The network fee is paid in ${symbol}. Make sure this wallet has enough balance.";

  static String m3(symbol) => "Receive ${symbol}";

  static String m4(name) => "Remove \"${name}\" from the address book?";

  static String m5(symbol) =>
      "Remove \"${symbol}\"? The home page will no longer query this asset balance.";

  static String m6(name) =>
      "Remove \"${name}\"? Assets on this custom network will no longer be queried.";

  static String m7(name) =>
      "Remove \"${name}\"? The wallet data saved on this device will be deleted.";

  static String m8(symbol) => "Transfer ${symbol}";

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
        "estimatedNetworkFee":
            MessageLookupByLibrary.simpleMessage("Estimated network fee"),
        "feeEstimating":
            MessageLookupByLibrary.simpleMessage("Estimating fee..."),
        "feeFallback": m0,
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
        "mnemonicWordNumber": m1,
        "more": MessageLookupByLibrary.simpleMessage("More"),
        "network": MessageLookupByLibrary.simpleMessage("Network"),
        "networkAdded": MessageLookupByLibrary.simpleMessage("Network added"),
        "networkChainId": MessageLookupByLibrary.simpleMessage("Chain ID"),
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
        "networkFeeAsset": m2,
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
        "passwordCache": MessageLookupByLibrary.simpleMessage("Password Cache"),
        "passwordCacheDesc": MessageLookupByLibrary.simpleMessage(
            "Auto-use cached password after biometric authentication"),
        "passwordCacheDisabled":
            MessageLookupByLibrary.simpleMessage("Password cache disabled"),
        "passwordCacheEnabled":
            MessageLookupByLibrary.simpleMessage("Password cache enabled"),
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
        "receiveAsset": m3,
        "receiveQrTip": MessageLookupByLibrary.simpleMessage(
            "Only send this asset on the selected network."),
        "receiveQrTitle":
            MessageLookupByLibrary.simpleMessage("Scan to receive"),
        "receiveUnavailable": MessageLookupByLibrary.simpleMessage(
            "Receive details are unavailable"),
        "recipientAddress":
            MessageLookupByLibrary.simpleMessage("Recipient address"),
        "refreshBalance": MessageLookupByLibrary.simpleMessage("Refresh"),
        "removeContact": MessageLookupByLibrary.simpleMessage("Remove contact"),
        "removeContactConfirm": m4,
        "removeCustomAsset":
            MessageLookupByLibrary.simpleMessage("Remove asset"),
        "removeCustomAssetConfirmMessage": m5,
        "removeNetwork": MessageLookupByLibrary.simpleMessage("Remove network"),
        "removeNetworkConfirm": m6,
        "removeWallet": MessageLookupByLibrary.simpleMessage("Remove wallet"),
        "removeWalletConfirmMessage": m7,
        "retry": MessageLookupByLibrary.simpleMessage("Retry"),
        "saveContact": MessageLookupByLibrary.simpleMessage("Save contact"),
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
        "themeSystem": MessageLookupByLibrary.simpleMessage("System"),
        "totalAssets": MessageLookupByLibrary.simpleMessage("Total assets"),
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
        "transactionOverview": MessageLookupByLibrary.simpleMessage("Overview"),
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
        "transactionStatusSuccess":
            MessageLookupByLibrary.simpleMessage("Success"),
        "transactionStatusUnknown":
            MessageLookupByLibrary.simpleMessage("Unknown"),
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
        "transferAsset": m8,
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

// ignore_for_file: constant_identifier_names
import 'package:get/get.dart';
import 'package:omnicast/page/transaction/view/transaction_history_page.dart';
import 'package:omnicast/page/home/view/home_page.dart';
import 'package:omnicast/page/transfer/view/transfer_page.dart';
import 'package:omnicast/page/receive/view/receive_page.dart';
import 'package:omnicast/page/wallet/view/wallet_detail_page.dart';
import 'package:omnicast/page/setting/view/language_page.dart';
import 'package:omnicast/page/setting/view/asset_visibility_page.dart';
import 'package:omnicast/page/setting/view/setting_page.dart';
import 'package:omnicast/page/setting/view/theme_page.dart';
import 'package:omnicast/page/setting/view/network_management_page.dart';
import 'package:omnicast/page/main/view/main_page.dart';

class RouteTable {
  static const String transactionHistory = '/transactionHistory';
  static const String home = '/home';
  static const String transfer = '/transfer';
  static const String receive = '/receive';
  static const String walletDetail = '/walletDetail';
  static const String language = '/language';
  static const String assetVisibility = '/assetVisibility';
  static const String setting = '/setting';
  static const String theme = '/theme';
  static const String networkManagement = '/networkManagement';
  static const String main = '/main';

  static final List<GetPage> pages = [
    GetPage(
      name: '/transactionHistory',
      page: () => TransactionHistoryPage(),
    ),
    GetPage(
      name: '/home',
      page: () => HomePage(),
    ),
    GetPage(
      name: '/transfer',
      page: () => TransferPage(),
    ),
    GetPage(
      name: '/receive',
      page: () => ReceivePage(),
    ),
    GetPage(
      name: '/walletDetail',
      page: () => WalletDetailPage(),
    ),
    GetPage(
      name: '/language',
      page: () => LanguagePage(),
    ),
    GetPage(
      name: '/assetVisibility',
      page: () => AssetVisibilityPage(),
    ),
    GetPage(
      name: '/setting',
      page: () => SettingPage(),
    ),
    GetPage(
      name: '/theme',
      page: () => ThemePage(),
    ),
    GetPage(
      name: '/networkManagement',
      page: () => NetworkManagementPage(),
    ),
    GetPage(
      name: '/main',
      page: () => MainPage(),
    ),
  ];
}

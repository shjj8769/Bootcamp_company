import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../login_page.dart';
import 'approval_page.dart';
import 'dashboard_page.dart';
import 'inquiry_page.dart';
import 'model_page.dart';
import 'notice_page.dart';
import 'order_page.dart';
import 'purchase_order_page.dart';
import 'review_page.dart';
import 'sales_page.dart';
import 'stock_page.dart';
import 'store_map_page.dart';

// 본사 직원 로그인 후 화면: 왼쪽 메뉴 + 상단바 + 본문
class CompanyHomePage extends StatefulWidget {
  const CompanyHomePage({super.key});

  @override
  State<CompanyHomePage> createState() => _CompanyHomePageState();
}

class _MenuItem {
  final String label;
  final String title;

  const _MenuItem(this.label, this.title);
}

class _CompanyHomePageState extends State<CompanyHomePage> {
  static const _menus = [
    _MenuItem('대시보드', '대시보드'),
    _MenuItem('매출 현황', '매출 현황'),
    _MenuItem('공지 관리', '공지 관리'),
    _MenuItem('리뷰 관리', '리뷰 관리'),
    _MenuItem('문의 관리', '문의 관리'),
    _MenuItem('주문 관리', '주문 관리'),
    _MenuItem('재고 관리', '재고 관리'),
    _MenuItem('결재 관리', '결재 관리'),
    _MenuItem('발주 관리', '발주 관리'),
    _MenuItem('대리점 관리', '대리점 관리'),
    _MenuItem('모델 계약', '모델 계약'),
  ];

  int _index = 0;
  OrderDraft? _draft; // 재고 관리의 '발주하기'에서 넘어온 품의 초안

  void _logout() {
    Session.clear();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _requestOrder(OrderDraft draft) {
    setState(() {
      _draft = draft;
      _index = _menus.indexWhere((m) => m.label == '결재 관리');
    });
  }

  Widget _page() {
    switch (_menus[_index].label) {
      case '대시보드':
        return DashboardPage(onGo: (label) => _go(label));
      case '매출 현황':
        return const SalesPage();
      case '공지 관리':
        return const NoticePage();
      case '리뷰 관리':
        return const ReviewPage();
      case '문의 관리':
        return const InquiryPage();
      case '주문 관리':
        return const OrderPage();
      case '재고 관리':
        return StockPage(onRequestOrder: _requestOrder);
      case '결재 관리':
        return ApprovalPage(draft: _draft, onDraftConsumed: () => _draft = null);
      case '발주 관리':
        return const PurchaseOrderPage();
      case '모델 계약':
        return const ModelPage();
      default:
        return const StoreMapPage();
    }
  }

  void _go(String label) {
    final i = _menus.indexWhere((m) => m.label == label);
    if (i >= 0) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.theme,
      child: Scaffold(
        body: Row(
          children: [
            _sidebar(),
            Expanded(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                      // 메뉴를 바꿀 때마다 화면을 새로 만들어 최신 데이터를 다시 불러옴
                      child: KeyedSubtree(key: ValueKey(_index), child: _page()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 240,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'FITPICK',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 4),
          const Center(child: Text('HEADQUARTERS', style: TextStyle(color: AppColors.mint, fontSize: 11))),
          const SizedBox(height: 28),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (var i = 0; i < _menus.length; i++) _menuTile(i),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
              label: const Text('로그아웃', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(int i) {
    final selected = i == _index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _index = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.sidebarSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.diamond_outlined, size: 14, color: selected ? Colors.white : Colors.white54),
              const SizedBox(width: 12),
              Text(
                _menus[i].label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final name = Session.eId;
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('본사 운영센터', style: TextStyle(fontSize: 12, color: AppColors.teal)),
                Text(_menus[_index].title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(
            '${Session.employee['e_team'] ?? ''} ${Session.employee['e_jobtitle'] ?? ''}',
            style: const TextStyle(color: AppColors.subText, fontSize: 13),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: AppColors.greenBg,
            child: Text(
              name.isEmpty ? '?' : name[0],
              style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

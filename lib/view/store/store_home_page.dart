import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../login_page.dart';
import 'dashboard_page.dart';
import 'pickup_page.dart';
import 'receive_page.dart';
import 'return_page.dart';
import 'stock_page.dart';

// 대리점 직원 로그인 후 화면: 왼쪽 메뉴 + 상단바 + 본문
// 모든 데이터는 로그인한 직원의 store_seq 기준으로만 조회됨
class StoreHomePage extends StatefulWidget {
  const StoreHomePage({super.key});

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  static const _menus = ['대시보드', '재고 현황', '입고 확인', '고객 픽업', '반품 처리'];

  int _index = 0;
  String _storeName = '';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  // 상단바에 표시할 대리점 이름 (GET /employee/me)
  Future<void> _loadStoreName() async {
    try {
      final res = await Api.get('/employee/me');
      final name = (res['result']?['store_name'] ?? '').toString();
      if (mounted) setState(() => _storeName = name);
    } catch (_) {
      // 이름을 못 가져와도 화면 사용에는 문제 없음
    }
  }

  void _logout() {
    Session.clear();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Widget _page() {
    switch (_menus[_index]) {
      case '대시보드':
        return StoreDashboardPage(onGo: _go);
      case '재고 현황':
        return const StoreStockPage();
      case '입고 확인':
        return const StoreReceivePage();
      case '고객 픽업':
        return const StorePickupPage();
      default:
        return const StoreReturnPage();
    }
  }

  void _go(String label) {
    final i = _menus.indexOf(label);
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
          Center(
            child: Text(
              _storeName.isEmpty ? 'STORE' : _storeName,
              style: const TextStyle(color: AppColors.mint, fontSize: 12),
            ),
          ),
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
                _menus[i],
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
                Text(
                  _storeName.isEmpty ? '대리점 운영센터' : '$_storeName 대리점',
                  style: const TextStyle(fontSize: 12, color: AppColors.teal),
                ),
                Text(_menus[_index], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text('${Session.employee['e_jobtitle'] ?? ''}', style: const TextStyle(color: AppColors.subText, fontSize: 13)),
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

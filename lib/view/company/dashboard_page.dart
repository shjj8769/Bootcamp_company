import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';
import '../common/notice_summary.dart';

// 대시보드: 오늘 매출, 답변 대기 문의, 발송 대기 주문, 발주 필요 재고 요약. 카드를 누르면 해당 메뉴로 이동
class DashboardPage extends StatefulWidget {
  final void Function(String menuLabel) onGo;

  const DashboardPage({super.key, required this.onGo});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // 일부 API가 실패해도 나머지는 보이도록 항목별로 '-' 처리
  Future<String> _safe(Future<String> Function() job) async {
    try {
      return await job();
    } catch (_) {
      return '-';
    }
  }

  Future<Map<String, String>> _load() async {
    final results = await Future.wait([
      _safe(() async {
        final res = await Api.get('/payment/');
        final now = DateTime.now();
        num sum = 0;
        for (final p in (res['results'] ?? []) as List) {
          final d = DateTime.tryParse('${p['pay_date']}');
          if (d != null && d.year == now.year && d.month == now.month && d.day == now.day) {
            sum += (p['pay_price'] ?? 0) as num;
          }
        }
        return formatWon(sum);
      }),
      _safe(() async {
        final res = await Api.get('/inquire/list', query: {'i_state': '0'});
        return '${((res['results'] ?? []) as List).length}건';
      }),
      _safe(() async {
        final res = await Api.get('/office_stock/order');
        return '${((res['results'] ?? []) as List).length}건';
      }),
      _safe(() async {
        final res = await Api.get('/office_stock/list');
        final need = ((res['results'] ?? []) as List).where((r) => r['need_order'] == true).length;
        return '$need개';
      }),
    ]);
    return {'sales': results[0], 'inquiry': results[1], 'order': results[2], 'stock': results[3]};
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PageHeader(
          title: '대시보드',
          subtitle: '오늘 처리할 업무를 한눈에 확인하세요.',
          trailing: IconButton(
            onPressed: () => setState(() { _future = _load(); }),
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ),
        AsyncBody<Map<String, String>>(
          future: _future,
          onRetry: () => setState(() { _future = _load(); }),
          builder: (data) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 3.2,
            children: [
              _tile('오늘 매출', data['sales']!, '매출 현황'),
              _tile('답변 대기 문의', data['inquiry']!, '문의 관리'),
              _tile('발송 대기 주문', data['order']!, '주문 관리'),
              _tile('발주 필요 재고', data['stock']!, '재고 관리'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NoticeSummary(onViewAll: () => widget.onGo('공지 관리')),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _tile(String label, String value, String menu) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => widget.onGo(menu),
      child: Stack(
        children: [
          Positioned.fill(child: KpiCard(label: label, value: value)),
          const Positioned(
            right: 16,
            top: 16,
            child: Icon(Icons.chevron_right, color: AppColors.subText),
          ),
        ],
      ),
    );
  }
}

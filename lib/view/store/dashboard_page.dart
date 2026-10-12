import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';
import '../common/notice_summary.dart';

// 대리점 대시보드: 우리 매장 재고 요약, 입고 대기, 반품 대기, 재고가 적은 제품, 본사 공지사항
// 카드를 누르면 해당 메뉴로 이동. 모든 데이터는 로그인한 대리점(store_seq) 기준
class StoreDashboardPage extends StatefulWidget {
  final void Function(String menuLabel) onGo;

  const StoreDashboardPage({super.key, required this.onGo});

  @override
  State<StoreDashboardPage> createState() => _StoreDashboardPageState();
}

// 항목별로 불러오지 못하면 null (화면에는 '-'로 표시)
class _DashboardData {
  final List<Map<String, dynamic>>? stocks;
  final int? incoming;
  final int? returns;

  _DashboardData(this.stocks, this.incoming, this.returns);
}

class _StoreDashboardPageState extends State<StoreDashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<T?> _safe<T>(Future<T> Function() job) async {
    try {
      return await job();
    } catch (_) {
      return null;
    }
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      _safe<List<Map<String, dynamic>>>(() async {
        final res = await Api.get('/store_stock/list');
        return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }),
      _safe<int>(() async {
        final res = await Api.get('/store_stock/receive');
        return ((res['results'] ?? []) as List).length;
      }),
      // 반품 API에는 매장 정보가 없어서 구매 내역의 store_seq로 우리 매장의 처리 대기 반품만 센다
      _safe<int>(() async {
        final both = await Future.wait([Api.get('/refund/'), Api.get('/purchase/')]);
        final storeByPurchase = <int, int>{
          for (final p in (both[1]['results'] ?? []) as List) p['p_id'] as int: (p['store_seq'] ?? 0) as int,
        };
        return ((both[0]['results'] ?? []) as List)
            .where((r) => storeByPurchase[r['p_r_id']] == Session.storeSeq && r['is_refunded'] != 1)
            .length;
      }),
    ]);
    return _DashboardData(
      results[0] as List<Map<String, dynamic>>?,
      results[1] as int?,
      results[2] as int?,
    );
  }

  void _reload() => setState(() {
        _future = _load();
      });

  String _value(int? n, String unit) => n == null ? '-' : '${formatNumber(n)}$unit';

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PageHeader(
          title: '대시보드',
          subtitle: '우리 매장의 재고와 오늘 처리할 업무를 한눈에 확인하세요.',
          trailing: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: '새로고침'),
        ),
        AsyncBody<_DashboardData>(
          future: _future,
          onRetry: _reload,
          builder: (d) {
            final stocks = d.stocks;
            final total = stocks?.fold<int>(0, (s, r) => s + ((r['s_count'] ?? 0) as int));
            final lowest = (stocks == null ? <Map<String, dynamic>>[] : [...stocks])
              ..sort((a, b) => ((a['s_count'] ?? 0) as int).compareTo((b['s_count'] ?? 0) as int));
            return Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 3.2,
                  children: [
                    _tile('보유 제품(SKU)', _value(stocks?.length, '종'), '재고 현황'),
                    _tile('총 재고 수량', _value(total, '개'), '재고 현황'),
                    _tile('입고 대기', _value(d.incoming, '건'), '입고 확인'),
                    _tile('반품 처리 대기', _value(d.returns, '건'), '반품 처리'),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '재고가 적은 제품',
                  trailing: TextButton(onPressed: () => widget.onGo('재고 현황'), child: const Text('전체 보기 ›')),
                  child: stocks == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('재고를 불러오지 못했습니다.', style: TextStyle(color: AppColors.subText))),
                        )
                      : lowest.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('보유한 재고가 없습니다.', style: TextStyle(color: AppColors.subText))),
                            )
                          : Column(
                              children: [
                                for (final r in lowest.take(5))
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('${r['pr_id']}', style: const TextStyle(fontSize: 13))),
                                        Text('${r['s_count'] ?? 0}개', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                ),
                const SizedBox(height: 16),
                const NoticeSummary(limit: 6),
              ],
            );
          },
        ),
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

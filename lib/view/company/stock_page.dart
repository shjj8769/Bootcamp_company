import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';
import 'approval_page.dart';

// 재고 관리: 본사재고 목록. 재고가 기준재고(100)의 30% 미만이면 '발주 필요'로 표시
// '발주하기'를 누르면 결재(품의) 화면으로 이동. GET /office_stock/list
class StockPage extends StatefulWidget {
  final void Function(OrderDraft draft) onRequestOrder;

  const StockPage({super.key, required this.onRequestOrder});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _onlyNeed = false;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/office_stock/list');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(title: '재고 관리', subtitle: '본사 재고를 확인하고 부족한 제품은 발주를 요청하세요.'),
        AsyncBody<List<Map<String, dynamic>>>(
          future: _future,
          onRetry: _reload,
          builder: _content,
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _content(List<Map<String, dynamic>> all) {
    final needCount = all.where((r) => r['need_order'] == true).length;
    final rows = all.where((r) {
      if (_onlyNeed && r['need_order'] != true) return false;
      if (_keyword.isEmpty) return true;
      final text = '${r['pr_id']} ${r['pr_name']}'.toLowerCase();
      return text.contains(_keyword.toLowerCase());
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: KpiCard(label: '관리 중인 제품(SKU)', value: '${formatNumber(all.length)}개')),
            const SizedBox(width: 16),
            Expanded(child: KpiCard(label: '발주 필요 (재고 30% 미만)', value: '${formatNumber(needCount)}개')),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: !_onlyNeed,
                showCheckmark: false,
                selectedColor: AppColors.sidebar,
                labelStyle: TextStyle(color: !_onlyNeed ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _onlyNeed = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('발주 필요'),
                selected: _onlyNeed,
                showCheckmark: false,
                selectedColor: AppColors.sidebar,
                labelStyle: TextStyle(color: _onlyNeed ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _onlyNeed = true),
              ),
              const Spacer(),
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '제품명·SKU 검색',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onChanged: (v) => setState(() => _keyword = v.trim()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: EdgeInsets.zero,
          child: rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(
                    child: Text('표시할 재고가 없습니다.', style: TextStyle(color: AppColors.subText)),
                  ),
                )
              : Column(
                  children: [
                    const TableHeaderRow(
                      labels: ['SKU', '제품명', '현재 재고', '최소수량', '상태', '발주'],
                      flex: [3, 3, 3, 2, 2, 2],
                    ),
                    for (final r in rows) _row(r),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final now = (r['now_count'] ?? 0) as int;
    final least = (r['least_count'] ?? 0) as int;
    final base = (r['base_count'] ?? 100) as int;
    final need = r['need_order'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('${r['pr_id']}', style: const TextStyle(fontSize: 12))),
          Expanded(
            flex: 3,
            child: Text('${r['pr_name'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (now / base).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: AppColors.background,
                      color: need ? AppColors.coral : AppColors.mint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$now', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text('$least', style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(need ? '발주 필요' : '정상', kind: need ? BadgeKind.warn : BadgeKind.done),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => widget.onRequestOrder(
                  OrderDraft(
                    prId: '${r['pr_id']}',
                    prName: '${r['pr_name'] ?? ''}',
                    nowCount: now,
                    leastCount: least,
                    baseCount: base,
                  ),
                ),
                child: const Text('발주하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

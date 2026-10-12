import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 대리점 재고 현황: 로그인한 대리점의 제품(SKU)별 수량. GET /store_stock/list
class StoreStockPage extends StatefulWidget {
  const StoreStockPage({super.key});

  @override
  State<StoreStockPage> createState() => _StoreStockPageState();
}

class _StoreStockPageState extends State<StoreStockPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/store_stock/list');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PageHeader(
          title: '재고 현황',
          subtitle: '우리 매장에 있는 제품 수량을 확인하세요.',
          trailing: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: '새로고침'),
        ),
        AsyncBody<List<Map<String, dynamic>>>(
          future: _future,
          onRetry: _reload,
          builder: (all) {
            final total = all.fold<int>(0, (s, r) => s + ((r['s_count'] ?? 0) as int));
            final rows = _keyword.isEmpty
                ? all
                : all.where((r) => '${r['pr_id']}'.toLowerCase().contains(_keyword.toLowerCase())).toList();
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: KpiCard(label: '보유 제품(SKU)', value: '${formatNumber(all.length)}종')),
                    const SizedBox(width: 16),
                    Expanded(child: KpiCard(label: '총 재고 수량', value: '${formatNumber(total)}개')),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'SKU 검색',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onChanged: (v) => setState(() => _keyword = v.trim()),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: rows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 50),
                          child: Center(child: Text('재고가 없습니다.', style: TextStyle(color: AppColors.subText))),
                        )
                      : Column(
                          children: [
                            const TableHeaderRow(labels: ['제품(SKU)', '수량'], flex: [6, 2]),
                            for (final r in rows)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                                child: Row(
                                  children: [
                                    Expanded(flex: 6, child: Text('${r['pr_id']}', style: const TextStyle(fontSize: 13))),
                                    Expanded(
                                      flex: 2,
                                      child: Text('${r['s_count'] ?? 0}개', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

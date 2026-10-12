import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 반품 처리: 우리 매장에서 구매한 상품의 반품 요청 목록과 처리
// GET /refund/ (+ /purchase/ 로 매장 필터), PUT /refund/{p_r_id}
// 처리하면 환불 완료로만 바꿈 (반품 상품을 본사로 다시 보내는 '반납'은 이 화면에서 다루지 않음)
class StoreReturnPage extends StatefulWidget {
  const StoreReturnPage({super.key});

  @override
  State<StoreReturnPage> createState() => _StoreReturnPageState();
}

class _StoreReturnPageState extends State<StoreReturnPage> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _onlyWaiting = true;
  int? _processingId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // 반품 API에는 매장 정보가 없어서, 구매 내역(purchase)의 store_seq로 우리 매장 반품만 골라냄
  Future<List<Map<String, dynamic>>> _load() async {
    final results = await Future.wait([Api.get('/refund/'), Api.get('/purchase/')]);
    final storeByPurchase = <int, int>{
      for (final p in (results[1]['results'] ?? []) as List) p['p_id'] as int: (p['store_seq'] ?? 0) as int,
    };
    return ((results[0]['results'] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((r) => storeByPurchase[r['p_r_id']] == Session.storeSeq)
        .toList();
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _process(Map<String, dynamic> r) async {
    final id = r['p_r_id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반품 처리'),
        content: Text('${r['pr_name'] ?? r['SKU']} ${r['p_count']}개의 환불을 완료 처리합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('처리')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _processingId = id);
    try {
      await Api.sendJson('PUT', '/refund/$id', {'is_refunded': 1, 'e_id': Session.eId});
      if (!mounted) return;
      showMessage(context, '환불을 완료 처리했습니다.');
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
      _reload();
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PageHeader(
          title: '반품 처리',
          subtitle: '고객이 요청한 반품을 확인하고 처리하세요.',
          trailing: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: '새로고침'),
        ),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('처리 대기'),
                selected: _onlyWaiting,
                showCheckmark: false,
                selectedColor: AppColors.sidebar,
                labelStyle: TextStyle(color: _onlyWaiting ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _onlyWaiting = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('전체'),
                selected: !_onlyWaiting,
                showCheckmark: false,
                selectedColor: AppColors.sidebar,
                labelStyle: TextStyle(color: !_onlyWaiting ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _onlyWaiting = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncBody<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _reload,
            builder: (all) {
              final rows = _onlyWaiting ? all.where((r) => r['is_refunded'] != 1).toList() : all;
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('반품 요청이 없습니다.', style: TextStyle(color: AppColors.subText))),
                );
              }
              return Column(
                children: [
                  const TableHeaderRow(
                    labels: ['반품번호', '제품', '수량', '사유', '반품일', '상태', '처리'],
                    flex: [2, 4, 1, 4, 2, 2, 2],
                  ),
                  for (final r in rows) _row(r),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final done = r['is_refunded'] == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('RET-${r['p_r_id']}', style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 4,
            child: Text('${r['pr_name'] ?? r['SKU']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(flex: 1, child: Text('${r['p_count'] ?? '-'}', style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 4,
            child: Text('${r['p_r_reason'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(flex: 2, child: Text(formatDate(r['p_r_date']), style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(done ? '처리 완료' : '처리 대기', kind: done ? BadgeKind.done : BadgeKind.wait),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: done
                  ? const Text('-', style: TextStyle(color: AppColors.subText))
                  : OutlinedButton(
                      onPressed: _processingId == null ? () => _process(r) : null,
                      child: _processingId == r['p_r_id']
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('반품 처리'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

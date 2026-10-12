import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 발주 관리: 제조사 견적서(발주 결과) 목록과 상세. GET /estimate/list, /estimate/detail
// 견적서와 주문서(영수증)는 동일하게 취급
class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/estimate/list');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(title: '발주 관리', subtitle: '제조사 견적서를 확인하고 발주 내역을 관리하세요.'),
        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncBody<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _reload,
            builder: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('견적서가 없습니다.', style: TextStyle(color: AppColors.subText))),
                );
              }
              return Column(
                children: [
                  const TableHeaderRow(
                    labels: ['견적번호', '제조사', '견적일', '결제 금액(VAT 포함)', '보기'],
                    flex: [3, 3, 2, 3, 2],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('${r['estimate_no']}', style: const TextStyle(fontSize: 13))),
          Expanded(flex: 3, child: Text('${r['m_name'] ?? '-'}', style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text(formatDate(r['e_date']), style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 3,
            child: Text(formatWon((r['total_price'] ?? 0) as num), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _EstimateDialog(eESeq: r['e_e_seq'] as int),
                ),
                child: const Text('견적서 보기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateDialog extends StatelessWidget {
  final int eESeq;

  const _EstimateDialog({required this.eESeq});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('견적서'),
      content: SizedBox(
        width: 640,
        child: FutureBuilder<dynamic>(
          future: Api.get('/estimate/detail', query: {'e_e_seq': '$eESeq'}),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) return Text(snap.error.toString());
            final d = Map<String, dynamic>.from(snap.data as Map);
            final items = ((d['items'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('견적번호 ${d['estimate_no']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('제조사 ${d['m_name'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                  if (d['m_address'] != null) Text('주소 ${d['m_address']}', style: const TextStyle(fontSize: 13)),
                  Text('견적일 ${formatDate(d['e_date'])}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 14),
                  const TableHeaderRow(labels: ['품명', '단가', '수량', '합계'], flex: [4, 2, 1, 2]),
                  for (final i in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('${i['pr_name'] ?? i['pr_id']}', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(formatWon((i['e_list_price'] ?? 0) as num), style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 1, child: Text('${i['e_count'] ?? 0}', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(formatWon((i['e_price'] ?? 0) as num), style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '결제 예정 금액 ${formatWon((d['total_price'] ?? 0) as num)} (VAT 포함)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기'))],
    );
  }
}

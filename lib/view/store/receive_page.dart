import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 입고 확인: 본사가 발송한 물품 중 아직 받지 않은 것을 확인하고 수령 처리
// GET /store_stock/receive, POST /store_stock/receive (수령 확인 시 대리점 재고 증가)
class StoreReceivePage extends StatefulWidget {
  const StoreReceivePage({super.key});

  @override
  State<StoreReceivePage> createState() => _StoreReceivePageState();
}

class _StoreReceivePageState extends State<StoreReceivePage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _receivingId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/store_stock/receive');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _receive(Map<String, dynamic> row) async {
    final id = '${row['send_id']}';
    setState(() => _receivingId = id);
    try {
      await Api.postForm('/store_stock/receive', {'send_id': id});
      if (!mounted) return;
      showMessage(context, '입고 확인했습니다. 재고에 반영되었습니다.');
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _receivingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PageHeader(
          title: '입고 확인',
          subtitle: '본사에서 발송한 물품을 받으면 수령 확인을 눌러 주세요.',
          trailing: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: '새로고침'),
        ),
        SectionCard(
          padding: EdgeInsets.zero,
          child: AsyncBody<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _reload,
            builder: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('받을 물품이 없습니다.', style: TextStyle(color: AppColors.subText))),
                );
              }
              return Column(
                children: [
                  const TableHeaderRow(labels: ['제품(SKU)', '수량', '발송일', '처리'], flex: [5, 1, 2, 2]),
                  for (final r in rows)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text('${r['pr_id']}', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 1, child: Text('${r['s_count']}', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(formatDate(r['s_date']), style: const TextStyle(fontSize: 13))),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton(
                                onPressed: _receivingId == null ? () => _receive(r) : null,
                                style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
                                child: _receivingId == '${r['send_id']}'
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('수령 확인'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

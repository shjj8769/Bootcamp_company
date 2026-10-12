import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 주문 관리: 고객 결제로 들어온 주문과 진행 상태를 보여주고, 발송 전 주문을 대리점으로 발송 처리
// 상태: 발송 전 -> 발송중(발송 처리) -> 발송완료(대리점 입고 확인) -> 픽업완료(고객 QR 픽업)
// GET /office_stock/order, POST /office_stock/send (발송 시 본사재고 감소)
class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

const _statuses = ['발송 전', '발송중', '발송완료', '픽업완료'];

BadgeKind _kindOf(String status) => switch (status) {
      '발송중' => BadgeKind.info,
      '발송완료' => BadgeKind.done,
      '픽업완료' => BadgeKind.strong,
      _ => BadgeKind.wait,
    };

class _OrderPageState extends State<OrderPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _filter; // null이면 전체
  int? _sendingId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/office_stock/order');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _send(Map<String, dynamic> order) async {
    final pId = order['p_id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대리점으로 발송'),
        content: Text('${order['s_name'] ?? '대리점'}으로 ${order['pr_id']} ${order['p_count']}개를 발송합니다.\n본사 재고가 그만큼 줄어듭니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('발송')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sendingId = pId);
    try {
      await Api.postForm('/office_stock/send', {'p_id': '$pId'});
      if (!mounted) return;
      showMessage(context, '발송 처리했습니다. 상태가 \'발송중\'으로 바뀝니다.');
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message == 'not enough stock' ? '본사 재고가 부족합니다.' : e.message);
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PageHeader(
          title: '주문 관리',
          subtitle: '주문을 대리점으로 발송하고 입고, 픽업까지 진행 상황을 확인하세요.',
          trailing: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: '새로고침'),
        ),
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
    final counts = {for (final s in _statuses) s: all.where((r) => r['status'] == s).length};
    final rows = _filter == null ? all : all.where((r) => r['status'] == _filter).toList();
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _statuses.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: KpiCard(label: _statuses[i], value: '${counts[_statuses[i]]}건')),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _chip('전체', null),
              for (final s in _statuses) ...[
                const SizedBox(width: 8),
                _chip(s, s),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: EdgeInsets.zero,
          child: rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('해당하는 주문이 없습니다.', style: TextStyle(color: AppColors.subText))),
                )
              : Column(
                  children: [
                    const TableHeaderRow(
                      labels: ['주문번호', '대리점', '제품(SKU)', '수량', '주문일', '상태', '처리'],
                      flex: [2, 2, 4, 1, 2, 2, 2],
                    ),
                    for (final r in rows) _row(r),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.sidebar,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final status = '${r['status']}';
    final waiting = status == '발송 전';
    final canSend = r['can_send'] == true;
    final sending = _sendingId == r['p_id'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('ORD-${r['p_id']}', style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text('${r['s_name'] ?? r['store_seq']}', style: const TextStyle(fontSize: 13))),
          Expanded(flex: 4, child: Text('${r['pr_id']}', style: const TextStyle(fontSize: 12))),
          Expanded(flex: 1, child: Text('${r['p_count']}', style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text(formatDate(r['p_date']), style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(status, kind: _kindOf(status))),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: waiting
                  ? OutlinedButton(
                      onPressed: canSend && !sending ? () => _send(r) : null,
                      child: sending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(canSend ? '발송하기' : '재고 부족'),
                    )
                  : const Text('-', style: TextStyle(color: AppColors.subText)),
            ),
          ),
        ],
      ),
    );
  }
}

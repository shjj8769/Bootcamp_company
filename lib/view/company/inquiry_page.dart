import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 문의 관리: 상태별 목록, 검색(문의번호/내용/고객명), 답변 등록
// GET /inquire/list, POST /inquire/search, POST /inquire/answer
class InquiryPage extends StatefulWidget {
  const InquiryPage({super.key});

  @override
  State<InquiryPage> createState() => _InquiryPageState();
}

bool _isDone(dynamic state) => state == 1 || state == '1' || state == '답변완료';

class _InquiryPageState extends State<InquiryPage> {
  final _searchController = TextEditingController();
  int? _state; // null 전체, 0 답변 대기, 1 답변 완료
  String _keyword = '';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = _keyword.isEmpty
        ? await Api.get('/inquire/list', query: {if (_state != null) 'i_state': '$_state'})
        : await Api.postForm('/inquire/search', {
            'keyword': _keyword,
            if (_state != null) 'i_state': '$_state',
          });
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(title: '문의 관리', subtitle: '고객 문의를 상태별로 확인하고 답변을 관리하세요.'),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _tab('전체', null),
              const SizedBox(width: 8),
              _tab('답변 대기', 0),
              const SizedBox(width: 8),
              _tab('답변 완료', 1),
              const Spacer(),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '문의번호·내용·고객명 검색',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onSubmitted: (value) {
                    _keyword = value.trim();
                    _reload();
                  },
                ),
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
            builder: _table,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _tab(String label, int? value) {
    final selected = _state == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.sidebar,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
      onSelected: (_) {
        _state = value;
        _reload();
      },
    );
  }

  Widget _table(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: Text('문의가 없습니다.', style: TextStyle(color: AppColors.subText))),
      );
    }
    return Column(
      children: [
        const TableHeaderRow(labels: ['번호', '고객', '제목', '상태', '처리'], flex: [2, 2, 4, 2, 2]),
        for (final row in rows) _row(row),
      ],
    );
  }

  Widget _row(Map<String, dynamic> row) {
    // 추가 문의 중 답변하지 않은 것이 있으면 처리 대기로 표시
    final followUps = ((row['follow_ups'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pendingFollow = followUps.any((f) => !_isDone(f['i_state']));
    final done = _isDone(row['i_state']);
    return InkWell(
      onTap: () => _openDetail(row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text('INQ-${row['i_seq']}', style: const TextStyle(fontSize: 13))),
            Expanded(flex: 2, child: Text('${row['c_name'] ?? '-'}', style: const TextStyle(fontSize: 13))),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Flexible(
                    child: Text('${row['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ),
                  if (pendingFollow) ...[
                    const SizedBox(width: 8),
                    const StatusBadge('추가 문의', kind: BadgeKind.warn),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(done ? '답변 완료' : '답변 대기', kind: done ? BadgeKind.done : BadgeKind.wait),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => _openDetail(row),
                  child: Text(done && !pendingFollow ? '답변 보기' : '답변하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _InquiryDialog(inquiry: row),
    );
    if (changed == true) _reload();
  }
}

// 문의 상세: 원글과 추가 문의 각각에 답변을 등록
class _InquiryDialog extends StatefulWidget {
  final Map<String, dynamic> inquiry;

  const _InquiryDialog({required this.inquiry});

  @override
  State<_InquiryDialog> createState() => _InquiryDialogState();
}

class _InquiryDialogState extends State<_InquiryDialog> {
  final Map<int, TextEditingController> _controllers = {};
  bool _changed = false;
  bool _saving = false;

  List<Map<String, dynamic>> get _items {
    final follow = ((widget.inquiry['follow_ups'] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return [widget.inquiry, ...follow];
  }

  TextEditingController _controller(int seq) => _controllers.putIfAbsent(seq, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(int seq) async {
    final text = _controller(seq).text.trim();
    if (text.isEmpty) {
      showMessage(context, '답변 내용을 입력해 주세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      await Api.postForm('/inquire/answer', {
        'i_seq': '$seq',
        'e_id': Session.eId,
        'inquiry_detail': text,
      });
      if (!mounted) return;
      _changed = true;
      Navigator.of(context).pop(true);
      showMessage(context, '답변을 등록했습니다.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return AlertDialog(
      title: Text('INQ-${widget.inquiry['i_seq']}  ${widget.inquiry['title'] ?? ''}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) _item(items[i], isFollow: i > 0),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(_changed), child: const Text('닫기')),
      ],
    );
  }

  Widget _item(Map<String, dynamic> item, {required bool isFollow}) {
    final seq = item['i_seq'] as int;
    final answered = (item['inquiry_detail'] ?? '').toString().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFollow ? '추가 문의 · ${formatDate(item['i_date'])}' : '고객 문의 · ${formatDate(item['i_date'])}',
            style: const TextStyle(fontSize: 12, color: AppColors.subText),
          ),
          const SizedBox(height: 6),
          Text('${item['post'] ?? ''}'),
          const Divider(height: 24),
          if (answered) ...[
            Text('답변 · ${formatDate(item['d_date'])}  (${item['e_id'] ?? '-'})',
                style: const TextStyle(fontSize: 12, color: AppColors.teal)),
            const SizedBox(height: 6),
            Text('${item['inquiry_detail']}'),
          ] else ...[
            TextField(
              controller: _controller(seq),
              maxLines: 4,
              decoration: const InputDecoration(hintText: '답변을 입력하세요', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : () => _submit(seq),
                style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
                child: const Text('답변 등록'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

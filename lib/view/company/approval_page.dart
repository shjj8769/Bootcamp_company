import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 재고 관리의 '발주하기'에서 넘어오는 품의 초안 (해당 제품의 품의 작성 창이 바로 열림)
class OrderDraft {
  final String prId;
  final String prName;
  final int nowCount;
  final int leastCount;
  final int baseCount;

  const OrderDraft({
    required this.prId,
    required this.prName,
    required this.nowCount,
    required this.leastCount,
    required this.baseCount,
  });
}

// 결재(품의) 관리
// 1) 재고가 부족한 순서대로 본사재고를 보여주고, 오른쪽 '품의 작성'을 누르면 해당 제품과 제조사(자동)가 고정된 품의서가 열림
//    품의서에서는 단가와 신청 사유만 입력 (GET /approval/list/candidates, POST /approval/submit)
// 2) 흐름: 사원이 품의 상신 -> 같은 부서 팀장 서명 -> 임원 서명 -> 마지막 결재자인 임원이 '발주' -> 견적서/발주 생성
//    결재 순서와 권한은 서버(/approval/*)가 토큰의 직급·부서로 검증하고, 화면은 서버가 알려준 can_sign/can_order대로 버튼만 보여줌
class ApprovalPage extends StatefulWidget {
  final OrderDraft? draft;
  final VoidCallback onDraftConsumed;

  const ApprovalPage({super.key, this.draft, required this.onDraftConsumed});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  late Future<List<Map<String, dynamic>>> _listFuture;
  late Future<List<Map<String, dynamic>>> _candFuture;
  bool _onlyNeed = true; // true면 재고 부족(발주 필요) 품목만
  int? _busyId;
  String? _draftPrId; // 재고 관리에서 넘어온 제품: 후보 목록을 불러오면 해당 품의서를 바로 연다

  @override
  void initState() {
    super.initState();
    _draftPrId = widget.draft?.prId;
    if (widget.draft != null) widget.onDraftConsumed();
    _listFuture = _loadList();
    _candFuture = _loadCandidates();
  }

  List<Map<String, dynamic>> _rows(dynamic res) =>
      ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<List<Map<String, dynamic>>> _loadList() async => _rows(await Api.get('/approval/list'));

  Future<List<Map<String, dynamic>>> _loadCandidates() async {
    final rows = _rows(await Api.get('/approval/list/candidates'));
    final draftId = _draftPrId;
    if (draftId != null) {
      _draftPrId = null;
      final match = rows.where((r) => r['pr_id'] == draftId).firstOrNull;
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openCompose(match);
        });
      }
    }
    return rows;
  }

  void _reloadAll() => setState(() {
        _listFuture = _loadList();
        _candFuture = _loadCandidates();
      });

  Future<void> _openCompose(Map<String, dynamic> candidate) async {
    if (candidate['m_id'] == null) {
      showMessage(context, '이 제품의 제조사를 찾을 수 없어 품의를 작성할 수 없습니다.');
      return;
    }
    if (candidate['pending'] == true) {
      showMessage(context, '이미 같은 제품으로 진행 중인 품의가 있습니다.');
      return;
    }
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _ComposeDialog(candidate: candidate),
    );
    if (submitted == true && mounted) {
      showMessage(context, '품의가 상신되었습니다.');
      _reloadAll();
    }
  }

  Future<void> _sign(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결재 서명'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('품의 #${a['a_seq']}에 서명합니다.'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.background,
              ),
              child: Text(
                '${Session.employee['e_jobtitle'] ?? ''}  ${Session.eId}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
            child: const Text('서명하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _act(a['a_seq'] as int, '/approval/sign', '서명했습니다.');
  }

  Future<void> _order(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('발주'),
        content: Text('품의 #${a['a_seq']} (${_total(a)})을 발주합니다.\n발주하면 견적서가 생성되고 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('발주하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _act(a['a_seq'] as int, '/approval/order', '발주했습니다. 발주 관리에서 견적서를 확인할 수 있습니다.');
  }

  Future<void> _act(int aSeq, String path, String doneMessage) async {
    setState(() => _busyId = aSeq);
    try {
      await Api.postForm(path, {'a_seq': '$aSeq'});
      if (!mounted) return;
      showMessage(context, doneMessage);
      _reloadAll();
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(
          context,
          switch (e.message) {
            'not your turn' => '지금은 서명할 차례가 아닙니다.',
            'not allowed to order' => '발주 권한이 없습니다. 모든 결재가 끝난 뒤 마지막 결재자인 임원만 발주할 수 있습니다.',
            'already ordered' => '이미 발주한 품의입니다.',
            _ => e.message,
          },
        );
        _reloadAll();
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _total(Map<String, dynamic> a) {
    num sum = 0;
    for (final i in (a['a_items'] ?? []) as List) {
      sum += ((i['e_count'] ?? 0) as num) * ((i['e_list_price'] ?? 0) as num);
    }
    return formatWon(sum);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(
          title: '결재 관리',
          subtitle: '재고가 부족한 제품의 품의를 작성하면 팀장, 임원 순서로 결재하고 최종적으로 임원이 발주합니다.',
        ),
        SectionCard(
          title: '재고 부족 품목',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _chip('발주 필요', true),
              const SizedBox(width: 8),
              _chip('전체', false),
            ],
          ),
          child: AsyncBody<List<Map<String, dynamic>>>(
            future: _candFuture,
            onRetry: () => setState(() {
              _candFuture = _loadCandidates();
            }),
            builder: _candidateList,
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('품의 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        AsyncBody<List<Map<String, dynamic>>>(
          future: _listFuture,
          onRetry: () => setState(() {
            _listFuture = _loadList();
          }),
          builder: (rows) {
            if (rows.isEmpty) {
              return const SectionCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('우리 부서의 품의가 없습니다.', style: TextStyle(color: AppColors.subText))),
                ),
              );
            }
            return Column(
              children: [
                for (final a in rows)
                  Padding(padding: const EdgeInsets.only(bottom: 14), child: _approvalCard(a)),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _chip(String label, bool onlyNeed) {
    final selected = _onlyNeed == onlyNeed;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.sidebar,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
      onSelected: (_) => setState(() => _onlyNeed = onlyNeed),
    );
  }

  // 재고가 적은 순서(서버가 정렬해서 내려줌)대로 한 줄씩, 오른쪽에 '품의 작성' 버튼
  Widget _candidateList(List<Map<String, dynamic>> all) {
    final rows = _onlyNeed ? all.where((r) => r['need_order'] == true).toList() : all;
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text('재고가 부족한 품목이 없습니다.', style: TextStyle(color: AppColors.subText))),
      );
    }
    return Column(
      children: [
        const TableHeaderRow(labels: ['제품', '현재 재고', '제조사', '상태', ''], flex: [5, 3, 2, 2, 2]),
        for (final r in rows) _candidateRow(r),
      ],
    );
  }

  Widget _candidateRow(Map<String, dynamic> r) {
    final now = (r['now_count'] ?? 0) as int;
    final base = (r['base_count'] ?? 100) as int;
    final need = r['need_order'] == true;
    final pending = r['pending'] == true;
    final noManufacture = r['m_id'] == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['pr_name'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${r['pr_id']}', style: const TextStyle(fontSize: 11, color: AppColors.subText)),
              ],
            ),
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
          Expanded(flex: 2, child: Text('${r['m_name'] ?? '-'}', style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(need ? '재고 부족' : '정상', kind: need ? BadgeKind.warn : BadgeKind.done),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: pending || noManufacture ? null : () => _openCompose(r),
                style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
                child: Text(pending ? '품의 진행중' : (noManufacture ? '제조사 없음' : '품의 작성')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalCard(Map<String, dynamic> a) {
    final ordered = a['ordered'] == true;
    final done = a['a_state'] == '심사완료';
    final items = ((a['a_items'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final line = ((a['a_line'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final signatures = ((a['a_signatures'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final busy = _busyId == a['a_seq'];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('품의 #${a['a_seq']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              StatusBadge(
                '${a['a_state']}',
                kind: ordered ? BadgeKind.strong : (done ? BadgeKind.done : BadgeKind.wait),
              ),
              const Spacer(),
              Text(
                '${a['e_id']} (${a['e_jobtitle']}) · 처리일 ${formatDate(a['a_date'])}',
                style: const TextStyle(fontSize: 12, color: AppColors.subText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('제조사 ${a['a_name']} · 합계 ${_total(a)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final i in items)
            Text(
              '· ${i['pr_name'] ?? ''} (${i['pr_id']})  ${i['e_count']}개 × ${formatWon((i['e_list_price'] ?? 0) as num)}',
              style: const TextStyle(fontSize: 13, color: AppColors.subText),
            ),
          if ((a['a_reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('사유: ${a['a_reason']}', style: const TextStyle(fontSize: 13, color: AppColors.subText)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _stage('상신', '${a['e_id']}', true),
              for (var s = 0; s < line.length; s++) ...[
                const Icon(Icons.chevron_right, size: 18, color: AppColors.subText),
                _stage(
                  '${line[s]['e_jobtitle']}',
                  s < signatures.length ? '${signatures[s]['e_id']}' : ((line[s]['approvers'] ?? []) as List).join(', '),
                  s < signatures.length,
                ),
              ],
              const Spacer(),
              if (a['can_sign'] == true)
                FilledButton.icon(
                  onPressed: busy ? null : () => _sign(a),
                  icon: const Icon(Icons.draw_outlined, size: 18),
                  label: const Text('결재(서명)'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
                ),
              if (a['can_order'] == true)
                FilledButton.icon(
                  onPressed: busy ? null : () => _order(a),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('발주'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stage(String title, String who, bool signed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: signed ? AppColors.greenBg : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (signed) const Icon(Icons.check_circle, size: 14, color: AppColors.greenText),
              if (signed) const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          Text(who, style: const TextStyle(fontSize: 11, color: AppColors.subText)),
        ],
      ),
    );
  }
}

// 품의서 작성 창: 제품, 제조사, 수량은 고정(자동)이고 단가와 신청 사유만 입력
class _ComposeDialog extends StatefulWidget {
  final Map<String, dynamic> candidate;

  const _ComposeDialog({required this.candidate});

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  final _price = TextEditingController();
  late final TextEditingController _reason;
  bool _saving = false;
  String? _error;

  Map<String, dynamic> get c => widget.candidate;

  @override
  void initState() {
    super.initState();
    // 재고 부족 사유를 기본 문구로 채워 두고, 필요하면 고쳐 쓸 수 있음
    _reason = TextEditingController(
      text: c['need_order'] == true ? '재고 ${c['now_count']}개로 최소수량(${c['least_count']}개) 미만이라 발주 요청' : '',
    );
  }

  @override
  void dispose() {
    _price.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = int.tryParse(_price.text.trim().replaceAll(',', ''));
    if (price == null || price < 0) {
      setState(() => _error = '단가를 숫자로 입력해 주세요.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = '신청 사유를 입력해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Api.sendJson('POST', '/approval/submit', {
        'm_id': c['m_id'],
        'a_reason': _reason.text.trim(),
        'items': [
          {
            'pr_id': c['pr_id'],
            'pr_name': c['pr_name'] ?? '',
            'e_count': c['suggested_count'],
            'e_list_price': price,
          },
        ],
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message == 'no executive in team'
            ? '우리 부서에는 임원이 없어 품의를 올릴 수 없습니다. 결재선은 사원 → 팀장 → 임원으로 임원이 마지막에 발주해야 하므로, 임원 계정을 먼저 등록해 주세요.'
            : e.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fixed(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.subText, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('발주 품의서 작성'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fixed('제품', '${c['pr_name'] ?? ''} (${c['pr_id']})'),
                    _fixed('제조사', '${c['m_name']}'),
                    _fixed('현재 재고', '${c['now_count']}개 / 최소수량 ${c['least_count']}개'),
                    _fixed('발주 수량', '${c['suggested_count']}개 (기준재고 ${c['base_count']}개까지)'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '제조 단가(원)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '신청 사유', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('취소')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('품의 상신'),
        ),
      ],
    );
  }
}

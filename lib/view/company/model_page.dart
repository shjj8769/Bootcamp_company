import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 모델 계약: 계약서 / 해지 계약서 조회 (본사 앱 전용)
// GET /model/contact/list, /model/bussiness_contract/detail, /model/terminate/list
class ModelPage extends StatefulWidget {
  const ModelPage({super.key});

  @override
  State<ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends State<ModelPage> {
  int _tab = 0; // 0 계약서, 1 해지 계약서
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final path = _tab == 0 ? '/model/contact/list' : '/model/terminate/list';
    final res = await Api.get(path);
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() { _future = _load(); });

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 본사 앱에서만 확인 가능
    if (Session.kind != 'hq') {
      return const Center(child: Text('본사 직원만 확인할 수 있는 화면입니다.', style: TextStyle(color: AppColors.subText)));
    }
    return ListView(
      children: [
        const PageHeader(title: '모델 계약', subtitle: '모델 계약서와 해지 계약서를 확인하세요.'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('계약서')),
            ButtonSegment(value: 1, label: Text('해지 계약서')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => _selectTab(s.first),
        ),
        const SizedBox(height: 16),
        AsyncBody<List<Map<String, dynamic>>>(
          future: _future,
          onRetry: _reload,
          builder: (rows) => SectionCard(
            padding: EdgeInsets.zero,
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Center(
                      child: Text(_tab == 0 ? '계약서가 없습니다.' : '해지 계약서가 없습니다.',
                          style: const TextStyle(color: AppColors.subText)),
                    ),
                  )
                : Column(
                    children: _tab == 0
                        ? [
                            const TableHeaderRow(
                              labels: ['계약서번호', '모델', '담당자', '계약일', '계약기간', '계약금액'],
                              flex: [2, 3, 2, 2, 4, 3],
                            ),
                            for (final r in rows) _contactRow(r),
                          ]
                        : [
                            const TableHeaderRow(
                              labels: ['해지번호', '모델', '담당자', '해지일', '해지금액'],
                              flex: [2, 3, 2, 2, 3],
                            ),
                            for (final r in rows) _terminateRow(r),
                          ],
                  ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _cell(int flex, String text) =>
      Expanded(flex: flex, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)));

  Widget _rowBox({required VoidCallback? onTap, required List<Widget> children}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: children),
      ),
    );
  }

  Widget _contactRow(Map<String, dynamic> r) {
    return _rowBox(
      onTap: () => showDialog<void>(context: context, builder: (_) => _ContractDialog(contact: r)),
      children: [
        _cell(2, '${r['b_c_seq']}'),
        _cell(3, '${r['m_name'] ?? '-'}'),
        _cell(2, '${r['e_id'] ?? '-'}'),
        _cell(2, formatDate(r['c_date'])),
        _cell(4, '${formatDate(r['b_c_start_date'])} ~ ${formatDate(r['b_c_end_date'])}'),
        _cell(3, formatWon((r['b_c_price'] ?? 0) as num)),
      ],
    );
  }

  Widget _terminateRow(Map<String, dynamic> r) {
    return _rowBox(
      onTap: () => showDialog<void>(context: context, builder: (_) => _TerminateDialog(terminate: r)),
      children: [
        _cell(2, '${r['c_seq']}'),
        _cell(3, '${r['m_name'] ?? '-'}'),
        _cell(2, '${r['e_id'] ?? '-'}'),
        _cell(2, formatDate(r['t_date'])),
        _cell(3, formatWon((r['t_price'] ?? 0) as num)),
      ],
    );
  }
}

Widget _info(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.subText))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );

// 계약서 상세: 계약 목록 행 + 계약서 본문(b_c_detail)은 상세 API로 조회
class _ContractDialog extends StatelessWidget {
  final Map<String, dynamic> contact;

  const _ContractDialog({required this.contact});

  Future<Map<String, dynamic>> _load() async {
    final res = await Api.get('/model/bussiness_contract/detail', query: {'b_c_seq': '${contact['b_c_seq']}'});
    return Map<String, dynamic>.from(res as Map);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${contact['m_name'] ?? '모델'} 계약서'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _info('계약서번호', '${contact['b_c_seq']}'),
              _info('담당자', '${contact['e_id'] ?? '-'}'),
              _info('계약일', formatDate(contact['c_date'])),
              _info('계약기간', '${formatDate(contact['b_c_start_date'])} ~ ${formatDate(contact['b_c_end_date'])}'),
              _info('계약금액', formatWon((contact['b_c_price'] ?? 0) as num)),
              const Divider(height: 24),
              AsyncBody<Map<String, dynamic>>(
                future: _load(),
                onRetry: () {},
                builder: (d) => Text('${d['b_c_detail'] ?? ''}'),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기'))],
    );
  }
}

class _TerminateDialog extends StatelessWidget {
  final Map<String, dynamic> terminate;

  const _TerminateDialog({required this.terminate});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${terminate['m_name'] ?? '모델'} 해지 계약서'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info('해지번호', '${terminate['c_seq']}'),
            _info('담당자', '${terminate['e_id'] ?? '-'}'),
            _info('해지일', formatDate(terminate['t_date'])),
            _info('해지금액', formatWon((terminate['t_price'] ?? 0) as num)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기'))],
    );
  }
}

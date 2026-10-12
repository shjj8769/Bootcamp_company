import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';
import '../common/notice_summary.dart';

// 공지 관리: 공지/이벤트/운영 글 작성, 수정, 삭제
// GET /notice/list, POST /notice/insert, POST /notice/update, DELETE /notice/delete/{n_seq}
// DB의 제목/내용 컬럼이 45자까지라서 입력도 45자로 제한
class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _category; // null이면 전체
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/notice/list');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _openForm([Map<String, dynamic>? notice]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _NoticeFormDialog(notice: notice),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Map<String, dynamic> notice) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지 삭제'),
        content: Text('\'${notice['n_title']}\' 공지를 삭제할까요?\n삭제한 공지는 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.delete('/notice/delete/${notice['n_seq']}');
      if (!mounted) return;
      showMessage(context, '공지를 삭제했습니다.');
      _reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PageHeader(
          title: '공지 관리',
          subtitle: '고객에게 보이는 공지, 이벤트, 운영 안내를 작성하고 관리하세요.',
          trailing: FilledButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('공지 작성'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
          ),
        ),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _chip('전체', null),
              for (final c in noticeCategories) ...[
                const SizedBox(width: 8),
                _chip(c, c),
              ],
              const Spacer(),
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '제목 검색',
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

  Widget _chip(String label, String? value) {
    final selected = _category == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.sidebar,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
      onSelected: (_) => setState(() => _category = value),
    );
  }

  Widget _table(List<Map<String, dynamic>> all) {
    final rows = all.where((n) {
      if (_category != null && n['n_classification'] != _category) return false;
      return _keyword.isEmpty || '${n['n_title']}'.toLowerCase().contains(_keyword.toLowerCase());
    }).toList();
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: Text('공지가 없습니다.', style: TextStyle(color: AppColors.subText))),
      );
    }
    return Column(
      children: [
        const TableHeaderRow(labels: ['분류', '제목', '내용', '작성일', '관리'], flex: [2, 4, 5, 2, 3]),
        for (final n in rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Align(alignment: Alignment.centerLeft, child: NoticeBadge('${n['n_classification']}')),
                ),
                Expanded(
                  flex: 4,
                  child: Text('${n['n_title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 5,
                  child: Text('${n['n_detail'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.subText)),
                ),
                Expanded(flex: 2, child: Text(formatDate(n['n_date']), style: const TextStyle(fontSize: 13))),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      OutlinedButton(onPressed: () => _openForm(n), child: const Text('수정')),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _delete(n),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB3261E)),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// 공지 작성/수정 팝업 (notice가 null이면 새 공지)
class _NoticeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? notice;

  const _NoticeFormDialog({this.notice});

  @override
  State<_NoticeFormDialog> createState() => _NoticeFormDialogState();
}

class _NoticeFormDialogState extends State<_NoticeFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _detail;
  late String _category;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.notice != null;

  @override
  void initState() {
    super.initState();
    final n = widget.notice;
    _title = TextEditingController(text: n == null ? '' : '${n['n_title']}');
    _detail = TextEditingController(text: n == null ? '' : '${n['n_detail'] ?? ''}');
    _category = n == null ? noticeCategories.first : '${n['n_classification']}';
    if (!noticeCategories.contains(_category)) _category = noticeCategories.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final detail = _detail.text.trim();
    if (title.isEmpty || detail.isEmpty) {
      setState(() => _error = '제목과 내용을 모두 입력해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await Api.postForm('/notice/update', {
          'n_seq': '${widget.notice!['n_seq']}',
          'n_classification': _category,
          'n_title': title,
          'n_detail': detail,
        });
      } else {
        await Api.postForm('/notice/insert', {
          'n_classification': _category,
          'n_title': title,
          'n_detail': detail,
          'e_id': Session.eId,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showMessage(context, _isEdit ? '공지를 수정했습니다.' : '공지를 등록했습니다.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? '공지 수정' : '공지 작성'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '분류', border: OutlineInputBorder()),
                items: [for (final c in noticeCategories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                maxLength: 45,
                decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detail,
                maxLength: 45,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('취소')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
          child: Text(_isEdit ? '수정' : '등록'),
        ),
      ],
    );
  }
}

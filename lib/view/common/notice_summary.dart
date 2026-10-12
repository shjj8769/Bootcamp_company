import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

// 공지 분류
const noticeCategories = ['공지', '이벤트', '운영'];

// 운영 현황: 최근 공지/이벤트/운영 글을 분류별로 보여줌 (본사/대리점 대시보드 공용). GET /notice/list
class NoticeSummary extends StatefulWidget {
  final VoidCallback? onViewAll;
  final int limit;

  const NoticeSummary({super.key, this.onViewAll, this.limit = 5});

  @override
  State<NoticeSummary> createState() => _NoticeSummaryState();
}

class _NoticeSummaryState extends State<NoticeSummary> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _category;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/notice/list');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '운영 현황',
      trailing: widget.onViewAll == null ? null : TextButton(onPressed: widget.onViewAll, child: const Text('전체 보기 ›')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip('전체', null),
              for (final c in noticeCategories) ...[
                const SizedBox(width: 8),
                _chip(c, c),
              ],
              const Spacer(),
              if (widget.onViewAll != null) OutlinedButton(onPressed: widget.onViewAll, child: const Text('전체 보기')),
            ],
          ),
          const SizedBox(height: 8),
          AsyncBody<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: () => setState(() {
              _future = _load();
            }),
            builder: (all) {
              final rows = all.where((n) => _category == null || n['n_classification'] == _category).take(widget.limit).toList();
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('등록된 글이 없습니다.', style: TextStyle(color: AppColors.subText))),
                );
              }
              return Column(
                children: [
                  for (final n in rows)
                    InkWell(
                      onTap: widget.onViewAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                        child: Row(
                          children: [
                            SizedBox(width: 80, child: Align(alignment: Alignment.centerLeft, child: NoticeBadge('${n['n_classification']}'))),
                            Expanded(
                              child: Text('${n['n_title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Text(formatNoticeDate(n['n_date']), style: const TextStyle(fontSize: 12, color: AppColors.subText)),
                            const SizedBox(width: 10),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
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
}

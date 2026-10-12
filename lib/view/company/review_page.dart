import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_config.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 리뷰 관리: 고객 리뷰 목록과 상세(사진 포함). GET /review/list, /review/image/{r_seq}
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/review/list');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(title: '리뷰 관리', subtitle: '고객이 남긴 리뷰를 확인하고 제품 반응을 분석하세요.'),
        AsyncBody<List<Map<String, dynamic>>>(
          future: _future,
          onRetry: _reload,
          builder: (rows) {
            final avg = rows.isEmpty
                ? 0.0
                : rows.fold<num>(0, (s, r) => s + ((r['rating'] ?? 0) as num)) / rows.length;
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: KpiCard(label: '전체 리뷰', value: '${formatNumber(rows.length)}건')),
                    const SizedBox(width: 16),
                    Expanded(child: KpiCard(label: '평균 평점', value: avg.toStringAsFixed(1))),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: rows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 50),
                          child: Center(child: Text('리뷰가 없습니다.', style: TextStyle(color: AppColors.subText))),
                        )
                      : Column(
                          children: [
                            const TableHeaderRow(
                              labels: ['번호', '고객', '제품', '평점', '내용', '작성일'],
                              flex: [1, 2, 3, 2, 5, 2],
                            ),
                            for (final r in rows) _row(r),
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

  Widget _row(Map<String, dynamic> r) {
    final rating = ((r['rating'] ?? 0) as num).round();
    return InkWell(
      onTap: () => showDialog<void>(context: context, builder: (_) => _ReviewDialog(review: r)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Expanded(flex: 1, child: Text('${r['r_seq']}', style: const TextStyle(fontSize: 13))),
            Expanded(flex: 2, child: Text('${r['c_name'] ?? '-'}', style: const TextStyle(fontSize: 13))),
            Expanded(
              flex: 3,
              child: Text('${r['pr_name'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
            Expanded(
              flex: 2,
              child: Text('★' * rating + '☆' * (5 - rating).clamp(0, 5),
                  style: const TextStyle(color: AppColors.coral, fontSize: 14)),
            ),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Flexible(
                    child: Text('${r['post'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ),
                  if (r['has_image'] == 1 || r['has_image'] == true) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.image_outlined, size: 16, color: AppColors.subText),
                  ],
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(formatDate(r['r_date']), style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _ReviewDialog extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewDialog({required this.review});

  @override
  Widget build(BuildContext context) {
    final hasImage = review['has_image'] == 1 || review['has_image'] == true;
    return AlertDialog(
      title: Text('${review['pr_name'] ?? '리뷰'}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${review['c_name'] ?? '-'} · ${formatDate(review['r_date'])} · 평점 ${review['rating'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.subText)),
              if ((review['fit'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('착용감: ${review['fit']}', style: const TextStyle(fontSize: 12, color: AppColors.subText)),
              ],
              const SizedBox(height: 12),
              Text('${review['post'] ?? ''}'),
              if (hasImage) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '${AppConfig.baseUrl}/review/image/${review['r_seq']}',
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Text('이미지를 불러오지 못했습니다.'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기'))],
    );
  }
}

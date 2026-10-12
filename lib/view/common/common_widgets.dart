import 'package:flutter/material.dart';

import 'app_theme.dart';

String formatWon(num value) {
  final text = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final left = text.length - i;
    buf.write(text[i]);
    if (left > 1 && left % 3 == 1) buf.write(',');
  }
  return '₩$buf';
}

String formatNumber(num value) => formatWon(value).substring(1);

String formatDate(dynamic value) {
  if (value == null) return '-';
  final d = DateTime.tryParse(value.toString());
  if (d == null) return value.toString();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}.${two(d.month)}.${two(d.day)}';
}

// 화면 상단 제목 영역
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.subText)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// 흰색 카드 + 제목
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;

  const KpiCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.subText)),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.teal),
          ),
        ],
      ),
    );
  }
}

enum BadgeKind { wait, done, warn, info, strong }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeKind kind;

  const StatusBadge(this.text, {super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      BadgeKind.warn => (const Color(0xFFFFE1E3), const Color(0xFFB3261E)),
      BadgeKind.done => (AppColors.greenBg, AppColors.greenText),
      BadgeKind.info => (const Color(0xFFE1ECFF), const Color(0xFF1F4FA3)),
      BadgeKind.strong => (AppColors.sidebar, Colors.white),
      BadgeKind.wait => (AppColors.amberBg, AppColors.amberText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// 공지 분류 배지: 공지(파랑), 이벤트(노랑), 운영(초록)
class NoticeBadge extends StatelessWidget {
  final String category;

  const NoticeBadge(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    final kind = switch (category) {
      '이벤트' => BadgeKind.wait,
      '운영' => BadgeKind.done,
      _ => BadgeKind.info,
    };
    return StatusBadge(category, kind: kind);
  }
}

// 날짜 표시: 오늘이면 '오늘', 아니면 yyyy.MM.dd
String formatNoticeDate(dynamic value) {
  final d = DateTime.tryParse((value ?? '').toString());
  if (d == null) return '-';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return '오늘';
  return formatDate(value);
}

// 테이블 헤더 줄
class TableHeaderRow extends StatelessWidget {
  final List<String> labels;
  final List<int> flex;

  const TableHeaderRow({super.key, required this.labels, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(
                labels[i],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.subText),
              ),
            ),
        ],
      ),
    );
  }
}

// 비동기 데이터 로딩/에러/재시도 처리
class AsyncBody<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  const AsyncBody({super.key, required this.future, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snap.error.toString(), style: const TextStyle(color: AppColors.subText)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
                ],
              ),
            ),
          );
        }
        return builder(snap.data as T);
      },
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

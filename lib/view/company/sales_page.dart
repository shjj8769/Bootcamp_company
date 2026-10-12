import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 매출 현황: 일별/주별/월별 결제 금액 합계, 제품별 판매 수량, 매장별 제품 수량
// 결제 금액은 /payment/, 수량은 /purchase/ 응답을 앱에서 합산 (매장별 매출 금액은 표시하지 않음)
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

enum _Period { day, week, month }

class _SalesData {
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> purchases;
  final Map<int, String> storeNames;

  _SalesData(this.payments, this.purchases, this.storeNames);
}

class _SalesPageState extends State<SalesPage> {
  _Period _period = _Period.day;
  DateTime _base = DateTime.now();
  late Future<_SalesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SalesData> _load() async {
    final results = await Future.wait([
      Api.get('/payment/'),
      Api.get('/purchase/'),
      Api.get('/store/list').catchError((_) => {'results': []}),
    ]);
    List<Map<String, dynamic>> rows(dynamic res) =>
        ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final names = <int, String>{
      for (final s in rows(results[2])) s['store_seq'] as int: (s['name'] ?? '').toString(),
    };
    return _SalesData(rows(results[0]), rows(results[1]), names);
  }

  // 기준일이 속한 기간의 시작일
  DateTime _start(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    switch (_period) {
      case _Period.day:
        return day;
      case _Period.week:
        return day.subtract(Duration(days: day.weekday - 1));
      case _Period.month:
        return DateTime(d.year, d.month);
    }
  }

  DateTime _next(DateTime start) {
    switch (_period) {
      case _Period.day:
        return start.add(const Duration(days: 1));
      case _Period.week:
        return start.add(const Duration(days: 7));
      case _Period.month:
        return DateTime(start.year, start.month + 1);
    }
  }

  DateTime _prev(DateTime start) {
    switch (_period) {
      case _Period.day:
        return start.subtract(const Duration(days: 1));
      case _Period.week:
        return start.subtract(const Duration(days: 7));
      case _Period.month:
        return DateTime(start.year, start.month - 1);
    }
  }

  String _label(DateTime start) {
    switch (_period) {
      case _Period.day:
        return '${start.month}/${start.day}';
      case _Period.week:
        return '${start.month}/${start.day}~';
      case _Period.month:
        return '${start.month}월';
    }
  }

  String get _periodName => {_Period.day: '일별', _Period.week: '주별', _Period.month: '월별'}[_period]!;

  bool _inRange(dynamic value, DateTime from, DateTime to) {
    final d = DateTime.tryParse((value ?? '').toString());
    return d != null && !d.isBefore(from) && d.isBefore(to);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _base,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _base = picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(title: '매출 현황', subtitle: '기간별 결제 금액을 확인하고 제품 판매 수량을 비교하세요.'),
        Row(
          children: [
            for (final p in _Period.values) ...[
              _periodChip(p),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(formatDate(_base).replaceAll('.', '-')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncBody<_SalesData>(
          future: _future,
          onRetry: () => setState(() { _future = _load(); }),
          builder: _content,
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _periodChip(_Period p) {
    final selected = p == _period;
    final name = {_Period.day: '일별', _Period.week: '주별', _Period.month: '월별'}[p]!;
    return ChoiceChip(
      label: Text(name),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.sidebar,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.subText, fontWeight: FontWeight.w700),
      onSelected: (_) => setState(() => _period = p),
    );
  }

  Widget _content(_SalesData data) {
    final start = _start(_base);
    final end = _next(start);

    final payments = data.payments.where((p) => _inRange(p['pay_date'], start, end)).toList();
    final total = payments.fold<num>(0, (sum, p) => sum + ((p['pay_price'] ?? 0) as num));

    final purchases = data.purchases.where((p) => _inRange(p['p_date'], start, end)).toList();
    final byProduct = <String, int>{};
    final byStore = <int, int>{};
    for (final p in purchases) {
      final count = (p['p_count'] ?? 0) as int;
      final name = (p['pr_name'] ?? '알 수 없는 제품').toString();
      byProduct[name] = (byProduct[name] ?? 0) + count;
      final seq = (p['store_seq'] ?? 0) as int;
      byStore[seq] = (byStore[seq] ?? 0) + count;
    }
    final totalCount = byProduct.values.fold<int>(0, (a, b) => a + b);

    // 선택 기간까지 최근 7개 기간의 결제 합계 (그래프)
    final starts = <DateTime>[];
    var cursor = start;
    for (var i = 0; i < 7; i++) {
      starts.insert(0, cursor);
      cursor = _prev(cursor);
    }
    final sums = [
      for (final s in starts)
        data.payments
            .where((p) => _inRange(p['pay_date'], s, _next(s)))
            .fold<num>(0, (sum, p) => sum + ((p['pay_price'] ?? 0) as num))
            .toDouble(),
    ];

    final productEntries = byProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final storeEntries = byStore.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: KpiCard(label: '${formatDate(start)} $_periodName 매출', value: formatWon(total))),
            const SizedBox(width: 16),
            Expanded(child: KpiCard(label: '결제 건수', value: '${formatNumber(payments.length)}건')),
            const SizedBox(width: 16),
            Expanded(child: KpiCard(label: '판매 수량', value: '${formatNumber(totalCount)}개')),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '$_periodName 매출 추이',
          child: SizedBox(height: 260, child: _chart(starts, sums)),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SectionCard(
                title: '제품별 판매 수량',
                child: _rankList(
                  productEntries.map((e) => MapEntry(e.key, e.value)).toList(),
                  '이 기간에 판매된 제품이 없습니다.',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SectionCard(
                title: '매장별 제품 수량',
                child: _rankList(
                  storeEntries
                      .map((e) => MapEntry(data.storeNames[e.key] ?? '매장 ${e.key}', e.value))
                      .toList(),
                  '이 기간에 판매된 수량이 없습니다.',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chart(List<DateTime> starts, List<double> sums) {
    final maxY = sums.fold<double>(0, (m, v) => v > m ? v : m);
    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= starts.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_label(starts[i]), style: const TextStyle(fontSize: 11, color: AppColors.subText)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              formatWon(rod.toY),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < sums.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: sums[i],
                  width: 28,
                  color: i == sums.length - 1 ? AppColors.teal : AppColors.mint,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rankList(List<MapEntry<String, int>> items, String emptyText) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(emptyText, style: const TextStyle(color: AppColors.subText))),
      );
    }
    final maxValue = items.first.value == 0 ? 1 : items.first.value;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(item.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.value / maxValue,
                      minHeight: 10,
                      backgroundColor: AppColors.background,
                      color: AppColors.mint,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text('${formatNumber(item.value)}개', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

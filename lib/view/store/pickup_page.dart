import 'package:flutter/material.dart';
// TODO: 에뮬레이터 테스트 중 카메라 때문에 앱이 종료되어 임시 비활성화 (실기기 테스트 시 주석 해제)
// import 'package:mobile_scanner/mobile_scanner.dart';

import '../common/api_client.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 고객 픽업: 고객이 매장에 오면 주문을 골라 QR을 생성(POST /qr/issue)하고, 고객 앱에 표시된 같은 QR을 카메라로 스캔해 인증(POST /qr/scan)
// 인증되면 대리점 재고가 주문 수량만큼 줄고 QR은 바로 폐기됨 (QR은 5분 유효, 1회용)
class StorePickupPage extends StatefulWidget {
  const StorePickupPage({super.key});

  @override
  State<StorePickupPage> createState() => _StorePickupPageState();
}

class _StorePickupPageState extends State<StorePickupPage> {
  // final _scanner = MobileScannerController(
  //   formats: const [BarcodeFormat.qrCode],
  //   detectionSpeed: DetectionSpeed.noDuplicates,
  // );
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _success = false;

  // 고객 QR 생성: 우리 매장 주문으로 QR 코드를 만들면 고객 앱에도 같은 QR이 표시됨. 코드는 글자로도 보여주고 입력칸에 자동으로 채움
  List<Map<String, dynamic>> _orders = [];
  int? _demoOrderId;
  String? _demoCode;
  String? _demoError;
  bool _issuing = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // 우리 매장(store_seq)에서 받을 구매 내역
  Future<void> _loadOrders() async {
    try {
      final res = await Api.get('/purchase/');
      final rows = ((res['results'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((p) => p['store_seq'] == Session.storeSeq)
          .toList();
      if (mounted) setState(() => _orders = rows);
    } catch (_) {
      // 목록을 못 불러와도 QR 스캔과 직접 입력은 그대로 사용 가능
    }
  }

  Future<void> _issueDemo() async {
    final order = _orders.where((o) => o['p_id'] == _demoOrderId).firstOrNull;
    if (order == null) {
      setState(() => _demoError = '주문을 선택해 주세요.');
      return;
    }
    setState(() {
      _issuing = true;
      _demoError = null;
      _demoCode = null;
    });
    try {
      final res = await Api.postForm('/qr/issue', {'p_id': '${order['p_id']}'});
      if (!mounted) return;
      setState(() {
        _demoCode = '${res['code']}';
        _codeController.text = '${res['code']}';
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _demoError = e.message == 'already picked up' ? '이미 픽업이 완료된 주문입니다.' : (e.message == 'order not found' ? '우리 매장의 주문이 아닙니다.' : e.message));
      }
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  @override
  void dispose() {
    // _scanner.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    final value = code.trim();
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final res = await Api.postForm('/qr/scan', {'code': value});
      if (!mounted) return;
      setState(() {
        _success = true;
        _message = '픽업 인증 완료 · ${res['pr_id']} ${res['count']}개를 고객에게 전달하세요.';
        _codeController.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = e.message == 'not enough stock'
            ? '매장 재고가 부족합니다. 입고 확인을 먼저 해주세요.'
            : (e.message == 'invalid or expired qr' ? '유효하지 않거나 만료된 QR입니다. 고객 앱에서 새 QR을 받아 주세요.' : e.message);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageHeader(title: '고객 픽업', subtitle: '고객의 QR 코드를 카메라로 스캔해 상품 수령을 확인하세요.'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SectionCard(
                title: 'QR 스캔',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 380,
                    // child: MobileScanner(
                    //   controller: _scanner,
                    //   onDetect: (capture) {
                    //     final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
                    //     if (code != null) _verify(code);
                    //   },
                    //   errorBuilder: (context, error) => Center(
                    //     child: Padding(
                    //       padding: const EdgeInsets.all(24),
                    //       child: Text(
                    //         '카메라를 사용할 수 없습니다. 카메라 권한을 확인하거나 오른쪽에 코드를 직접 입력해 주세요.',
                    //         textAlign: TextAlign.center,
                    //         style: const TextStyle(color: AppColors.subText),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '카메라 스캔은 임시로 비활성화되었습니다. 오른쪽에 코드를 직접 입력해 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subText),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  SectionCard(
                    title: '코드 직접 입력',
                    child: Column(
                      children: [
                        TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(labelText: 'QR 코드', border: OutlineInputBorder()),
                          onSubmitted: _verify,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : () => _verify(_codeController.text),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.sidebar),
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('인증하기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _demoCard(),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _success ? AppColors.greenBg : const Color(0xFFFFE1E3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _success ? AppColors.greenText : const Color(0xFFB3261E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // 고객 QR 생성 카드
  Widget _demoCard() {
    return SectionCard(
      title: '고객 QR 생성',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '고객이 매장에 오면 주문을 선택해 QR을 생성하세요. 고객 앱에 같은 QR이 표시되고, 그 QR을 스캔하면 인증됩니다. 카메라를 쓸 수 없으면 아래 코드가 위 입력칸에 자동으로 채워집니다. (5분 안에 인증)',
            style: TextStyle(fontSize: 12, color: AppColors.subText, height: 1.4),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _demoOrderId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '주문 선택', border: OutlineInputBorder()),
            items: [
              for (final o in _orders)
                DropdownMenuItem(
                  value: o['p_id'] as int,
                  child: Text(
                    'ORD-${o['p_id']} · ${o['pr_name'] ?? o['SKU']} · ${o['p_count']}개 · ${o['email']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _issuing ? null : (v) => setState(() => _demoOrderId = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _issuing || _orders.isEmpty ? null : _issueDemo,
              child: _issuing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_orders.isEmpty ? '우리 매장 주문이 없습니다' : 'QR 생성'),
            ),
          ),
          if (_demoError != null) ...[
            const SizedBox(height: 10),
            Text(_demoError!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
          ],
          if (_demoCode != null) ...[
            const SizedBox(height: 14),
            const Text('생성된 QR 코드', style: TextStyle(fontSize: 12, color: AppColors.subText)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(
                _demoCode!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

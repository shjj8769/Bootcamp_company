import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../common/api_client.dart';
import '../common/app_config.dart';
import '../common/app_theme.dart';
import '../common/common_widgets.dart';

// 대리점 관리: 네이버 지도에 서울 25개 대리점을 마커로 표시, 마커를 누르면 매장명과 상세주소 표시
// 매출 등 다른 정보는 보여주지 않음 (GET /store/list). 매장명, 상세주소, 전화번호만 표시
class StoreMapPage extends StatefulWidget {
  const StoreMapPage({super.key});

  @override
  State<StoreMapPage> createState() => _StoreMapPageState();
}

class _StoreMapPageState extends State<StoreMapPage> {
  late Future<List<Map<String, dynamic>>> _future;
  Map<String, dynamic>? _selected;
  String? _mapError;
  bool _mapLoaded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    await AppConfig.load();
    if (AppConfig.naverClientId.isEmpty) {
      throw ApiException('네이버지도 Client ID가 없습니다. .env의 NAVER_MAP_CLIENT_ID를 확인해 주세요.');
    }
    await FlutterNaverMap().init(
      clientId: AppConfig.naverClientId,
      onAuthFailed: (e) {
        if (mounted) setState(() => _mapError = _authMessage(e));
      },
    );
    final res = await Api.get('/store/list');
    return ((res['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // 인증 실패 원인별 안내 (NCP 콘솔 Maps 애플리케이션 설정과 대조)
  String _authMessage(NAuthFailedException e) {
    final hint = switch (e) {
      NUnauthorizedClientException() =>
        'Client ID가 NCP에 없거나, 이 앱의 패키지명(com.example.project_company)이 애플리케이션에 등록되지 않았거나, Dynamic Map이 선택되지 않았습니다.',
      NQuotaExceededException() => '지도 사용량 한도를 초과했습니다.',
      NClientUnspecifiedException() => 'Client ID가 앱에 전달되지 않았습니다. .env를 확인해 주세요.',
      _ => '알 수 없는 인증 오류입니다.',
    };
    return '네이버지도 인증에 실패했습니다.\n$hint\n(${e.runtimeType} / code ${e.code} / ${e.message})';
  }

  // 지도 SDK가 타일을 받아 오면 onMapLoaded가 호출됨. 12초 안에 안 뜨면 확인할 점을 안내
  void _watchMapLoad() {
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && !_mapLoaded && _mapError == null) {
        setState(() => _mapError = '지도가 12초 안에 표시되지 않았습니다.\n'
            '1) 에뮬레이터/태블릿의 인터넷 연결  2) .env의 NAVER_MAP_CLIENT_ID\n'
            '3) NCP 콘솔 Maps 애플리케이션에 앱 패키지명(com.example.project_company)이 등록되어 있는지 확인해 주세요.');
      }
    });
  }

  Future<void> _onMapReady(NaverMapController controller, List<Map<String, dynamic>> stores) async {
    // 목업처럼 코랄색 원형 마커 (기본 아이콘에 색을 덧입히면 흐릿해져서 직접 그린 아이콘을 사용)
    final icon = await NOverlayImage.fromWidget(
      widget: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.coral,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
      size: const Size(26, 26),
      context: context,
    );
    for (final s in stores) {
      final lat = (s['lat'] as num?)?.toDouble();
      final lng = (s['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final marker = NMarker(
        id: 'store_${s['store_seq']}',
        position: NLatLng(lat, lng),
        icon: icon,
        caption: NOverlayCaption(text: (s['name'] ?? '').toString(), textSize: 12),
      );
      marker.setOnTapListener((_) {
        setState(() => _selected = s);
        controller.updateCamera(NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lng)));
      });
      controller.addOverlay(marker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(title: '대리점 관리', subtitle: '서울 25개 자치구 대리점 위치를 확인하세요.'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SectionCard(
              title: '서울 대리점 지도',
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Expanded(
                child: AsyncBody<List<Map<String, dynamic>>>(
                  future: _future,
                  onRetry: () => setState(() { _future = _load(); }),
                  builder: _map,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _map(List<Map<String, dynamic>> stores) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(target: NLatLng(37.5519, 126.9918), zoom: 10.5),
              locationButtonEnable: false,
            ),
            onMapReady: (controller) {
              _watchMapLoad();
              _onMapReady(controller, stores);
            },
            onMapLoaded: () {
              if (mounted) {
                setState(() {
                  _mapLoaded = true;
                  _mapError = null;
                });
              }
            },
            onMapTapped: (point, latLng) => setState(() => _selected = null),
          ),
          if (!_mapLoaded && _mapError == null)
            const Center(child: Text('지도를 불러오는 중...', style: TextStyle(color: AppColors.subText))),
          if (_mapError != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: const Color(0xFFFFE1E3),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_mapError!, style: const TextStyle(color: Color(0xFFB3261E))),
                ),
              ),
            ),
          if (_selected != null)
            Positioned(
              right: 20,
              bottom: 20,
              child: _infoCard(_selected!),
            ),
        ],
      ),
    );
  }

  // 마커를 눌렀을 때 나오는 매장 정보 (매장명 + 상세주소)
  Widget _infoCard(Map<String, dynamic> store) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${store['name'] ?? ''}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _selected = null),
                child: const Icon(Icons.close, size: 20, color: AppColors.subText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${store['address'] ?? '주소 정보가 없습니다.'}',
            style: const TextStyle(fontSize: 14, color: AppColors.subText, height: 1.4),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 15, color: AppColors.subText),
              const SizedBox(width: 6),
              Text(
                (store['phone'] ?? '').toString().isEmpty ? '전화번호 정보가 없습니다.' : '${store['phone']}',
                style: const TextStyle(fontSize: 14, color: AppColors.subText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

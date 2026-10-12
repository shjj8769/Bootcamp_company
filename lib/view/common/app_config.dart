import 'package:flutter_dotenv/flutter_dotenv.dart';

// 앱 설정: 프로젝트 루트의 .env 하나만 읽음 (서버와 같은 파일을 pubspec의 assets로 앱에 포함)
// - API_BASE_URL: 앱이 접속할 서버 주소 (에뮬레이터는 http://10.0.2.2:8000). 없으면 API_HOST:API_PORT로 만듦
// - NAVER_MAP_CLIENT_ID: 네이버지도 Client ID
// 주의: .env에는 DB 정보도 있고 그대로 앱에 포함되므로 팀프로젝트(비배포) 용도로만 사용
class AppConfig {
  static String baseUrl = '';
  static String naverClientId = '';
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    await dotenv.load(fileName: '.env');
    final explicit = (dotenv.env['API_BASE_URL'] ?? '').trim();
    final host = (dotenv.env['API_HOST'] ?? '').trim();
    final port = (dotenv.env['API_PORT'] ?? '').trim();
    baseUrl = explicit.isNotEmpty ? explicit : (host.isEmpty ? '' : 'http://$host${port.isEmpty ? '' : ':$port'}');
    naverClientId = (dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '').trim();
    _loaded = true;
  }
}

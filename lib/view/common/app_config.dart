import 'package:flutter_dotenv/flutter_dotenv.dart';

// 앱 전용 설정 (assets/app.env). DB 정보가 있는 서버용 .env와는 별개 파일
class AppConfig {
  static String baseUrl = '';
  static String naverClientId = '';
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    await dotenv.load(fileName: 'assets/app.env');
    baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    naverClientId = dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '';
    _loaded = true;
  }
}

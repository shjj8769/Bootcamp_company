import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

// 로그인한 직원 정보와 토큰 (앱 실행 중에만 메모리에 보관)
class Session {
  static String? token;
  static Map<String, dynamic> employee = {};
  static String kind = ''; // 'hq' 본사, 'store' 대리점

  static String get eId => (employee['e_id'] ?? '').toString();
  static int get storeSeq => (employee['store_seq'] ?? 0) as int;

  static void clear() {
    token = null;
    employee = {};
    kind = '';
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

// FastAPI 서버 호출 공통 처리. 토큰이 있으면 Authorization 헤더에 붙임
class Api {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  static Map<String, String> get _headers => {
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  static dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 401) {
      throw ApiException('로그인이 만료되었습니다. 다시 로그인해 주세요.');
    }
    if (res.statusCode == 403) {
      throw ApiException('이 화면을 볼 권한이 없습니다.');
    }
    if (res.statusCode >= 400) {
      final detail = body is Map ? body['detail'] : null;
      throw ApiException(detail?.toString() ?? '서버 오류 (${res.statusCode})');
    }
    // 백엔드는 실패해도 200으로 {'result': 'Error', 'message': ...}를 돌려주는 경우가 있음
    if (body is Map && body['result'] == 'Error') {
      throw ApiException((body['message'] ?? '요청을 처리하지 못했습니다.').toString());
    }
    return body;
  }

  // 연결 실패 시 원인(오류 종류)과 접속 주소를 함께 알려 줌
  static ApiException _connectError(Object e) => ApiException(
        '서버에 연결할 수 없습니다. 네트워크와 서버 주소를 확인해 주세요.\n'
        '주소: ${AppConfig.baseUrl.isEmpty ? '(설정 없음)' : AppConfig.baseUrl}\n'
        '원인: ${e.runtimeType}',
      );

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    try {
      final res = await http
          .get(_uri(path, query), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectError(e);
    }
  }

  static Future<dynamic> delete(String path) async {
    try {
      final res = await http
          .delete(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectError(e);
    }
  }

  // Form 형식 POST (inquire, office_stock, qr 등 Form 파라미터 API)
  static Future<dynamic> postForm(String path, Map<String, String> fields) async {
    try {
      final res = await http
          .post(_uri(path), headers: _headers, body: fields)
          .timeout(const Duration(seconds: 15));
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectError(e);
    }
  }

  // JSON 형식 POST/PUT (refund, hq_return 등 BaseModel 바디 API)
  static Future<dynamic> sendJson(String method, String path, Map<String, dynamic> body) async {
    try {
      final req = http.Request(method, _uri(path))
        ..headers.addAll({..._headers, 'Content-Type': 'application/json'})
        ..body = jsonEncode(body);
      final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 15)),
      );
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _connectError(e);
    }
  }
}

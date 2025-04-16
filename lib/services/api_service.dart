import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:tomapto/services/token_manager.dart';

class ApiService {
  // 토큰 매니저 인스턴스
  static final _tokenManager = TokenManager();

  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    // Android 플랫폼이면서 URL이 localhost를 포함하는 경우
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      // 에뮬레이터에서는 10.0.2.2로 localhost 대체
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }

    // 다른 플랫폼이거나 이미 localhost가 아닌 경우 원래 URL 반환
    return baseUrl;
  }

  // 토큰 가져오기 - 토큰 매니저 사용
  static Future<String?> getToken() async {
    return await _tokenManager.getToken();
  }

  // 로그인 요청 메소드 - 토큰 매니저 사용
  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
  ) async {
    try {
      // API 기본 URL 가져오기
      final apiBaseUrl = getApiBaseUrl();

      print('API URL: $apiBaseUrl/account/login');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'user_password': password}),
      );

      // 응답 로깅 (디버깅용)
      print('API 응답 코드: ${response.statusCode}');
      print('API 응답 데이터: ${response.body}');

      // 응답 파싱
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // 로그인 성공 시 토큰 매니저에 토큰 저장
        await _tokenManager.saveToken(responseData['token']);

        // 사용자 정보 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', responseData['user']['user_id']);

        // 로그인 유지 체크 시 추가 설정
        if (responseData['remember_me'] ?? false) {
          await prefs.setBool('remember_me', true);
        }
      }

      return responseData;
    } catch (e) {
      print('API 호출 오류 상세: $e');
      rethrow; // 오류를 다시 던져서 상위 레벨에서 처리하도록 함
    }
  }

  // 프로필 정보 가져오기 - 토큰 매니저 사용
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await _tokenManager.getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      print('프로필 API 호출: $apiBaseUrl/account/profile');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/account/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // 응답 로깅 (디버깅용)
      print('프로필 API 응답 코드: ${response.statusCode}');
      print('프로필 API 응답 데이터: ${response.body}');

      // 응답 파싱
      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        // 인증 오류 발생 시 토큰 제거
        await _tokenManager.clearToken();
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      }

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '프로필 정보를 가져오는데 실패했습니다.');
      }

      return responseData;
    } catch (e) {
      print('프로필 API 호출 오류: $e');
      rethrow;
    }
  }

  // 로그아웃 요청 - 토큰 매니저 사용
  static Future<Map<String, dynamic>> logout() async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await _tokenManager.getToken();

      if (token == null) {
        // 토큰이 없는 경우 (이미 로그아웃 상태)
        return {'success': true, 'message': '이미 로그아웃 상태입니다.'};
      }

      print('로그아웃 API 호출: $apiBaseUrl/account/logout');

      // 서버에 로그아웃 요청
      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // 응답 로깅 (디버깅용)
      print('로그아웃 API 응답 코드: ${response.statusCode}');
      print('로그아웃 API 응답 데이터: ${response.body}');

      // 로컬 토큰 삭제
      await _tokenManager.clearToken();

      // 응답 파싱 (실패하더라도 로컬에서는 로그아웃 처리)
      try {
        return json.decode(response.body);
      } catch (e) {
        return {'success': true, 'message': '로컬에서 로그아웃 처리 완료'};
      }
    } catch (e) {
      print('로그아웃 API 호출 오류: $e');

      // 오류가 발생하더라도 로컬에서는 로그아웃 처리
      await _tokenManager.clearToken();
      return {'success': true, 'message': '서버 연결 오류, 로컬에서 로그아웃 처리 완료'};
    }
  }

  // 인증이 필요한 API 호출을 위한 헤더 생성
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await _tokenManager.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // 인증 상태 확인
  static Future<bool> isAuthenticated() async {
    return await _tokenManager.isTokenValid();
  }
}

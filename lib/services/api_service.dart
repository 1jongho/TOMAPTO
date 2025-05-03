import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiService {
  static String getApiBaseUrl() {
    // 기본 URL 가져오기
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 디버그 모드이고 안드로이드 플랫폼인 경우
    if (kDebugMode && Platform.isAndroid) {
      // localhost를 사용 중이고 LOCAL_IP가 설정되어 있다면
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        // localhost를 LOCAL_IP로 대체
        return baseUrl.replaceAll('localhost', localIp);
      }

      // 에뮬레이터 특정 주소 처리
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }

    // 그 외의 경우 원래 URL 반환
    return baseUrl;
  }

  // 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 로그인 요청 메소드
  static Future<Map<String, dynamic>> login(
    String userId,
    String password, [
    bool rememberMe = true, // 기본값 true로 설정 (선택적 파라미터) - 쉼표 제거
  ]) async {
    try {
      // API 기본 URL 가져오기
      final apiBaseUrl = getApiBaseUrl();

      print('API URL: $apiBaseUrl/account/login');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'user_password': password,
          'remember_me': rememberMe, // rememberMe 값 서버에 전송
        }),
      );

      // 응답 로깅 (디버깅용)
      print('API 응답 코드: ${response.statusCode}');
      print('API 응답 데이터: ${response.body}');

      // 응답 파싱
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // 로그인 성공 시 토큰과 사용자 정보 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        await prefs.setString('user_id', responseData['user']['user_id']);

        // remember_me 값 저장 - 앱 종료 후에도 로그인 상태 유지할지 결정
        await prefs.setBool('remember_me', rememberMe);
      }

      return responseData;
    } catch (e) {
      print('API 호출 오류 상세: $e');
      rethrow; // 오류를 다시 던져서 상위 레벨에서 처리하도록 함
    }
  }

  // 프로필 정보 가져오기
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

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

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '프로필 정보를 가져오는데 실패했습니다.');
      }

      return responseData;
    } catch (e) {
      print('프로필 API 호출 오류: $e');
      rethrow;
    }
  }

  // 로그아웃 요청
  static Future<Map<String, dynamic>> logout() async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

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

      // 로컬 저장소에서 토큰과 사용자 정보 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_id');
      // remember_me 설정은 유지 (사용자 편의성 향상)

      // 응답 파싱 (실패하더라도 로컬에서는 로그아웃 처리)
      try {
        return json.decode(response.body);
      } catch (e) {
        return {'success': true, 'message': '로컬에서 로그아웃 처리 완료'};
      }
    } catch (e) {
      print('로그아웃 API 호출 오류: $e');

      // 오류가 발생하더라도 로컬에서는 로그아웃 처리
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user_id');
        // remember_me 설정은 유지 (사용자 편의성 향상)

        return {'success': true, 'message': '서버 연결 오류, 로컬에서 로그아웃 처리 완료'};
      } catch (e) {
        throw Exception('로그아웃 처리 중 오류가 발생했습니다: $e');
      }
    }
  }
}

// Enhanced token_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/pages/profile/login.dart';
import 'package:tomapto/services/real_time_location_service.dart';

class TokenService {
  // JWT 토큰 디코딩 메서드
  static Map<String, dynamic>? parseJwt(String token) {
    try {
      // JWT 토큰 형식: xxxxx.yyyyy.zzzzz
      final parts = token.split('.');
      if (parts.length != 3) {
        print('토큰 형식이 유효하지 않습니다.');
        return null;
      }

      // payload 부분(yyyyy)을 디코딩
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      var resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);

      // 디버깅용 로그
      print('파싱된 토큰 데이터: ${payloadMap.keys.join(', ')}');

      return payloadMap;
    } catch (e) {
      print('토큰 파싱 오류: $e');
      return null;
    }
  }

  // 토큰 만료 확인 메서드
  static bool isTokenExpired(String token) {
    try {
      final Map<String, dynamic>? decodedToken = parseJwt(token);

      if (decodedToken == null) {
        print('토큰 파싱 실패');
        return true; // 파싱 실패 시 만료된 것으로 간주
      }

      // JWT의 exp 클레임(만료 시간) 확인
      final exp = decodedToken['exp'];
      if (exp == null) {
        print('토큰에 만료 시간(exp)이 없습니다. 토큰 내용: $decodedToken');
        return false; // exp 필드가 없으면 만료되지 않은 것으로 간주
      }

      // 만료 시간은 초 단위로 저장됨, 현재 시간은 밀리초 단위이므로 변환 필요
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      final isExpired = now.isAfter(expiry);

      // 디버깅용 로그
      print('토큰 만료시간: $expiry, 현재시간: $now, 만료됨: $isExpired');

      return isExpired;
    } catch (e) {
      print('토큰 만료 확인 오류: $e');
      return false; // 오류 발생 시에도 토큰을 유효한 것으로 간주
    }
  }

  // 토큰 유효성 검사 및 필요시 로그아웃 처리
  static Future<bool> validateToken(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // 토큰이 없는 경우
    if (token == null) {
      print('토큰이 없습니다.');
      _redirectToLogin(context);
      return false;
    }

    // 현재 세션에서 로그인한 경우는 remember_me 설정과 관계없이 로그인 상태 유지
    if (isLoggedIn) {
      // 토큰이 만료된 경우만 확인
      if (isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 로그인 페이지로 이동합니다.');
        await _logout();
        _redirectToLogin(context);
        return false;
      }
      return true; // 현재 세션 로그인 + 토큰 유효 = 로그인 상태 유지
    }

    // 자동 로그인(remember_me)이 활성화된 경우
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (rememberMe) {
      // 토큰이 만료된 경우
      if (isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 로그인 페이지로 이동합니다.');
        await _logout();
        _redirectToLogin(context);
        return false;
      }
      return true; // 자동 로그인 + 토큰 유효 = 로그인 상태 유지
    }

    // 현재 세션에서 로그인하지 않았고, 자동 로그인도 비활성화된 경우
    print('자동 로그인이 비활성화되어 있고 현재 세션에 로그인하지 않았습니다.');
    await _logout();
    _redirectToLogin(context);
    return false;
  }

  // 로그아웃 처리 (토큰 및 관련 정보 삭제)
  static Future<void> _logout() async {
    // 실시간 위치 업데이트 서비스 중지
    try {
      final locationService = RealTimeLocationService();
      await locationService.stopLocationUpdates();
    } catch (e) {
      print('위치 업데이트 서비스 중지 오류: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('is_logged_in'); // 세션 로그인 상태 제거
    // remember_me 설정은 유지 (사용자 편의성 향상)
    print('로그아웃 처리 완료');
  }

  // 로그인 페이지로 리디렉션
  static void _redirectToLogin(BuildContext context) {
    // 현재 라우트가 로그인 페이지가 아닐 경우에만 리디렉션
    if (ModalRoute.of(context)?.settings.name != '/login') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false, // 모든 이전 라우트 제거
      );
    }
  }

  // 토큰 리프레시 (선택적 기능)
  static Future<bool> refreshToken() async {
    // 실제 구현을 위해서는 서버에 요청하여 토큰을 갱신해야 함
    // 예시 코드만 제공
    try {
      print('토큰 갱신 시도');
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('token');

      if (oldToken == null) {
        print('갱신할 토큰이 없습니다.');
        return false;
      }

      // 여기서 실제 API 호출을 통해 새 토큰을 발급받아야 함
      // ...

      // 토큰 저장
      // await prefs.setString('token', newToken);

      return true;
    } catch (e) {
      print('토큰 갱신 실패: $e');
      return false;
    }
  }
}

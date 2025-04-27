import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/pages/profile/login.dart';

class TokenService {
  // JWT 토큰 디코딩 메서드
  static Map<String, dynamic>? parseJwt(String token) {
    try {
      // JWT 토큰 형식: xxxxx.yyyyy.zzzzz
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      // payload 부분(yyyyy)을 디코딩
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      var resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);

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
        return true; // 파싱 실패 시 만료된 것으로 간주
      }

      // JWT의 exp 클레임(만료 시간) 확인
      final exp = decodedToken['exp'];
      if (exp == null) {
        return true; // exp 필드가 없으면 만료된 것으로 간주
      }

      // 만료 시간은 초 단위로 저장됨, 현재 시간은 밀리초 단위이므로 변환 필요
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      return now.isAfter(expiry);
    } catch (e) {
      print('토큰 만료 확인 오류: $e');
      return true; // 오류 발생 시 만료된 것으로 간주
    }
  }

  // 토큰 유효성 검사 및 필요시 로그아웃 처리
  static Future<bool> validateToken(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // 토큰이 없는 경우
    if (token == null || token.isEmpty) {
      _redirectToLogin(context);
      return false;
    }

    // 토큰이 만료된 경우
    if (isTokenExpired(token)) {
      print('토큰이 만료되었습니다. 로그인 페이지로 이동합니다.');
      await _logout();
      _redirectToLogin(context);
      return false;
    }

    return true; // 토큰이 유효함
  }

  // 로그아웃 처리 (토큰 및 관련 정보 삭제)
  static Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('remember_me');
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
}

// services/token_manager.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  // 싱글톤 인스턴스
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  // 토큰 검증을 위한 타이머
  Timer? _tokenValidationTimer;

  // 토큰 유효성 상태
  bool _isTokenValid = false;

  // 토큰 유효 기간 (밀리초)
  final int _tokenValidityDuration = 24 * 60 * 60 * 1000; // 24시간

  // 기본적인 검증 간격 (밀리초)
  final int _validationInterval = 30 * 60 * 1000; // 30분마다 검증

  // 토큰 저장
  Future<bool> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      // 토큰 저장 시간 기록
      final tokenTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('token_timestamp', tokenTimestamp);

      _isTokenValid = true;
      // 토큰 유효성 검증 타이머 시작
      _startTokenValidationTimer();

      return true;
    } catch (e) {
      print('토큰 저장 오류: $e');
      return false;
    }
  }

  // 토큰 가져오기
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 토큰이 유효한지 먼저 확인
      if (await isTokenValid()) {
        return prefs.getString('token');
      } else {
        return null;
      }
    } catch (e) {
      print('토큰 가져오기 오류: $e');
      return null;
    }
  }

  // 토큰 삭제 (로그아웃)
  Future<bool> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('token_timestamp');
      await prefs.remove('user_id');
      _isTokenValid = false;

      // 검증 타이머 중지
      _tokenValidationTimer?.cancel();
      _tokenValidationTimer = null;

      return true;
    } catch (e) {
      print('토큰 삭제 오류: $e');
      return false;
    }
  }

  // 토큰 유효성 검증
  Future<bool> isTokenValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // 토큰이 없으면 유효하지 않음
      if (token == null) {
        _isTokenValid = false;
        return false;
      }

      // 토큰 저장 시간 확인
      final tokenTimestamp = prefs.getInt('token_timestamp');
      if (tokenTimestamp == null) {
        _isTokenValid = false;
        return false;
      }

      // 현재 시간과 비교하여 유효 기간 확인
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final tokenAge = currentTime - tokenTimestamp;

      // 유효 기간이 지났으면 만료 처리
      if (tokenAge > _tokenValidityDuration) {
        print('토큰 만료됨');
        await clearToken();
        _isTokenValid = false;
        return false;
      }

      _isTokenValid = true;
      return true;
    } catch (e) {
      print('토큰 유효성 검증 오류: $e');
      _isTokenValid = false;
      return false;
    }
  }

  // 토큰 유효성 주기적 검증 타이머 시작
  void _startTokenValidationTimer() {
    // 기존 타이머가 있으면 취소
    _tokenValidationTimer?.cancel();

    // 새 타이머 시작
    _tokenValidationTimer = Timer.periodic(
      Duration(milliseconds: _validationInterval),
      (_) async {
        await isTokenValid();
      },
    );
  }

  // 현재 토큰 상태 반환
  bool get isValid => _isTokenValid;
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:tomapto/services/api_service.dart';
import 'package:tomapto/services/token_manager.dart';
import 'package:tomapto/services/real_time_location_service.dart';

class LoginController {
  // 텍스트 필드 컨트롤러
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode idFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  // 폼 키
  final formKey = GlobalKey<FormState>();

  // 상태 변수
  bool rememberMe = false;
  bool obscureText = true;
  bool isLoading = false;
  String errorMessage = '';

  // 토큰 매니저와 위치 서비스 인스턴스
  final _tokenManager = TokenManager();
  final _locationService = RealTimeLocationService();

  // 컨트롤러 dispose 메서드
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    idFocusNode.dispose();
    passwordFocusNode.dispose();
  }

  // 비밀번호 표시/숨김 토글
  void togglePasswordVisibility(Function setState) {
    setState(() {
      obscureText = !obscureText;
    });
  }

  // 로그인 유지 상태 토글
  void toggleRememberMe(Function setState) {
    setState(() {
      rememberMe = !rememberMe;
    });
  }

  // 로그인 메서드
  Future<bool> login(BuildContext context, Function setState) async {
    // 폼 유효성 검사
    if (formKey.currentState?.validate() ?? false) {
      // 로딩 상태 시작
      setState(() {
        isLoading = true;
        errorMessage = ''; // 에러 메시지 초기화
      });

      try {
        print('로그인 시도: ${idController.text}');

        // API 호출
        final response = await ApiService.login(
          idController.text,
          passwordController.text,
        );

        // 로그인 성공 처리
        if (response['success'] == true) {
          // 로그인 유지 설정 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('remember_me', rememberMe);

          // 실시간 위치 서비스 시작
          await _locationService.startLocationUpdates();

          return true;
        } else {
          // 로그인 실패 처리
          setState(() {
            errorMessage = response['message'] ?? '로그인에 실패했습니다.';
          });
          return false;
        }
      } catch (e) {
        // 오류 처리
        print('로그인 오류: $e');
        setState(() {
          if (e is http.ClientException) {
            errorMessage = '서버에 연결할 수 없습니다: ${e.toString()}';
          } else {
            errorMessage = '서버 연결에 실패했습니다. 나중에 다시 시도해주세요.';
          }
        });
        return false;
      } finally {
        // 로딩 상태 종료
        setState(() {
          isLoading = false;
        });
      }
    }
    return false;
  }

  // 로그인 상태 확인 메소드
  Future<bool> checkLoginStatus() async {
    try {
      // 토큰 유효성 확인
      bool isTokenValid = await _tokenManager.isTokenValid();

      if (isTokenValid) {
        // 로그인 유지 확인
        final prefs = await SharedPreferences.getInstance();
        final rememberMe = prefs.getBool('remember_me') ?? false;

        if (rememberMe) {
          // 실시간 위치 서비스 시작
          await _locationService.startLocationUpdates();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('로그인 상태 확인 오류: $e');
      return false;
    }
  }
}

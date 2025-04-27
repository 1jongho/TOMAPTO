import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

class LoginController {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode idFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  final formKey = GlobalKey<FormState>();
  bool rememberMe = false;
  bool obscureText = true;
  bool isLoading = false;
  String errorMessage = '';

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
        final responseData = await ApiService.login(
          idController.text,
          passwordController.text,
          rememberMe, // rememberMe 값 전달
        );

        // 로그인 성공 처리
        if (responseData['success'] == true) {
          // 로그인 유지 설정은 ApiService.login에서 이미 처리됨
          return true;
        } else {
          // 로그인 실패 처리
          setState(() {
            errorMessage = responseData['message'] ?? '로그인에 실패했습니다.';
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    // 토큰이 존재하고 로그인 유지가 활성화된 경우 자동 로그인
    if (token != null && rememberMe) {
      return true;
    }
    return false;
  }
}

// API 서비스 클래스
class ApiService {
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

  // 로그인 요청 메소드
  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
    bool rememberMe,
  ) async {
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
          'remember_me': rememberMe,
        }),
      );

      // 응답 로깅 (디버깅용)
      print('API 응답 코드: ${response.statusCode}');
      print('API 응답 데이터: ${response.body}');

      // 응답 파싱
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // 로그인 성공 시 토큰 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        await prefs.setString('user_id', responseData['user']['user_id']);

        // 로그인 유지 설정 저장
        await prefs.setBool('remember_me', rememberMe);
      }

      return responseData;
    } catch (e) {
      print('API 호출 오류 상세: $e');
      rethrow;
    }
  }

  // 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 로그아웃
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('remember_me'); // remember_me 설정도 제거
  }
}

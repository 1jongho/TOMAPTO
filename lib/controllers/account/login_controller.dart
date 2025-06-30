// login_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/services/push_notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:tomapto/services/location_service.dart';
import 'package:tomapto/services/real_time_location_service.dart';

class LoginController {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode idFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  final formKey = GlobalKey<FormState>();
  bool rememberMe = true; // 기본값은 true로 설정
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

  // 위치 업데이트를 위한 메서드 - 위치 공유는 하지 않음
  Future<void> _updateUserLocation() async {
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          print('위치 권한이 거부되었습니다.');
          return;
        }
      }

      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('위치 서비스가 비활성화되어 있습니다.');
        return;
      }

      // 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 위치 정보를 서버에 업데이트 - 위치 공유는 하지 않음
      await LocationService.updateMyLocation(
        position.latitude,
        position.longitude,
      );

      print('로그인 후 위치 업데이트 성공: ${position.latitude}, ${position.longitude}');

      // 실시간 위치 업데이트 서비스 시작 - 이것은 내 위치 표시를 위해 필요함
      // 중요: 친구와의 위치 공유 요청은 포함하지 않음
      final realTimeLocationService = RealTimeLocationService();
      await realTimeLocationService.startLocationUpdates();
    } catch (e) {
      print('위치 업데이트 실패: $e');
    }
  }

  Future<bool> login(BuildContext context, Function setState) async {
    // 폼 유효성 검사
    if (formKey.currentState?.validate() ?? false) {
      // 로딩 상태 시작
      setState(() {
        isLoading = true;
        errorMessage = ''; // 에러 메시지 초기화
      });

      try {
        print('로그인 시도: ${idController.text}, rememberMe: $rememberMe');

        // API 호출
        final responseData = await ApiService.login(
          idController.text,
          passwordController.text,
          rememberMe, // rememberMe 값 전달
        );

        // 로그인 성공 처리
        if (responseData['success'] == true) {
          // 토큰과 사용자 ID를 저장합니다.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', responseData['token']);
          await prefs.setString('user_id', responseData['user']['user_id']);
          await prefs.setBool('remember_me', rememberMe);

          // 중요: 현재 세션 로그인 상태를 항상 true로 설정
          // 이렇게 하면 remember_me가 false여도 현재 앱 세션에서는 로그인 상태 유지
          await prefs.setBool('is_logged_in', true);

          print('로그인 성공: 토큰 저장됨. remember_me=$rememberMe, is_logged_in=true');

          // 🔥 FCM 토큰 저장 추가
          try {
            print('🔥 로그인 후 FCM 토큰 저장 시작');
            await _saveFCMTokenToServer();
            print('🔥 로그인 후 FCM 토큰 저장 완료');
          } catch (e) {
            print('🔥 로그인 후 FCM 토큰 저장 실패: $e');
          }

          // 자동 위치 서비스 시작 코드 제거 (이 부분을 삭제하면 로그인 시 위치 활성화가 자동으로 되지 않음)

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
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // 토큰이 있고 로그인 유지가 활성화된 경우 또는 현재 세션에서 로그인한 경우
    if (token != null && (rememberMe || isLoggedIn)) {
      return true;
    }
    return false;
  }

  Future<void> _saveFCMTokenToServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        print('🔥 Auth Token 없음 - FCM 토큰 저장 불가');
        return;
      }

      final fcmToken = await PushNotificationService().getCurrentToken();
      if (fcmToken == null) {
        print('🔥 FCM Token 없음');
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiService.getApiBaseUrl()}/account/save-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({'fcm_token': fcmToken}),
      );

      print('🔥 FCM 토큰 서버 응답: ${response.statusCode}');
      print('🔥 FCM 토큰 서버 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        print('🔥 FCM 토큰 서버 저장 성공');
      } else {
        print('🔥 FCM 토큰 서버 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 FCM 토큰 저장 오류: $e');
    }
  }
}

// API 서비스 클래스
class ApiService {
  // API 기본 URL 가져오기
  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 에뮬레이터에서 실행 중인 경우
    if (Platform.isAndroid) {
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
        await prefs.setBool('is_logged_in', true); // 현재 세션 로그인 상태 저장
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
    await prefs.remove('is_logged_in'); // 현재 세션 로그인 상태 제거
    // remember_me 설정은 유지하여 다음 로그인 시 사용자 편의성 향상
  }
}

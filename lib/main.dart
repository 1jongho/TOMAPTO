import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/pages/map/naver_map.dart';
import 'package:tomapto/services/real_time_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 네이버 맵 초기화 메서드 선언
Future<void> init({
  String? clientId,
  Function(NAuthFailedException ex)? onAuthFailed,
}) async {
  // FlutterNaverMap 인스턴스를 생성하고 init 메서드 호출
  await FlutterNaverMap().init(clientId: clientId, onAuthFailed: onAuthFailed);
}

// 로그인 상태 확인 및 위치 서비스 시작
Future<void> initLocationServiceIfLoggedIn() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // 로그인 상태인 경우에만 위치 서비스 시작
    if (token != null && (rememberMe || isLoggedIn)) {
      final locationService = RealTimeLocationService();
      if (!locationService.isRunning) {
        print('앱 시작 시 위치 서비스 초기화 중...');
        await locationService.startLocationUpdates();
      }
    }
  } catch (e) {
    print('위치 서비스 초기화 오류: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  try {
    // 네이버 맵 초기화 - 새로 선언한 init 메서드 사용
    await init(
      clientId: dotenv.env['NAVER_API_KEY'] ?? '',
      onAuthFailed: (NAuthFailedException ex) {
        print('네이버 맵 인증 실패: ${ex.message}');
      },
    );
    print('네이버 맵 초기화 성공');

    // 로그인 상태 확인 및 위치 서비스 시작
    await initLocationServiceIfLoggedIn();
  } catch (e) {
    print('초기화 중 오류 발생: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      home: const NaverMapPage(),
    );
  }
}

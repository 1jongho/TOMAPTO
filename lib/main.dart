import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/pages/map/naver_map.dart';
import 'package:tomapto/services/real_time_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  // 네이버 맵 초기화
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_API_KEY'] ?? '',
    onAuthFailed: (error) {
      print('네이버 맵 인증 실패: $error');
    },
  );

  // 로그인 상태 확인 및 위치 서비스 시작
  await _initializeLocationService();

  runApp(const MyApp());
}

// 위치 서비스 초기화 함수
Future<void> _initializeLocationService() async {
  try {
    // 로그인 상태 확인
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // 토큰이 있으면 로그인된 상태로 간주
    if (token != null && token.isNotEmpty) {
      print('사용자 로그인 상태 확인됨: 위치 서비스 시작');

      // 실시간 위치 서비스 시작
      final locationService = RealTimeLocationService();
      await locationService.startLocationUpdates();
    } else {
      print('로그인되지 않음: 위치 서비스를 시작하지 않습니다.');
    }
  } catch (e) {
    print('위치 서비스 초기화 오류: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '토맵토',
      theme: ThemeData(fontFamily: 'Pretendard'),
      home: const NaverMapPage(),
    );
  }
}

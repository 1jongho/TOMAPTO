import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/pages/profile/login.dart';
import 'package:tomapto/pages/map/transit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  // 네이버 맵 초기화 (네이버 맵 페이지를 사용할 때 필요)
  try {
    await NaverMapSdk.instance.initialize(
      clientId: dotenv.env['NAVER_API_KEY'] ?? '',
      onAuthFailed: (error) {
        print('네이버 맵 인증 실패: $error');
      },
    );
  } catch (e) {
    print('네이버 맵 초기화 실패: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOMAPTO',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard',
      ),
      // 시작 페이지 설정
      home: const LoginPage(), // 로그인 페이지를 홈 화면으로 설정
      // 아래 주석을 해제하면 지도 페이지를 홈 화면으로 설정할 수 있습니다
      // home: const NaverMapPage(),
    );
  }
}

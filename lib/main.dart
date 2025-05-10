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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          surface: Colors.white,
          secondary: Color(0xFF2196F3),
        ),
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: Color(0xFFFB233B),
          circularTrackColor: Colors.grey.withOpacity(0.2),
        ),

        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white,
          modalBackgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),

        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith<Color>((
              Set<MaterialState> states,
            ) {
              if (states.contains(MaterialState.pressed)) {
                return Color(0xFF388E3C);
              }
              return Color(0xFF4CAF50);
            }),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            overlayColor: MaterialStateProperty.resolveWith<Color>((
              Set<MaterialState> states,
            ) {
              if (states.contains(MaterialState.pressed)) {
                return Colors.green.withOpacity(0.1);
              }
              return Colors.transparent; // 투명으로 설정하여 보라색 효과 제거
            }),
            // 스플래시 팩토리 추가
            splashFactory: NoSplash.splashFactory,
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.resolveWith<Color>((
              Set<MaterialState> states,
            ) {
              if (states.contains(MaterialState.pressed)) {
                return Color(0xFF363636);
              }
              return Color(0xFF363636);
            }),
            // TextButton에도 스플래시 효과 제거
            splashFactory: NoSplash.splashFactory,
            overlayColor: MaterialStateProperty.resolveWith<Color>((
              Set<MaterialState> states,
            ) {
              if (states.contains(MaterialState.pressed)) {
                return Color(0xFF363636).withOpacity(0.3);
              }
              return Colors.transparent;
            }),
          ),
        ),
      ),
      home: NaverMapPage(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';
import 'package:tomapto/controllers/map/transit_provider.dart';
import 'package:tomapto/pages/intro.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tomapto/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // .env 파일 로드
    await dotenv.load(fileName: ".env");

    print('🚀 Firebase 초기화 시작');
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY']!,
        appId: dotenv.env['FIREBASE_APP_ID']!,
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
        projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      ),
    );
    print('🚀 Firebase 초기화 성공');

    // 백그라운드 메시지 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 네이버 맵 초기화
    await FlutterNaverMap().init(
      clientId: dotenv.env['NAVER_API_KEY'] ?? '',
      onAuthFailed: (NAuthFailedException ex) {
        print('네이버 맵 인증 실패: ${ex.message}');
      },
    );
    print('네이버 맵 초기화 성공');

    // 푸시 알림 서비스 초기화
    await PushNotificationService().initialize();
    print('푸시 알림 서비스 초기화 성공');
  } catch (e) {
    print('앱 초기화 중 오류: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupPushNotificationNavigation();
    _initializePushNotifications();
  }

  /// 푸시알림 초기화 및 FCM 토큰 등록
  void _initializePushNotifications() async {
    print('🚀 푸시알림 초기화 시작');
    try {
      print('🚀 PushNotificationService 초기화 중...');
      await PushNotificationService().initialize();
      print('🚀 PushNotificationService 초기화 완료');

      print('🚀 3초 대기 중...');
      await Future.delayed(Duration(seconds: 3));
      print('🚀 3초 대기 완료');

      print('🚀 FCM 토큰 서버 저장 시작');
      await _saveFCMTokenToServer();
      print('🚀 FCM 토큰 서버 저장 완료');

      print('🔥 FCM 토큰 등록 완료');
    } catch (e) {
      print('🚀 푸시알림 초기화 오류: $e');
    }
  }

  /// FCM 토큰을 서버에 저장
  Future<void> _saveFCMTokenToServer() async {
    try {
      print('🔥 FCM 토큰 저장 시작');

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      print('🔥 Auth Token 존재: ${authToken != null}');
      if (authToken != null) {
        print('🔥 Auth Token 길이: ${authToken.length}');
      }

      if (authToken == null) {
        print('🔥 Auth Token 없음 - 로그인 필요');
        return;
      }

      final fcmToken = await PushNotificationService().getCurrentToken();
      print('🔥 FCM Token 획득: ${fcmToken?.substring(0, 20)}...');

      if (fcmToken == null) {
        print('🔥 FCM Token 없음');
        return;
      }

      print('🔥 서버 요청 시작: http://172.30.1.42:8080/api/account/save-fcm-token');

      final response = await http.post(
        Uri.parse('http://172.30.1.42:8080/api/account/save-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({'fcm_token': fcmToken}),
      );

      print('🔥 서버 응답 상태: ${response.statusCode}');
      print('🔥 서버 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        print('🔥 FCM 토큰 서버 등록 성공!');
      } else {
        print('🔥 FCM 토큰 서버 등록 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 FCM 토큰 서버 등록 오류: $e');
    }
  }

  /// 푸시 알림 네비게이션 설정
  void _setupPushNotificationNavigation() {
    PushNotificationService().setNavigationCallback((data) {
      _handlePushNotificationNavigation(data);
    });
  }

  /// 푸시 알림 클릭 시 네비게이션 처리
  void _handlePushNotificationNavigation(Map<String, dynamic> data) {
    final currentContext = navigatorKey.currentContext;
    if (currentContext == null) return;

    // 찾아가기 관련 알림 처리
    if (data['type'] == 'find_way') {
      final friendId = data['friend_id'];
      final friendName = data['friend_name'] ?? '친구';

      if (friendId != null) {
        // 실시간 위치 공유 페이지로 이동
        Navigator.of(currentContext).pushNamed(
          '/real_time_location',
          arguments: {'id': friendId, 'name': friendName},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TransitProvider(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Color(0xFF4C9EFC),
            selectionColor: Color(0xFF4C9EFC).withOpacity(0.2),
            selectionHandleColor: Color(0xFF4C9EFC),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Color(0xFF388E3C);
                }
                return Color(0xFF4CAF50);
              }),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
              overlayColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Colors.green.withOpacity(0.1);
                }
                return Colors.transparent;
              }),
              splashFactory: NoSplash.splashFactory,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Color(0xFF363636);
                }
                return Color(0xFF363636);
              }),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Color(0xFF363636).withOpacity(0.3);
                }
                return Colors.transparent;
              }),
            ),
          ),
        ),
        home: IntroPage(),
      ),
    );
  }
}

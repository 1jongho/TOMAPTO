import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';
import 'package:tomapto/controllers/map/transit_provider.dart';
import 'package:tomapto/pages/intro.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tomapto/services/push_notification_service.dart';
import 'package:tomapto/pages/friends/real_time_location_sharing.dart';
import 'package:tomapto/services/socket_service.dart';
import 'firebase_options.dart';

//  추가: 전역 NavigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Firebase 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('백그라운드 메시지 처리: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ 1. WidgetsFlutterBinding 초기화 완료');

  try {
    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ 2. Firebase 초기화 완료');

    // Firebase 백그라운드 메시지 핸들러 설정
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('✅ 3. 백그라운드 메시지 핸들러 설정 완료');

    // FCM 초기 설정
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    print('✅ 4. FCM 포그라운드 설정 완료');

    // 알림 권한 요청
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print(' 알림 권한 상태: ${settings.authorizationStatus}');

    // FCM 토큰 확인
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print(' FCM Token: $fcmToken');

    // 푸시알림 서비스 초기화
    final pushService = PushNotificationService();

    //  추가: 실시간 위치 페이지로 이동하는 콜백 설정
    pushService.onNavigateToFindWay = (friendData) {
      print(' 푸시알림 클릭 - 실시간 위치 페이지로 이동: $friendData');

      //  추가: 위치 공유 자동 시작
      final socketService = SocketService();
      if (!socketService.isConnected) {
        socketService.initSocket().then((_) {
          socketService.startLocationSharing(friendData['id'].toString(), null);
          print(' 소켓 연결 후 위치 공유 시작');
        });
      } else {
        socketService.startLocationSharing(friendData['id'].toString(), null);
        print(' 위치 공유 시작');
      }

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (context) =>
                  RealTimeLocationSharingPage(selectedFriend: friendData),
        ),
      );
    };

    await pushService.initialize();

    // 알림 채널 생성 (Android)
    await pushService.createNotificationChannel();
    print('✅ 8. 알림 채널 생성 완료');
  } catch (e) {
    print('❌ 7-8. 푸시알림 서비스 초기화 실패: $e');
    print('⚠️ 푸시알림 기능 제외하고 앱 계속 실행');
  }

  print(' 푸시알림 서비스 초기화 완료');
  // 토큰 새로고침 리스너
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print(' FCM Token 새로고침: $newToken');
  });

  try {
    await dotenv.load(fileName: ".env");
    print('✅ 10. dotenv 로드 완료');

    await FlutterNaverMap().init(
      clientId: dotenv.env['NAVER_API_KEY'] ?? '',
      onAuthFailed: (NAuthFailedException ex) {
        print('❌ 네이버 맵 인증 실패: ${ex.message}');
      },
    );
    print('✅ 11. 네이버 맵 초기화 성공');
  } catch (e) {
    print('❌ 10-11. 앱 초기화 중 오류: $e');
    print('⚠️ 일부 기능 제한되지만 앱 계속 실행');
  }

  print('🚀 모든 초기화 완료 - 앱 시작');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TransitProvider(),
      child: MaterialApp(
        navigatorKey: navigatorKey, //  추가: 전역 NavigatorKey 설정
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

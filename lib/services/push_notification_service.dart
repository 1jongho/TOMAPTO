// lib/services/push_notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // 찾아가기 페이지 네비게이션 콜백
  Function(Map<String, dynamic>)? onNavigateToFindWay;

  // 초기화 완료 여부
  bool _isInitialized = false;

  /// 푸시알림 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Firebase 초기화 확인
      await Firebase.initializeApp();

      _firebaseMessaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      // 권한 요청
      await _requestPermission();

      // 로컬 알림 초기화
      await _initializeLocalNotifications();

      // FCM 토큰 가져오기 및 저장
      await _saveDeviceToken();

      // 메시지 핸들러 설정
      _setupMessageHandlers();

      _isInitialized = true;
      print('푸시알림 서비스 초기화 완료');
    } catch (e) {
      print('푸시알림 서비스 초기화 실패: $e');
    }
  }

  /// 알림 권한 요청
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('사용자가 알림 권한을 허용했습니다');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('사용자가 임시 알림 권한을 허용했습니다');
    } else {
      print('사용자가 알림 권한을 거부했습니다');
    }
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
  }

  /// FCM 토큰 가져오기 및 저장
  Future<void> _saveDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        print('FCM 토큰 저장됨: $token');
      }
    } catch (e) {
      print('FCM 토큰 저장 실패: $e');
    }
  }

  /// 메시지 핸들러 설정
  void _setupMessageHandlers() {
    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드에서 알림 클릭 처리
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 앱이 종료된 상태에서 알림 클릭 처리
    _handleInitialMessage();
  }

  /// 포그라운드에서 메시지 수신 처리
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('포그라운드에서 메시지 수신: ${message.messageId}');

    // 찾아가기 관련 알림인 경우 로컬 알림 표시
    if (message.data['type'] == 'find_way') {
      await _showLocalNotification(message);
    }
  }

  /// 백그라운드에서 알림 클릭 처리
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('백그라운드에서 알림 클릭됨: ${message.messageId}');
    _navigateToFindWayPage(message.data);
  }

  /// 앱 종료 상태에서 알림 클릭 처리
  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('앱 종료 상태에서 알림 클릭됨: ${initialMessage.messageId}');
      _navigateToFindWayPage(initialMessage.data);
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'find_way_channel',
          '찾아가기 알림',
          channelDescription: '찾아가기 요청 및 응답 알림',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? '찾아가기 알림',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: json.encode(message.data),
    );
  }

  /// 로컬 알림 클릭 처리
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      final data = json.decode(response.payload!);
      _navigateToFindWayPage(data);
    }
  }

  /// 찾아가기 페이지로 네비게이션
  void _navigateToFindWayPage(Map<String, dynamic> data) {
    if (onNavigateToFindWay != null && data['type'] == 'find_way') {
      onNavigateToFindWay!(data);
    }
  }

  /// 네비게이션 콜백 설정
  void setNavigationCallback(Function(Map<String, dynamic>) callback) {
    onNavigateToFindWay = callback;
  }

  /// 현재 FCM 토큰 가져오기
  Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('FCM 토큰 가져오기 실패: $e');
      return null;
    }
  }

  /// 토큰 새로고침 리스너 설정
  void setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('FCM 토큰 새로고침됨: $newToken');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
      // 서버에 새 토큰 전송 (필요 시 구현)
    });
  }

  /// 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('토픽 구독 성공: $topic');
    } catch (e) {
      print('토픽 구독 실패: $e');
    }
  }

  /// 특정 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('토픽 구독 해제 성공: $topic');
    } catch (e) {
      print('토픽 구독 해제 실패: $e');
    }
  }

  /// 알림 채널 생성 (Android)
  Future<void> createNotificationChannel() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'find_way_channel',
        '찾아가기 알림',
        description: '찾아가기 요청 및 응답 알림',
        importance: Importance.max,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  /// 서비스 정리
  void dispose() {
    _isInitialized = false;
  }
}

/// 백그라운드 메시지 핸들러 (최상위 함수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('백그라운드 메시지 처리: ${message.messageId}');

  // 백그라운드에서 별도 처리가 필요한 경우 여기에 구현
  if (message.data['type'] == 'find_way') {
    print('찾아가기 백그라운드 알림: ${message.data}');
  }
}

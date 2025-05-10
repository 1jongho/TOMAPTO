import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class SocketService {
  // 싱글톤 인스턴스
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  // 소켓 객체
  IO.Socket? _socket;

  // 이벤트 스트림 컨트롤러
  final _friendRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendAcceptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationSharingStartedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationSharingStoppedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendStatusChangeController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 이벤트 스트림 게터
  Stream<Map<String, dynamic>> get onFriendRequest =>
      _friendRequestController.stream;
  Stream<Map<String, dynamic>> get onFriendAccept =>
      _friendAcceptController.stream;
  Stream<Map<String, dynamic>> get onLocationUpdate =>
      _locationUpdateController.stream;
  Stream<Map<String, dynamic>> get onLocationSharingStarted =>
      _locationSharingStartedController.stream;
  Stream<Map<String, dynamic>> get onLocationSharingStopped =>
      _locationSharingStoppedController.stream;
  Stream<Map<String, dynamic>> get onFriendStatusChange =>
      _friendStatusChangeController.stream;

  // 소켓 서버 URL 가져오기
  String _getSocketUrl() {
    // 먼저 SOCKET_URL 환경변수를 확인
    String socketUrl = dotenv.env['SOCKET_URL'] ?? '';

    // SOCKET_URL이 없으면 API_BASE_URL에서 파생
    if (socketUrl.isEmpty) {
      String baseUrl =
          dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
      // API URL에서 /api 부분 제거
      socketUrl = baseUrl.replaceAll('/api', '');

      String? localIp = dotenv.env['LOCAL_IP'];

      // 안드로이드 에뮬레이터에서 실행 중인 경우
      if (Platform.isAndroid) {
        // localhost를 사용 중이고 LOCAL_IP가 설정되어 있다면
        if (socketUrl.contains('localhost') &&
            localIp != null &&
            localIp.isNotEmpty) {
          // localhost를 LOCAL_IP로 대체
          socketUrl = socketUrl.replaceAll('localhost', localIp);
        }

        // 에뮬레이터 특정 주소 처리
        if (socketUrl.contains('localhost')) {
          socketUrl = socketUrl.replaceAll('localhost', '10.0.2.2');
        }
      }
    }

    print('소켓 URL: $socketUrl');
    return socketUrl;
  }

  // 소켓 연결 초기화
  Future<void> initSocket() async {
    if (_socket != null && _socket!.connected) {
      print('소켓이 이미 연결되어 있습니다.');
      return;
    }

    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다.');
        return;
      }

      final socketUrl = _getSocketUrl();
      print('소켓 서버 연결 시도: $socketUrl');

      // 소켓 객체 생성 및 설정
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // polling 폴백 추가
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'}) // 헤더에도 토큰 추가
            .setAuth({'token': token}) // auth 객체에 토큰 전달
            .enableForceNew() // 새 연결 강제
            .enableReconnection() // 재연결 활성화
            .setReconnectionAttempts(5) // 최대 5번 재시도
            .setReconnectionDelay(3000) // 3초마다 재연결 시도
            .build(),
      );

      // 소켓 이벤트 리스너 설정
      _setupSocketListeners();

      // 소켓 연결
      _socket!.connect();

      print('소켓 연결 초기화 성공');
    } catch (e) {
      print('소켓 초기화 오류: $e');
    }
  }

  // 소켓 이벤트 리스너 설정
  void _setupSocketListeners() {
    _socket!.on('connect', (_) {
      print('소켓 연결 성공! ID: ${_socket!.id}');
    });

    _socket!.on('connect_error', (error) {
      print('소켓 연결 오류: $error');
    });

    _socket!.on('connect_timeout', (_) {
      print('소켓 연결 시간 초과');
    });

    _socket!.on('disconnect', (_) {
      print('소켓 연결 해제!');
    });

    _socket!.on('error', (error) {
      print('소켓 오류: $error');
    });

    // 친구 요청 이벤트
    _socket!.on('friend_request', (data) {
      print('친구 요청 수신: $data');
      _friendRequestController.add(Map<String, dynamic>.from(data));
    });

    // 친구 수락 이벤트
    _socket!.on('friend_accept', (data) {
      print('친구 수락 수신: $data');
      _friendAcceptController.add(Map<String, dynamic>.from(data));
    });

    // 위치 업데이트 이벤트
    _socket!.on('location_update', (data) {
      print('위치 업데이트 수신: $data');
      _locationUpdateController.add(Map<String, dynamic>.from(data));
    });

    // 위치 공유 시작 이벤트
    _socket!.on('location_sharing_started', (data) {
      print('위치 공유 시작 수신: $data');
      _locationSharingStartedController.add(Map<String, dynamic>.from(data));
    });

    // 위치 공유 종료 이벤트
    _socket!.on('location_sharing_stopped', (data) {
      print('위치 공유 종료 수신: $data');
      _locationSharingStoppedController.add(Map<String, dynamic>.from(data));
    });

    // 친구 상태 변경 이벤트 (온라인/오프라인)
    _socket!.on('friend_status_change', (data) {
      print('친구 상태 변경 수신: $data');
      _friendStatusChangeController.add(Map<String, dynamic>.from(data));
    });

    // 연결 성공 이벤트
    _socket!.on('connect_success', (data) {
      print('연결 성공 이벤트: $data');
    });
  }

  // 친구 요청 전송
  void sendFriendRequest(String recipientId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('send_friend_request', {'recipient_id': recipientId});
    print('친구 요청 전송: $recipientId');
  }

  // 친구 요청 수락
  void acceptFriendRequest(dynamic requestId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    // requestId를 문자열로 변환하여 사용
    String stringRequestId = requestId?.toString() ?? '';
    if (stringRequestId.isEmpty) {
      print('유효하지 않은 요청 ID입니다.');
      return;
    }

    _socket!.emit('accept_friend_request', {'request_id': stringRequestId});
    print('친구 요청 수락: $stringRequestId');
  }

  // 친구 요청 거절
  void rejectFriendRequest(dynamic requestId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    // requestId를 문자열로 변환하여 사용
    String stringRequestId = requestId?.toString() ?? '';
    if (stringRequestId.isEmpty) {
      print('유효하지 않은 요청 ID입니다.');
      return;
    }

    _socket!.emit('reject_friend_request', {'request_id': stringRequestId});
    print('친구 요청 거절: $stringRequestId');
  }

  // 위치 공유 시작 (durationMinutes가 null이면 무제한 공유)
  void startLocationSharing(String friendId, int? durationMinutes) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    // 소켓으로 위치 공유 시작 이벤트 전송
    _socket!.emit('start_location_sharing', {
      'friend_id': friendId,
      'duration_minutes': durationMinutes, // null일 경우 무제한
    });

    print('위치 공유 시작: $friendId, 기간: ${durationMinutes ?? "무제한"}');
  }

  // 위치 공유 종료
  void stopLocationSharing(String friendId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    // 소켓으로 위치 공유 종료 이벤트 전송
    _socket!.emit('stop_location_sharing', {'friend_id': friendId});
    print('위치 공유 종료: $friendId');
  }

  // 위치 업데이트 전송
  void sendLocationUpdate(
    double latitude,
    double longitude,
    double? heading,
    double? accuracy,
  ) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다. 위치 업데이트를 보낼 수 없습니다.');
      initSocket(); // 연결이 끊어졌으면 다시 연결 시도
      return;
    }

    // 모든 속성이 null이 아닌지 확인
    Map<String, dynamic> data = {'latitude': latitude, 'longitude': longitude};

    // 선택적 속성은 null이 아닐 때만 추가
    if (heading != null) data['heading'] = heading;
    if (accuracy != null) data['accuracy'] = accuracy;

    print('위치 업데이트 전송: $data');
    _socket!.emit('update_location', data);
  }

  // 소켓 연결 해제
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      print('소켓 연결 해제 완료');
    }
  }

  // 자원 해제
  void dispose() {
    disconnect();
    _friendRequestController.close();
    _friendAcceptController.close();
    _locationUpdateController.close();
    _locationSharingStartedController.close();
    _locationSharingStoppedController.close();
    _friendStatusChangeController.close();
  }

  // 연결 상태 확인
  bool get isConnected => _socket?.connected ?? false;

  // 재연결 시도
  Future<void> reconnect() async {
    disconnect();
    await initSocket();
  }
}

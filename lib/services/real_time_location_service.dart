// Enhanced real_time_location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/services/location_service.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RealTimeLocationService {
  // 싱글톤 인스턴스
  static final RealTimeLocationService _instance =
      RealTimeLocationService._internal();
  factory RealTimeLocationService() => _instance;
  RealTimeLocationService._internal();

  // 위치 스트림 구독
  StreamSubscription<Position>? _positionStreamSubscription;

  // 위치 갱신 상태
  bool _isRunning = false;

  // 위치 업데이트 간격 (초)
  final int _updateIntervalSeconds = 20; // 30초 -> 20초로 변경 (더 자주 업데이트)

  // 백그라운드 작업 타이머
  Timer? _backgroundTimer;

  // 현재 위치 스트림 설정
  LocationSettings get _locationSettings => LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // 10m -> 5m로 변경 (더 작은 거리 변화에도 업데이트)
    timeLimit: Duration(seconds: _updateIntervalSeconds),
  );

  // 위치 업데이트 시작
  Future<bool> startLocationUpdates() async {
    // 이미 실행 중이면 중복 실행 방지
    if (_isRunning) return true;

    try {
      // 로그인 상태 확인
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        print('위치 업데이트를 시작하려면 로그인이 필요합니다.');
        return false;
      }

      // 위치 권한 확인
      bool hasPermission = await LocationService.checkLocationPermission();
      if (!hasPermission) {
        print('위치 권한이 없거나 위치 서비스가 비활성화되어 있습니다.');
        return false;
      }

      // 소켓 서비스 초기화 - 위치 업데이트 전에 소켓 연결 확인
      final socketService = SocketService();
      if (!socketService.isConnected) {
        await socketService.initSocket();
      }

      // 스트림 구독 시작
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: (error) {
          print('위치 스트림 오류: $error');
          _isRunning = false;
        },
        onDone: () {
          print('위치 스트림 종료');
          _isRunning = false;
        },
      );

      _isRunning = true;
      print('실시간 위치 업데이트 서비스 시작됨');

      // 즉시 한 번 업데이트 실행
      _updateCurrentLocation();

      // 백그라운드 타이머 시작 (앱이 백그라운드에 있을 때도 주기적으로 위치 업데이트)
      _startBackgroundTimer();

      return true;
    } catch (e) {
      print('위치 업데이트 서비스 시작 오류: $e');
      _isRunning = false;
      return false;
    }
  }

  // 백그라운드 타이머 시작
  void _startBackgroundTimer() {
    // 기존 타이머가 있으면 취소
    _backgroundTimer?.cancel();

    // 백그라운드에서도 주기적으로 위치를 업데이트하기 위한 타이머
    _backgroundTimer = Timer.periodic(
      Duration(minutes: 5), // 5분마다
      (timer) async {
        // 로그인 상태인지 확인
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token == null) {
          timer.cancel();
          stopLocationUpdates();
          return;
        }

        // 백그라운드에서 위치 업데이트
        try {
          await updateLocationOnce();
        } catch (e) {
          print('백그라운드 위치 업데이트 오류: $e');
        }
      },
    );
  }

  // 위치 업데이트 중지
  Future<void> stopLocationUpdates() async {
    if (_positionStreamSubscription != null) {
      await _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }

    // 백그라운드 타이머 취소
    _backgroundTimer?.cancel();
    _backgroundTimer = null;

    _isRunning = false;
    print('실시간 위치 업데이트 서비스 중지됨');
  }

  // 위치 변경 이벤트 핸들러
  void _onPositionUpdate(Position position) async {
    print(
      '새 위치 수신: ${position.latitude}, ${position.longitude}, 정확도: ${position.accuracy}, 방향: ${position.heading}',
    );

    // 서버에 위치 업데이트 전송
    try {
      // 소켓을 통한 실시간 위치 업데이트
      final socketService = SocketService();
      if (!socketService.isConnected) {
        await socketService.initSocket();
      }

      if (socketService.isConnected) {
        socketService.sendLocationUpdate(
          position.latitude,
          position.longitude,
          position.heading,
          position.accuracy,
        );
      }

      // REST API를 통한 위치 업데이트 (서버 DB 저장용)
      bool success = await LocationService.updateMyLocation(
        position.latitude,
        position.longitude,
        position.heading,
        position.accuracy,
      );

      if (success) {
        print('서버에 위치 업데이트 성공');
      } else {
        print('서버에 위치 업데이트 실패');
      }
    } catch (e) {
      print('위치 업데이트 중 오류 발생: $e');

      // 오류 발생 시 소켓 재연결 시도
      try {
        final socketService = SocketService();
        await socketService.reconnect();
      } catch (reconnectError) {
        print('소켓 재연결 시도 중 오류: $reconnectError');
      }
    }
  }

  // 현재 위치 즉시 업데이트
  Future<void> _updateCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 수동으로 핸들러 호출
      _onPositionUpdate(position);
    } catch (e) {
      print('현재 위치 가져오기 실패: $e');
    }
  }

  // 현재 서비스 실행 상태 반환
  bool get isRunning => _isRunning;

  // 수동으로 위치 업데이트 요청
  Future<bool> updateLocationOnce() async {
    try {
      // 로그인 상태 확인
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        print('위치 업데이트를 위해서는 로그인이 필요합니다.');
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 소켓을 통한 실시간 위치 업데이트
      final socketService = SocketService();
      if (!socketService.isConnected) {
        await socketService.initSocket();
      }

      if (socketService.isConnected) {
        socketService.sendLocationUpdate(
          position.latitude,
          position.longitude,
          position.heading,
          position.accuracy,
        );
      }

      bool success = await LocationService.updateMyLocation(
        position.latitude,
        position.longitude,
        position.heading,
        position.accuracy,
      );

      return success;
    } catch (e) {
      print('위치 업데이트 실패: $e');
      return false;
    }
  }
}

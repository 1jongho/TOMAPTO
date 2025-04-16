// services/real_time_location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/services/location_service.dart';

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
  final int _updateIntervalSeconds = 30; // 기본 30초마다 갱신

  // 현재 위치 스트림 설정
  LocationSettings get _locationSettings => LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // 10m 이상 이동했을 때 이벤트 발생
    timeLimit: Duration(seconds: _updateIntervalSeconds),
  );

  // 위치 업데이트 시작
  Future<bool> startLocationUpdates() async {
    // 이미 실행 중이면 중복 실행 방지
    if (_isRunning) return true;

    try {
      // 위치 권한 확인
      bool hasPermission = await LocationService.checkLocationPermission();
      if (!hasPermission) {
        print('위치 권한이 없거나 위치 서비스가 비활성화되어 있습니다.');
        return false;
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

      return true;
    } catch (e) {
      print('위치 업데이트 서비스 시작 오류: $e');
      _isRunning = false;
      return false;
    }
  }

  // 위치 업데이트 중지
  Future<void> stopLocationUpdates() async {
    if (_positionStreamSubscription != null) {
      await _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
    _isRunning = false;
    print('실시간 위치 업데이트 서비스 중지됨');
  }

  // 위치 변경 이벤트 핸들러
  void _onPositionUpdate(Position position) async {
    print('새 위치 수신: ${position.latitude}, ${position.longitude}');

    // 서버에 위치 업데이트 전송
    try {
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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

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

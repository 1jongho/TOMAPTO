// services/location_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  // API 서버 기본 URL 가져오기
  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    // Android 플랫폼이면서 URL이 localhost를 포함하는 경우
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      // 에뮬레이터에서는 10.0.2.2로 localhost 대체
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }
    // 다른 플랫폼이거나 이미 localhost가 아닌 경우 원래 URL 반환
    return baseUrl;
  }

  // 내 위치 업데이트 - 실제 위치 데이터 사용하도록 수정
  static Future<bool> updateMyLocation(
    double latitude,
    double longitude,
    double? heading,
    double? accuracy,
  ) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      print('위치 업데이트 요청: $latitude, $longitude');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/location/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
          'heading': heading,
          'accuracy': accuracy,
        }),
      );

      if (response.statusCode == 200) {
        print('위치 업데이트 성공: $latitude, $longitude');
        return true;
      } else {
        print('위치 업데이트 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 업데이트 오류: $e');
      return false;
    }
  }

  // 친구 위치 조회
  static Future<Map<String, dynamic>?> getFriendLocation(
    String friendId,
  ) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/friend/$friendId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('친구 위치 조회 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('친구 위치 조회 오류: $e');
      return null;
    }
  }

  // 위치 공유 요청
  static Future<bool> requestLocationSharing(
    String friendId, {
    int? durationMinutes,
  }) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();

      // durationMinutes 값을 처리하는 방식 변경
      final Map<String, dynamic> requestBody = {'friend_id': friendId};

      // durationMinutes가 null이 아니고 양수인 경우에만 추가
      if (durationMinutes != null && durationMinutes > 0) {
        requestBody['duration_minutes'] = durationMinutes;
      }

      print('위치 공유 요청 데이터: $requestBody');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/location/share'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print('위치 공유 요청 성공');
        return true;
      } else {
        print('위치 공유 요청 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 공유 요청 오류: $e');
      return false;
    }
  }

  // 위치 공유 종료
  static Future<bool> endLocationSharing(String friendId) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/location/end-sharing'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': friendId}),
      );

      if (response.statusCode == 200) {
        print('위치 공유 종료 성공');
        return true;
      } else {
        print('위치 공유 종료 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 공유 종료 오류: $e');
      return false;
    }
  }

  // 활성화된 위치 공유 목록 조회
  static Future<List<Map<String, dynamic>>?> getActiveLocationSharings() async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/active-sharings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('위치 공유 목록 조회 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('위치 공유 목록 조회 오류: $e');
      return null;
    }
  }

  // 위치 접근 권한 및 서비스 상태 확인
  static Future<bool> checkLocationPermission() async {
    try {
      // 권한 체크
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return false;
        }
      }

      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      return serviceEnabled;
    } catch (e) {
      print('위치 권한 확인 오류: $e');
      return false;
    }
  }
}

// 실시간 위치 서비스 클래스
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

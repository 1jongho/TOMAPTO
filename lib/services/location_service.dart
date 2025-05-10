// Enhanced location_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:tomapto/services/token_service.dart';

class LocationService {
  static String getApiBaseUrl() {
    // 기본 URL 가져오기
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 플랫폼인 경우
    if (Platform.isAndroid) {
      // localhost를 사용 중이고 LOCAL_IP가 설정되어 있다면
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        // localhost를 LOCAL_IP로 대체
        return baseUrl.replaceAll('localhost', localIp);
      }

      // 에뮬레이터 특정 주소 처리
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }

    // 그 외의 경우 원래 URL 반환
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

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();
      print('위치 업데이트 요청: $latitude, $longitude, API: $apiBaseUrl');

      // 요청 데이터 구성
      Map<String, dynamic> requestData = {
        'latitude': latitude,
        'longitude': longitude,
      };

      // 선택적 필드는 null이 아닐 때만 추가
      if (heading != null) requestData['heading'] = heading;
      if (accuracy != null) requestData['accuracy'] = accuracy;

      final response = await http.post(
        Uri.parse('$apiBaseUrl/location/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),
      );

      // 응답 로깅 추가
      print('위치 업데이트 응답 코드: ${response.statusCode}');
      print('위치 업데이트 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        print('위치 업데이트 성공: $latitude, $longitude');

        // 위치 히스토리 DB에 기록 - 서버 측에서 자동으로 이루어지므로 클라이언트에서는 별도 작업 불필요

        return true;
      } else if (response.statusCode == 401) {
        print('위치 업데이트 실패: 인증 오류 - 다시 로그인이 필요합니다');
        return false;
      } else {
        print('위치 업데이트 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('위치 업데이트 오류: $e');
      return false;
    }
  }

  // 현재 위치 가져오기
  static Future<Position?> getCurrentLocation() async {
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          print('위치 권한이 거부되었습니다.');
          return null;
        }
      }

      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('위치 서비스가 비활성화되어 있습니다.');
        return null;
      }

      // 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('현재 위치 가져오기 오류: $e');
      return null;
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

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/friend/$friendId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // 응답 상태 코드에 따른 처리
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('친구 위치 조회 성공: $data');
        return data;
      } else if (response.statusCode == 403) {
        // 위치 공유가 되어있지 않은 경우
        print('친구 위치 조회 실패: 위치 공유 관계가 없습니다');
        return null;
      } else if (response.statusCode == 404) {
        // 친구의 위치 정보가 없는 경우
        print('친구 위치 정보가 없습니다.');
        return null;
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

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return false;
      }

      final apiBaseUrl = getApiBaseUrl();

      // 요청 바디 생성
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

      // 응답 상태 코드에 따른 처리
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

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
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

      // 응답 상태 코드에 따른 처리
      if (response.statusCode == 200) {
        print('위치 공유 종료 성공');
        return true;
      } else if (response.statusCode == 404) {
        print('활성화된 위치 공유가 없습니다.');
        return false;
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

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/active-sharings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // 응답 상태 코드에 따른 처리
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('위치 공유 목록 조회 성공: 총 ${data.length}개');
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

  // 위치 히스토리 조회
  // 위치 히스토리 조회
  static Future<List<Map<String, dynamic>>?> getLocationHistory(
    String friendId, {
    int limit = 20,
  }) async {
    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        return null;
      }

      // 토큰 유효성 검사
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다. 다시 로그인해주세요.');
        return null;
      }

      final apiBaseUrl = getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/history/$friendId?limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // 응답 상태 코드에 따른 처리
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('위치 히스토리 조회 성공: 총 ${data.length}개 기록');
        return data.cast<Map<String, dynamic>>();
      } else {
        print('위치 히스토리 조회 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('위치 히스토리 조회 오류: $e');
      return null;
    }
  }
}

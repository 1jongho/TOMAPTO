import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:tomapto/services/socket_service.dart';

class FriendsService {
  // API 기본 URL 가져오기
  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    if (Platform.isAndroid) {
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        return baseUrl.replaceAll('localhost', localIp);
      }
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }
    return baseUrl;
  }

  // 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 사용자 검색
  static Future<List<Map<String, dynamic>>> searchUsers(
    String searchTerm,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final apiBaseUrl = getApiBaseUrl();
      print('검색 API 호출: $apiBaseUrl/friends/search?term=$searchTerm');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/friends/search?term=$searchTerm'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('검색 응답 코드: ${response.statusCode}');
      print('검색 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      } else {
        throw Exception('사용자 검색 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('사용자 검색 오류: $e');
      return [];
    }
  }

  // 친구 요청 보내기
  static Future<bool> sendFriendRequest(String recipientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 소켓 서비스를 통한 실시간 알림
      final socketService = SocketService();
      if (!socketService.isConnected) {
        await socketService.initSocket();
      }
      socketService.sendFriendRequest(recipientId);

      // API 호출
      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'recipient_id': recipientId}),
      );

      print('친구 요청 응답 코드: ${response.statusCode}');
      print('친구 요청 응답 데이터: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? '친구 요청 실패');
      }
    } catch (e) {
      print('친구 요청 보내기 오류: $e');
      return false;
    }
  }

  // 친구 요청 수락
  static Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final apiBaseUrl = getApiBaseUrl();
      print('친구 요청 수락 API 호출: $apiBaseUrl/friends/request/$requestId/accept');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/request/$requestId/accept'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('친구 요청 수락 응답 코드: ${response.statusCode}');
      print('친구 요청 수락 응답 데이터: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('친구 요청 수락 오류: $e');
      return false;
    }
  }

  // 친구 요청 거절
  static Future<bool> rejectFriendRequest(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final apiBaseUrl = getApiBaseUrl();
      print('친구 요청 거절 API 호출: $apiBaseUrl/friends/request/$requestId/reject');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/request/$requestId/reject'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('친구 요청 거절 응답 코드: ${response.statusCode}');
      print('친구 요청 거절 응답 데이터: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('친구 요청 거절 오류: $e');
      return false;
    }
  }

  // 친구 삭제
  static Future<bool> deleteFriend(String friendId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final apiBaseUrl = getApiBaseUrl();
      print('친구 삭제 API 호출: $apiBaseUrl/friends/delete');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': friendId}),
      );

      print('친구 삭제 응답 코드: ${response.statusCode}');
      print('친구 삭제 응답 데이터: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('친구 삭제 오류: $e');
      return false;
    }
  }

  // 친구 차단
  static Future<bool> blockFriend(String friendId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final apiBaseUrl = getApiBaseUrl();
      print('친구 차단 API 호출: $apiBaseUrl/friends/block');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/friends/block'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'friend_id': friendId}),
      );

      print('친구 차단 응답 코드: ${response.statusCode}');
      print('친구 차단 응답 데이터: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('친구 차단 오류: $e');
      return false;
    }
  }

  // 받은 친구 요청 목록 조회
  static Future<List<Map<String, dynamic>>> getFriendRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final apiBaseUrl = getApiBaseUrl();
      print('친구 요청 목록 API 호출: $apiBaseUrl/friends/requests');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('친구 요청 목록 응답 코드: ${response.statusCode}');
      print('친구 요청 목록 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final requests = List<Map<String, dynamic>>.from(
          data['requests'] ?? [],
        );

        // 응답 데이터의 구조 확인을 위한 로그
        if (requests.isNotEmpty) {
          print(
            '첫 번째 요청 항목 request_id 타입: ${requests.first['request_id'].runtimeType}',
          );
        }

        return requests;
      } else {
        throw Exception('친구 요청 목록 조회 실패');
      }
    } catch (e) {
      print('친구 요청 목록 조회 오류: $e');
      return [];
    }
  }

  // 친구 요청 취소
  static Future<bool> cancelFriendRequest(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final apiBaseUrl = getApiBaseUrl();
      print('친구 요청 취소 API 호출: $apiBaseUrl/friends/request/$requestId');

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/friends/request/$requestId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('친구 요청 취소 응답 코드: ${response.statusCode}');
      print('친구 요청 취소 응답 데이터: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('친구 요청 취소 오류: $e');
      return false;
    }
  }
}

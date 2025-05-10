import 'package:flutter/material.dart';
import 'package:tomapto/services/friends_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FriendsController {
  // 상태 변수들
  bool isLoading = false;
  String errorMessage = '';
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> friendRequests = [];

  // 페이징을 위한 변수들
  int currentPage = 1;
  bool hasMoreResults = true;

  // ID 타입 변환 헬퍼 메서드
  String _ensureStringId(dynamic id) {
    if (id == null) return '';
    return id.toString();
  }

  // API 서버 기본 URL 가져오기
  String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 플랫폼인 경우
    if (baseUrl.contains('localhost') &&
        localIp != null &&
        localIp.isNotEmpty) {
      return baseUrl.replaceAll('localhost', localIp);
    }
    if (baseUrl.contains('localhost')) {
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }
    return baseUrl;
  }

  // 토큰 가져오기
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 검색 메서드
  Future<List<Map<String, dynamic>>> searchUsers(
    String searchTerm,
    Function setState,
  ) async {
    if (searchTerm.isEmpty) return [];

    setState(() => isLoading = true);

    try {
      final results = await FriendsService.searchUsers(searchTerm);

      // 디버깅 로그 추가
      print('서버에서 받은 검색 결과: $results');

      // 결과가 없으면 빈 배열 반환
      if (results.isEmpty) {
        setState(() {
          searchResults = [];
          isLoading = false;
          errorMessage = '';
        });
        return [];
      }

      // 결과 처리 - 여기서 각 결과의 상태 확인
      final processedResults =
          results.map((user) {
            // request_id가 있다면 문자열로 변환하여 저장
            if (user.containsKey('request_id')) {
              user['request_id'] = _ensureStringId(user['request_id']);
            }

            // 명시적 불리언 변환 적용
            if (user.containsKey('is_friend')) {
              user['is_friend'] = _getBoolValue(user['is_friend']);
            }
            if (user.containsKey('request_sent')) {
              user['request_sent'] = _getBoolValue(user['request_sent']);
            }
            if (user.containsKey('request_received')) {
              user['request_received'] = _getBoolValue(
                user['request_received'],
              );
            }
            return user;
          }).toList();

      setState(() {
        searchResults = processedResults;
        isLoading = false;
        errorMessage = '';
      });
      return processedResults;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '검색 중 오류가 발생했습니다: $e';
      });
      return [];
    }
  }

  // 다양한 타입의 값을 불리언으로 변환하는 헬퍼 메서드
  bool _getBoolValue(dynamic value) {
    if (value is bool) {
      return value;
    } else if (value is int) {
      return value == 1;
    } else if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  // 친구 요청 보내기
  Future<bool> sendFriendRequest(String userId, Function setState) async {
    setState(() => isLoading = true);

    try {
      final success = await FriendsService.sendFriendRequest(userId);
      setState(() {
        isLoading = false;
        // 검색 결과 업데이트
        for (var user in searchResults) {
          if (user['user_id'] == userId) {
            user['request_sent'] = true;
            break;
          }
        }
      });
      return success;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '친구 요청 보내기 실패: $e';
      });
      return false;
    }
  }

  // 친구 요청 취소
  Future<bool> cancelFriendRequest(dynamic requestId, Function setState) async {
    setState(() => isLoading = true);

    try {
      final stringRequestId = _ensureStringId(requestId);
      if (stringRequestId.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = '유효하지 않은 요청 ID';
        });
        return false;
      }

      print('취소할 요청 ID: $stringRequestId (원본: $requestId)');
      final success = await FriendsService.cancelFriendRequest(stringRequestId);

      setState(() {
        isLoading = false;
        // 검색 결과 업데이트
        for (var user in searchResults) {
          if (_ensureStringId(user['request_id']) == stringRequestId) {
            user['request_sent'] = false;
            break;
          }
        }
      });
      return success;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '친구 요청 취소 실패: $e';
      });
      return false;
    }
  }

  // 친구 요청 수락
  Future<bool> acceptFriendRequest(dynamic requestId, Function setState) async {
    setState(() => isLoading = true);

    try {
      final stringRequestId = _ensureStringId(requestId);
      if (stringRequestId.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = '유효하지 않은 요청 ID';
        });
        return false;
      }

      // 사용자 ID 가져오기
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      print('수락할 요청 ID: $stringRequestId, 사용자 ID: $userId');

      // 요청 수락 전 서버에 먼저 현재 유효한 요청인지 확인하는 요청 추가
      final apiBaseUrl = getApiBaseUrl();
      try {
        final checkResponse = await http.get(
          Uri.parse('$apiBaseUrl/friends/requests'),
          headers: {'Authorization': 'Bearer ${await getToken()}'},
        );

        if (checkResponse.statusCode == 200) {
          final data = json.decode(checkResponse.body);
          final requests = List<Map<String, dynamic>>.from(
            data['requests'] ?? [],
          );

          // 요청 목록에 해당 요청이 있는지 확인
          bool requestExists = false;
          for (var req in requests) {
            if (_ensureStringId(req['request_id']) == stringRequestId) {
              requestExists = true;
              break;
            }
          }

          if (!requestExists) {
            print('요청 ID $stringRequestId를 요청 목록에서 찾을 수 없습니다');
            setState(() {
              isLoading = false;
              errorMessage = '유효한 요청을 찾을 수 없습니다';
            });
            return false;
          }
        }
      } catch (e) {
        print('요청 확인 중 오류: $e');
        // 오류가 발생해도 계속 진행
      }

      final success = await FriendsService.acceptFriendRequest(stringRequestId);

      setState(() {
        isLoading = false;
        if (success) {
          // 요청 목록에서 해당 요청 제거
          friendRequests.removeWhere(
            (req) => _ensureStringId(req['request_id']) == stringRequestId,
          );
        }
      });
      return success;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '친구 요청 수락 실패: $e';
      });
      return false;
    }
  }

  // 친구 요청 거절
  Future<bool> rejectFriendRequest(dynamic requestId, Function setState) async {
    setState(() => isLoading = true);

    try {
      final stringRequestId = _ensureStringId(requestId);
      if (stringRequestId.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = '유효하지 않은 요청 ID';
        });
        return false;
      }

      print('거절할 요청 ID: $stringRequestId (원본: $requestId)');

      // 요청 거절 전 서버에 먼저 현재 유효한 요청인지 확인하는 요청 추가
      final apiBaseUrl = getApiBaseUrl();
      try {
        final checkResponse = await http.get(
          Uri.parse('$apiBaseUrl/friends/requests'),
          headers: {'Authorization': 'Bearer ${await getToken()}'},
        );

        if (checkResponse.statusCode == 200) {
          final data = json.decode(checkResponse.body);
          final requests = List<Map<String, dynamic>>.from(
            data['requests'] ?? [],
          );

          // 요청 목록에 해당 요청이 있는지 확인
          bool requestExists = false;
          for (var req in requests) {
            if (_ensureStringId(req['request_id']) == stringRequestId) {
              requestExists = true;
              break;
            }
          }

          if (!requestExists) {
            print('요청 ID $stringRequestId를 요청 목록에서 찾을 수 없습니다');
            setState(() {
              isLoading = false;
              errorMessage = '유효한 요청을 찾을 수 없습니다';
            });
            return false;
          }
        }
      } catch (e) {
        print('요청 확인 중 오류: $e');
        // 오류가 발생해도 계속 진행
      }

      final success = await FriendsService.rejectFriendRequest(stringRequestId);

      setState(() {
        isLoading = false;
        if (success) {
          // 요청 목록에서 해당 요청 제거
          friendRequests.removeWhere(
            (req) => _ensureStringId(req['request_id']) == stringRequestId,
          );
        }
      });
      return success;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '친구 요청 거절 실패: $e';
      });
      return false;
    }
  }

  // 친구 차단하기
  Future<bool> blockFriend(String friendId, Function setState) async {
    setState(() => isLoading = true);

    try {
      final success = await FriendsService.blockFriend(friendId);
      setState(() {
        isLoading = false;
      });
      return success;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '친구 차단 실패: $e';
      });
      return false;
    }
  }

  // 친구 삭제하기
  Future<bool> deleteFriend(String friendId, Function setState) async {
    setState(() => isLoading = true);

    try {
      // 삭제 요청 전 로그
      print('친구 삭제 요청: $friendId');

      final success = await FriendsService.deleteFriend(friendId);

      // 삭제 응답 로그
      print('친구 삭제 응답: 성공=$success');

      setState(() {
        isLoading = false;

        // 검색 결과에서 친구 상태 업데이트
        if (success) {
          for (var user in searchResults) {
            if (user['user_id'] == friendId) {
              user['is_friend'] = false;
              print('친구 상태 업데이트: ${user['user_id']}의 is_friend를 false로 설정');
              break;
            }
          }
        }
      });

      return success;
    } catch (e) {
      print('친구 삭제 오류: $e');
      setState(() {
        isLoading = false;
        errorMessage = '친구 삭제 실패: $e';
      });
      return false;
    }
  }

  // 친구 요청 목록 로드
  Future<void> loadFriendRequests(Function setState) async {
    setState(() => isLoading = true);

    try {
      final requests = await FriendsService.getFriendRequests();

      // request_id 타입 변환
      for (var request in requests) {
        if (request.containsKey('request_id')) {
          request['request_id'] = _ensureStringId(request['request_id']);
        }
      }

      setState(() {
        friendRequests = requests;
        isLoading = false;
      });
    } catch (e) {
      print('친구 요청 목록 로드 오류: $e');
      setState(() {
        isLoading = false;
        errorMessage = '친구 요청 목록 로드 실패: $e';
      });
    }
  }
}

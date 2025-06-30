// friends_list_screen.dart
import 'package:flutter/material.dart';
import 'package:tomapto/widgets/ad_placeholder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:tomapto/modal/friends_show.dart';
import 'package:tomapto/modal/friends_setting_modal.dart';
import 'package:tomapto/modal/login_services.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'package:tomapto/pages/friends/friends_add.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/services/token_service.dart';
import 'package:tomapto/pages/profile/login.dart';
import 'package:tomapto/services/real_time_location_service.dart';
import 'package:tomapto/pages/map/naver_map.dart';
import 'package:tomapto/pages/profile/profile.dart';
import 'package:tomapto/widgets/drawer_widget.dart';

class FriendScreen extends StatefulWidget {
  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen>
    with WidgetsBindingObserver {
  // 친구 데이터
  List<Map<String, dynamic>> friends = [];

  // 검색어 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // 현재 선택된 탭 인덱스 (친구 페이지는 인덱스 1)
  int _currentNavIndex = 1;

  // 새 친구 요청 카운트
  int _newRequestsCount = 0;

  // 로그인 상태
  bool _isLoggedIn = false;
  bool _isLoading = true;

  // 검색창 포커스 관리
  final FocusNode _searchFocus = FocusNode();

  // 따라가기 요청 관리
  Set<String> _followRequestFriends = {}; // 따라가기 요청이 있는 친구들의 ID

  // RealTimeLocationService 인스턴스
  final RealTimeLocationService _realTimeLocationService =
      RealTimeLocationService();

  // 아이디 마스킹 함수
  String _maskUserId(String userId) {
    if (userId.length < 5) {
      return userId; // 기존 사용자 대응
    }

    String visiblePart = userId.substring(0, userId.length - 4);
    String maskedPart = '****';

    return '$visiblePart$maskedPart';
  }

  @override
  void initState() {
    super.initState();

    // 앱 생명주기 관찰자 등록
    WidgetsBinding.instance.addObserver(this);

    // 로그인 상태 확인 - 토큰 유효성도 함께 검사
    _checkLoginStatus().then((isLoggedIn) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });

      if (isLoggedIn) {
        // 로그인된 경우에만 서버에서 데이터 로드
        _initSocketService();
        _fetchFriendsFromServer();
        _fetchFriendRequestsCount();
        _fetchLocationSharingStatus();
        _fetchFollowRequests(); // 따라가기 요청 조회 추가

        // 실시간 위치 업데이트 서비스 확인 및 필요시 시작
        _checkAndStartLocationService();
      }
      // 로그인되지 않은 경우는 별도 처리 없음 - 화면에 로그인 메시지 표시
    });
  }

  @override
  void dispose() {
    // 앱 생명주기 관찰자 제거
    WidgetsBinding.instance.removeObserver(this);

    _searchController.dispose();
    _searchFocus.dispose();
    // 소켓 서비스 정리
    if (_isLoggedIn) {
      SocketService().dispose();
    }
    super.dispose();
  }

  // 앱 생명주기 관리
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 돌아왔을 때
        if (_isLoggedIn) {
          _fetchFriendsFromServer();
          _fetchLocationSharingStatus();
          _fetchFollowRequests();
        }
        break;
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 갔을 때
        break;
      case AppLifecycleState.inactive:
        // 앱이 비활성 상태일 때
        break;
      case AppLifecycleState.detached:
        // 앱이 종료될 때
        _stopLocationService();
        break;
      case AppLifecycleState.hidden:
        // 앱이 숨겨질 때
        break;
    }
  }

  // 로그인 상태 확인 (토큰 유효성 검사 포함)
  Future<bool> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      // 토큰이 없는 경우
      if (token == null) {
        print('토큰이 없습니다. 로그인이 필요합니다.');
        return false;
      }

      // 현재 세션에서 로그인한 경우 (is_logged_in이 true)
      if (isLoggedIn) {
        // 토큰 만료 여부만 확인
        if (TokenService.isTokenExpired(token)) {
          // 토큰이 만료된 경우 로그아웃 처리
          await _logout();
          return false;
        }
        return true; // 현재 세션 로그인 상태이고 토큰이 유효하면 로그인됨
      }

      // remember_me 설정이 활성화된 경우
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (rememberMe) {
        // 토큰 유효성 확인
        if (TokenService.isTokenExpired(token)) {
          // 토큰이 만료된 경우 로그아웃 처리
          await _logout();
          return false;
        }
        return true; // 자동 로그인 설정이 활성화되고 토큰이 유효하면 로그인됨
      }

      // 현재 세션 로그인도 아니고 자동 로그인도 비활성화된 경우
      return false;
    } catch (e) {
      print('로그인 상태 확인 오류: $e');
      return false;
    }
  }

  // 로그아웃 처리
  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_id');
      await prefs.remove('is_logged_in');

      // 실시간 위치 서비스 중단
      await _realTimeLocationService.stopLocationUpdates();

      print('로그아웃 처리 완료');
    } catch (e) {
      print('로그아웃 처리 오류: $e');
    }
  }

  // 위치 서비스 중단 (로그아웃 시 사용)
  Future<void> _stopLocationService() async {
    try {
      await _realTimeLocationService.stopLocationUpdates();
      print('위치 서비스 중단 완료');
    } catch (e) {
      print('위치 서비스 중단 오류: $e');
    }
  }

  // 바텀 네비게이션 바 탭 변경 처리
  void _handleNavIndexChanged(int index) {
    // 현재 선택된 탭 업데이트
    setState(() {
      _currentNavIndex = index;
    });

    // 로그인이 필요한 탭(인덱스 1,2,3)이고 로그인되지 않은 경우
    if (!_isLoggedIn && index != 0) {
      // 직접 AlertDialog를 사용하여 로그인 필요 메시지 표시
      showDialog(
        context: context,
        barrierDismissible: true,
        builder:
            (BuildContext dialogContext) => AlertDialog(
              title: Text('로그인 필요'),
              content: Text('로그인이 필요한 서비스입니다.'), // 메시지 통일
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('취소'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Color(0xFFFB233B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext); // 다이얼로그 닫기

                    // 로그인 페이지로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text('로그인하기'),
                ),
              ],
            ),
      );

      // 다이얼로그 표시 후 여기서 반환
      return;
    }

    // 여기서 페이지 이동 로직 처리
    // 로그인된 경우 또는 홈 탭(인덱스 0)인 경우에만 여기에 도달
    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => NaverMapPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (route) => false,
        );
        break;
      case 1:
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => ProfilePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
    }
  }

  // 위치 서비스 초기화
  Future<void> _checkAndStartLocationService() async {
    try {
      // 위치 권한 확인
      final hasPermission =
          await RealTimeLocationService().startLocationUpdates();

      if (hasPermission) {
        print('실시간 위치 업데이트 서비스 시작됨');
      } else {
        print('실시간 위치 업데이트 서비스 시작 실패');
      }
    } catch (e) {
      print('위치 업데이트 서비스 초기화 중 오류 발생: $e');
    }
  }

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
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

    // 다른 플랫폼이거나 이미 localhost가 아닌 경우 원래 URL 반환
    return baseUrl;
  }

  // API 오류 처리 메서드
  void _handleApiError(http.Response response, String operation) {
    String errorMessage;

    switch (response.statusCode) {
      case 400:
        errorMessage = '잘못된 요청입니다.';
        break;
      case 401:
        errorMessage = '인증에 실패했습니다. 다시 로그인해주세요.';
        break;
      case 403:
        errorMessage = '접근 권한이 없습니다.';
        break;
      case 404:
        errorMessage = '요청한 정보를 찾을 수 없습니다.';
        break;
      case 500:
        errorMessage = '서버 오류가 발생했습니다.';
        break;
      default:
        errorMessage = '$operation에 실패했습니다.';
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  // 소켓 초기화 함수
  Future<void> _initSocketService() async {
    try {
      final socketService = SocketService();
      await socketService.initSocket();

      // 친구 요청 이벤트 리스너 등록
      socketService.onFriendRequest.listen((data) {
        // 새 친구 요청 알림 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${data['sender_nickname'] ?? data['sender_id']}님이 친구 요청을 보냈습니다',
            ),
            action: SnackBarAction(
              label: '확인',
              onPressed: () {
                // 친구 추가 페이지로 이동하고 요청 탭으로 전환 (initialTabIndex = 1)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FriendsAddPage(
                          initialSearchTerm: '',
                          initialTabIndex: 1, // 요청 알림 탭으로 설정 (인덱스 1)
                        ),
                  ),
                ).then((_) => _fetchFriendsFromServer()); // 돌아왔을 때 친구 목록 새로고침
              },
            ),
          ),
        );

        // 요청 수 새로고침
        _fetchFriendRequestsCount();
      });

      // 친구 수락 이벤트 리스너 등록
      socketService.onFriendAccept.listen((data) {
        // 친구 목록 새로고침
        _fetchFriendsFromServer();

        // 알림 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${data['user_nickname'] ?? data['user_id']}님이 친구 요청을 수락했습니다',
            ),
          ),
        );
      });

      // 위치 공유 시작 이벤트 리스너 등록
      socketService.onLocationSharingStarted.listen((data) {
        // 위치 공유 시작 이벤트 처리
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${data['user_nickname'] ?? data['user_id']}님이 위치 공유를 시작했습니다',
            ),
          ),
        );

        // 위치 공유 상태 업데이트
        _fetchLocationSharingStatus();
      });

      // 위치 공유 종료 이벤트 리스너 등록
      socketService.onLocationSharingStopped.listen((data) {
        // 위치 공유 종료 이벤트 처리
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${data['user_nickname'] ?? data['user_id']}님과의 위치 공유가 종료되었습니다',
            ),
          ),
        );

        // 위치 공유 상태 업데이트
        _fetchLocationSharingStatus();
      });

      // 친구 위치 업데이트 리스너 등록
      socketService.onLocationUpdate.listen((data) {
        // 친구 위치 업데이트 이벤트 처리
        print(
          '친구 위치 업데이트: ${data['user_id']} - lat: ${data['latitude']}, lng: ${data['longitude']}',
        );
      });

      // 친구 상태 변경 리스너 등록
      socketService.onFriendStatusChange.listen((data) {
        // 친구 상태 변경 처리
        print('친구 상태 변경: ${data['user_id']} - 온라인: ${data['isOnline']}');
        _refreshFriendsStatus(data);
      });
    } catch (e) {
      print('소켓 서비스 초기화 오류: $e');
    }
  }

  void _refreshFriendsStatus(Map<String, dynamic> statusData) {
    setState(() {
      for (var i = 0; i < friends.length; i++) {
        if (friends[i]['id'] == statusData['user_id']) {
          // isOnline 값의 타입에 따라 적절히 변환
          var isOnlineValue = statusData['isOnline'];
          bool isOnline = false;

          if (isOnlineValue is bool) {
            isOnline = isOnlineValue;
          } else if (isOnlineValue is int) {
            isOnline = (isOnlineValue == 1);
          } else if (isOnlineValue is String) {
            isOnline =
                (isOnlineValue.toLowerCase() == 'true' || isOnlineValue == '1');
          }

          friends[i]['isOnline'] = isOnline;
          break;
        }
      }
    });
  }

  // 서버에서 친구 목록 가져오기
  Future<void> _fetchFriendsFromServer() async {
    if (!_isLoggedIn) return;

    try {
      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        setState(() {
          _isLoggedIn = false;
        });
        return;
      }

      // 토큰 만료 확인
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다');
        setState(() {
          _isLoggedIn = false;
        });
        // 로그아웃 처리
        await _logout();

        // 로그인 페이지로 리디렉션
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/friends/list'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          // 서버에서 받은 친구 목록으로 업데이트
          friends = List<Map<String, dynamic>>.from(data['friends']);

          // isSharing 필드가 없는 경우 추가
          for (var friend in friends) {
            if (!friend.containsKey('isSharing')) {
              friend['isSharing'] = false;
            }
          }

          // 친구 목록 정렬
          _sortFriends();
        });
      } else if (response.statusCode == 401) {
        // 인증 오류 - 토큰이 만료되었거나 유효하지 않음
        print('토큰이 유효하지 않습니다');
        setState(() {
          _isLoggedIn = false;
        });
        // 로그아웃 처리
        await _logout();

        // 로그인 페이지로 리디렉션
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      } else {
        print('친구 목록 불러오기 실패: ${response.statusCode} - ${response.body}');
        _handleApiError(response, '친구 목록 로드');
      }
    } catch (e) {
      print('친구 목록 불러오기 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('친구 목록을 불러오는데 실패했습니다.')));
      }
    }
  }

  // 위치 공유 상태 확인
  Future<void> _fetchLocationSharingStatus() async {
    if (!_isLoggedIn) return;

    try {
      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        setState(() {
          _isLoggedIn = false;
        });
        return;
      }

      // 토큰 만료 확인
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다');
        setState(() {
          _isLoggedIn = false;
        });
        await _logout();
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/location/active-sharings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> sharings = json.decode(response.body);

        // 위치 공유 상태 업데이트
        setState(() {
          for (var friend in friends) {
            // 해당 친구와의 위치 공유 상태 확인
            friend['isSharing'] = sharings.any(
              (sharing) =>
                  (sharing['sharer_id'] == friend['id'] ||
                      sharing['sharee_id'] == friend['id']),
            );
          }
        });
      } else if (response.statusCode == 401) {
        // 인증 오류 - 토큰이 만료되었거나 유효하지 않음
        print('토큰이 유효하지 않습니다');
        setState(() {
          _isLoggedIn = false;
        });
        // 로그아웃 처리
        await _logout();
      } else {
        print('위치 공유 상태 조회 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('위치 공유 상태 조회 오류: $e');
    }
  }

  // 새 친구 요청 수 가져오기
  Future<void> _fetchFriendRequestsCount() async {
    if (!_isLoggedIn) return;

    try {
      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다');
        setState(() {
          _isLoggedIn = false;
        });
        return;
      }

      // 토큰 만료 확인
      if (TokenService.isTokenExpired(token)) {
        print('토큰이 만료되었습니다');
        setState(() {
          _isLoggedIn = false;
        });
        await _logout();
        return;
      }

      // API 호출
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          // 새 친구 요청 수 업데이트
          _newRequestsCount = data['requests'].length;
        });
      } else if (response.statusCode == 401) {
        // 인증 오류 - 토큰이 만료되었거나 유효하지 않음
        print('토큰이 유효하지 않습니다');
        setState(() {
          _isLoggedIn = false;
        });
        // 로그아웃 처리
        await _logout();
      } else {
        print('친구 요청 목록 불러오기 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('친구 요청 목록 불러오기 오류: $e');
    }
  }

  // 따라가기 요청 조회
  Future<void> _fetchFollowRequests() async {
    if (!_isLoggedIn) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('user_id');

      if (token == null) return;

      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/follow/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> requests = json.decode(response.body);
        setState(() {
          _followRequestFriends.clear();
          for (var request in requests) {
            if (request['status'] == 'pending' &&
                request['target_id'].toString() == myUserId) {
              _followRequestFriends.add(request['requester_id'].toString());
            }
          }
        });
        print('따라가기 요청자 목록: $_followRequestFriends');
      }
    } catch (e) {
      print('따라가기 요청 조회 오류: $e');
    }
  }

  // 친구 검색 함수
  void _searchFriends(String query) {
    if (!_isLoggedIn) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('로그인 필요'),
              content: Text('로그인이 필요한 서비스입니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('취소'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Color(0xFFFB233B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text('로그인하기'),
                ),
              ],
            ),
      );
      return;
    }

    if (query.isEmpty) {
      _fetchFriendsFromServer(); // 전체 친구 목록 다시 불러오기
      return;
    }

    // 현재 친구 목록에서 닉네임/이름/아이디로 검색
    setState(() {
      final allFriends = List<Map<String, dynamic>>.from(
        friends,
      ); // 전체 친구 목록 백업
      final filteredFriends =
          allFriends.where((friend) {
            final nickname = friend['nickname']?.toString().toLowerCase() ?? '';
            final name = friend['name']?.toString().toLowerCase() ?? '';
            final friendId =
                friend['id']?.toString().toLowerCase() ?? ''; // 아이디 검색
            final searchLower = query.toLowerCase();

            // 닉네임, 이름, 아이디 모두에서 검색
            return nickname.contains(searchLower) ||
                name.contains(searchLower) ||
                friendId.contains(searchLower);
          }).toList();

      friends = filteredFriends; // 필터링된 결과로 업데이트
    });
  }

  // 친구 데이터 유효성 확인 (확장 메서드 대신 일반 함수 사용)
  Map<String, dynamic> _ensureValidFriend(Map<String, dynamic> friend) {
    // ID가 없는 경우 임의 ID 부여
    if (!friend.containsKey('id')) {
      friend['id'] =
          friend['name']?.toString().hashCode.toString() ?? 'unknown';
    }

    // isOnline 필드가 없는 경우 기본값 false 부여
    if (!friend.containsKey('isOnline')) {
      friend['isOnline'] = false;
    } else {
      // isOnline 값의 타입에 따라 적절히 변환
      var isOnlineValue = friend['isOnline'];
      bool isOnline = false;

      if (isOnlineValue is bool) {
        isOnline = isOnlineValue;
      } else if (isOnlineValue is int) {
        isOnline = (isOnlineValue == 1);
      } else if (isOnlineValue is String) {
        isOnline =
            (isOnlineValue.toLowerCase() == 'true' || isOnlineValue == '1');
      }

      friend['isOnline'] = isOnline;
    }

    // isSharing 필드가 없는 경우 기본값 false 부여
    if (!friend.containsKey('isSharing')) {
      friend['isSharing'] = false;
    }

    return friend;
  }

  // 친구 목록 정렬
  void _sortFriends() {
    friends.sort((a, b) {
      // 온라인 상태 우선 정렬
      final aOnline = _getBoolValue(a['isOnline']);
      final bOnline = _getBoolValue(b['isOnline']);

      if (aOnline && !bOnline) return -1;
      if (!aOnline && bOnline) return 1;

      // 그 다음 닉네임/이름으로 정렬
      final aName =
          a['nickname']?.isNotEmpty == true ? a['nickname'] : a['name'] ?? '';
      final bName =
          b['nickname']?.isNotEmpty == true ? b['nickname'] : b['name'] ?? '';

      return aName.compareTo(bName);
    });
  }

  // 마지막 활동 시간 포맷팅
  String _formatLastActiveTime(String? lastActive) {
    if (lastActive == null) return '';

    try {
      final DateTime lastActiveTime = DateTime.parse(lastActive);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(lastActiveTime);

      if (difference.inMinutes < 5) {
        return '방금 전';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}시간 전';
      } else {
        return '${difference.inDays}일 전';
      }
    } catch (e) {
      return '';
    }
  }

  // 친구 프로필 모달 표시 (friends_show.dart 사용)
  void showFriendProfile(BuildContext context, Map<String, dynamic> friend) {
    // 친구에게 따라가기 요청이 있는지 확인하여 전달
    final hasFollowRequest = _followRequestFriends.contains(
      friend['id'].toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => FriendsShowModal(
            friend: friend,
            hasFollowRequest: hasFollowRequest, // 따라가기 요청 여부 전달
          ),
    );
  }

  // 위치 공유 상태 변경 콜백
  void _onShareStatusChanged(bool isSharing) {
    // 친구 목록 및 위치 공유 상태 새로고침
    _fetchFriendsFromServer();
    _fetchLocationSharingStatus();
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

  // 요청 및 친구 목록 새로고침을 위한 콜백
  void _onRequestsUpdated() {
    _fetchFriendsFromServer();
    _fetchFriendRequestsCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 드로어 위젯 사용 방식 수정
      drawer: Drawer(
        // 65% 너비 설정
        width: MediaQuery.of(context).size.width * 0.65,
        // 드로어 위젯을 자식으로 추가
        child:
            _isLoggedIn
                ? DrawerWidget(
                  newRequestsCount: _newRequestsCount,
                  onRequestsUpdated: _onRequestsUpdated,
                )
                : Container(), // 로그인되지 않은 경우 빈 컨테이너
      ),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Stack(
          children: [
            Builder(
              builder:
                  (context) => IconButton(
                    icon: Icon(Icons.menu, color: Colors.black),
                    onPressed: () {
                      if (!_isLoggedIn) {
                        // 로그인 안된 경우 로그인 다이얼로그 표시
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text('로그인 필요'),
                                content: Text('로그인이 필요한 서비스입니다'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('취소'),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Color(0xFFFB233B),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoginPage(),
                                        ),
                                      );
                                    },
                                    child: Text('로그인하기'),
                                  ),
                                ],
                              ),
                        );
                        return;
                      }
                      // 드로어 열기
                      Scaffold.of(context).openDrawer();
                    },
                  ),
            ),
            if (_newRequestsCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    '$_newRequestsCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: const Text(
          '친구',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [], // 메뉴 버튼이 leading으로 이동했으므로 actions는 비워둠
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB233B)),
                ),
              )
              : _isLoggedIn
              ? _buildFriendsListContent()
              : _buildLoginRequiredContent(),
      // 바텀 네비게이션 바
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _handleNavIndexChanged,
      ),
    );
  }

  // 친구 목록 컨텐츠 위젯 (로그인 시)
  Widget _buildFriendsListContent() {
    return Column(
      children: [
        // 검색창과 돋보기를 별도의 Row로 배치하여 돋보기를 밖으로 이동
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 10.0),
          child: Row(
            children: [
              // 검색창 (검색창 내 텍스트 중앙 정렬)
              Expanded(
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: TextStyle(fontSize: 14),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: '닉네임을 입력해주세요.',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        // 실시간 검색 기능은 유지
                      },
                      onSubmitted: (text) => _searchFriends(text),
                    ),
                  ),
                ),
              ),

              // 회색 원 밖에 있는 돋보기 아이콘
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Container(
                  width: 15,
                  height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: InkWell(
                    onTap: () {
                      _searchFriends(_searchController.text);
                    },
                    child: Icon(Icons.search, color: Colors.black, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 광고 플레이스홀더를 이미지로 대체
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Image.asset(
            'assets/icons/adsense_banner.png',
            width: double.infinity,
            height: 50,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 5),

        // 빨간색 선 위에 친구 목록 텍스트 위치
        Container(
          width: double.infinity,
          color: Colors.white,
          child: Column(
            children: [
              // 친구 목록 타이틀
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: Text(
                    '친구 목록',
                    style: TextStyle(fontWeight: FontWeight.w400, fontSize: 15),
                  ),
                ),
              ),
              Container(height: 3, color: Colors.red), // 2px → 3px
            ],
          ),
        ),

        // 친구 목록
        Expanded(
          child:
              friends.isEmpty
                  ? Center(child: Text('친구가 없습니다.'))
                  : RefreshIndicator(
                    onRefresh: () async {
                      await _fetchFriendsFromServer();
                      await _fetchLocationSharingStatus();
                    },
                    child: ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final validFriend = _ensureValidFriend(
                          Map<String, dynamic>.from(friend),
                        );

                        return Column(
                          children: [
                            // ListView.builder 안의 리스트 아이템 부분
                            InkWell(
                              onTap: () {
                                // 친구 항목 전체를 탭했을 때 친구 프로필 모달 표시 (위치 보기 등)
                                showFriendProfile(context, validFriend);
                              },
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 0,
                                ),
                                leading: Stack(
                                  children: [
                                    // 흰색 네모 프로필
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: const Color.fromARGB(
                                          255,
                                          0,
                                          0,
                                          0,
                                        ),
                                        size: 30,
                                      ),
                                    ),
                                    // 상태 표시 아이콘 - 오른쪽 위 위치
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color:
                                              _getBoolValue(
                                                    validFriend['isOnline'],
                                                  )
                                                  ? Colors.green
                                                  : Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 닉네임과 따라가기 요청 알람을 Row로 감싸기
                                    Row(
                                      children: [
                                        // 닉네임 (메인 표시)
                                        Text(
                                          validFriend['nickname']?.isNotEmpty ==
                                                  true
                                              ? validFriend['nickname']
                                              : validFriend['name'] ?? '닉네임 없음',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                        // 따라가기 요청 알람 표시 (느낌표)
                                        if (_followRequestFriends.contains(
                                          validFriend['id'].toString(),
                                        ))
                                          Container(
                                            margin: EdgeInsets.only(left: 6),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '!',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    // 마스킹된 아이디 (항상 표시) - 기존 코드 유지
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        '@${_maskUserId(validFriend['id'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    // 마지막 활동 시간 (오프라인인 경우만 표시) - 기존 코드 유지
                                    if (validFriend['isOnline'] != true &&
                                        validFriend['lastActive'] != null)
                                      Text(
                                        _formatLastActiveTime(
                                          validFriend['lastActive'],
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                  onPressed: () {
                                    // 더 보기 메뉴 - 친구 설정 모달 표시 (차단, 삭제 등)
                                    showFriendSettings(
                                      context,
                                      validFriend,
                                      _onShareStatusChanged,
                                    );
                                  },
                                ),
                              ),
                            ),
                            // 줄바꿈 구분선 (모든 항목 아래 표시)
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.grey[300],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  // 로그인 필요 화면 위젯 (로그인 전)
  Widget _buildLoginRequiredContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: Colors.grey[400], size: 100),
          SizedBox(height: 24),
          Text(
            '친구 목록',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              '로그인 후 이용 가능한 서비스입니다',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 36),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB233B),
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Text(
              '로그인하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// 친구 설정 모달 표시 함수 (전역 함수)
void showFriendSettings(
  BuildContext context,
  Map<String, dynamic> friend,
  Function onShareStatusChanged,
) {
  showDialog(
    context: context,
    builder:
        (context) => FriendsSettingModal(
          friend: friend,
          onShareStatusChanged: onShareStatusChanged,
        ),
  );
}

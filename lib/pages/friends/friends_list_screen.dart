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

class FriendScreen extends StatefulWidget {
  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
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

  // 모달 표시 플래그
  bool _hasShownLoginModal = false;

  @override
  void initState() {
    super.initState();

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

        // 실시간 위치 업데이트 서비스 확인 및 필요시 시작
        _checkAndStartLocationService();
      } else {
        // 로그인되지 않은 경우에만 화면이 로드된 후 실행되도록 WidgetsBinding 사용
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLoginModalIfNeeded();
        });
      }
    });
  }

  // 필요한 경우 로그인 모달 표시
  void _showLoginModalIfNeeded() {
    if (!_isLoggedIn && !_hasShownLoginModal && mounted) {
      setState(() {
        _hasShownLoginModal = true;
      });
      showLoginServicesModal(context, message: '친구 목록을 보려면 로그인이 필요합니다');
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
      await prefs.remove('remember_me');
    } catch (e) {
      print('로그아웃 처리 오류: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // 소켓 서비스 정리
    if (_isLoggedIn) {
      SocketService().dispose();
    }
    super.dispose();
  }

  // 바텀 네비게이션 바 탭 변경 처리
  void _handleNavIndexChanged(int index) {
    // 페이지 이동 전 토큰 유효성 다시 확인
    _checkLoginStatus().then((isLoggedIn) {
      if (!isLoggedIn && index != 0) {
        // 홈 화면이 아닌 경우 로그인 필요
        setState(() {
          _isLoggedIn = false;
          _hasShownLoginModal = false; // 다시 모달 표시 가능하도록 설정
        });
        _showLoginModalIfNeeded();
        return;
      }

      setState(() {
        _currentNavIndex = index;
      });

      // 여기서 실제 탭 전환 로직 구현
      // ...
    });
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
                // 친구 추가 페이지로 이동하고 요청 탭으로 전환
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FriendsAddPage(initialSearchTerm: ''),
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
      }
    } catch (e) {
      print('친구 목록 불러오기 오류: $e');
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

  // 친구 검색 함수
  void _searchFriends(String query) {
    if (!_isLoggedIn) {
      // 로그인되지 않은 경우 로그인 모달 표시
      showLoginServicesModal(context);
      return;
    }

    if (query.isEmpty) {
      _fetchFriendsFromServer(); // 검색어가 없으면 서버에서 다시 불러오기
      return;
    }

    // 검색어가 있으면 검색 페이지로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendsAddPage(initialSearchTerm: query),
      ),
    ).then((_) {
      // 돌아왔을 때 친구 목록 및 위치 공유 상태 새로고침
      _fetchFriendsFromServer();
      _fetchLocationSharingStatus();
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

  // 위치 공유 상태 변경 콜백
  void _onShareStatusChanged(bool isSharing) {
    // 친구 목록 및 위치 공유 상태 새로고침
    _fetchFriendsFromServer();
    _fetchLocationSharingStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '친구',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true, // 제목 중앙 정렬
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
      // 위치 공유 요청이 있을 때 표시할 FAB - 새 요청이 있을 때만 표시
      floatingActionButton:
          _isLoggedIn && _newRequestsCount > 0
              ? FloatingActionButton(
                backgroundColor: Colors.red,
                mini: true,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.person_add, color: Colors.white),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$_newRequestsCount',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  // 친구 추가 페이지로 이동하고 요청 탭으로 전환
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FriendsAddPage(initialSearchTerm: ''),
                    ),
                  ).then((_) {
                    // 돌아왔을 때 친구 목록 및 위치 공유 상태 새로고침
                    _fetchFriendsFromServer();
                    _fetchLocationSharingStatus();
                    _fetchFriendRequestsCount();
                  });
                },
                tooltip: '새 친구 요청',
              )
              : null,
    );
  }

  // 친구 목록 컨텐츠 위젯 (로그인 시)

  // 친구 목록 컨텐츠 위젯 (로그인 시)
  Widget _buildFriendsListContent() {
    return Column(
      children: [
        // 검색창과 돋보기를 별도의 Row로 배치하여 돋보기를 밖으로 이동
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 10.0),
          child: Row(
            children: [
              // 검색창 (돋보기 없이)
              Expanded(
                child: Container(
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '닉네임을 입력해주세요.',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                      onChanged: (value) {
                        // 실시간 검색 기능은 유지하되, 추가 기능은 없음
                      },
                      onSubmitted:
                          (text) => _searchFriends(text), // 엔터키 누르면 검색 실행
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

        // 광고 플레이스홀더 (기존 스타일 유지)
        AdPlaceholder(),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w900, // 더 굵게 수정
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              // 빨간색 선 - 더 얇게 수정
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
                        // 확장 메서드 대신 일반 함수 사용
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
                                  horizontal: 25,
                                  vertical: 4,
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
                                          width: 0.5, // 더 얇은 테두리
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
                                    // 상태 표시 아이콘을 오른쪽 위로 이동 (온라인 상태 표시) - 여기가 수정된 부분
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
                                            width: 1, // 더 얇은 테두리
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  validFriend['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
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
                            // 줄바꿈 구분선 (모든 항목 아래 표시) - 더 얇게 수정
                            Divider(
                              height: 1,
                              thickness: 0.5, // 더 얇은 구분선
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
              showLoginServicesModal(context);
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

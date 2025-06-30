import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/services/location_service.dart';
import 'package:tomapto/services/token_service.dart';
import 'package:tomapto/services/real_time_location_service.dart';
import 'package:tomapto/modal/follow_modal.dart';
import 'package:tomapto/modal/follow_request_modal.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/pages/map/transit.dart';
import 'package:tomapto/services/push_notification_service.dart';

class RealTimeLocationSharingPage extends StatefulWidget {
  final Map<String, dynamic> selectedFriend;

  const RealTimeLocationSharingPage({Key? key, required this.selectedFriend})
    : super(key: key);

  @override
  _RealTimeLocationSharingPageState createState() =>
      _RealTimeLocationSharingPageState();
}

class _RealTimeLocationSharingPageState
    extends State<RealTimeLocationSharingPage>
    with TickerProviderStateMixin {
  // 네이버 지도 관련
  NaverMapController? _mapController;
  NLatLng? _myPosition;
  NLatLng? _friendPosition;
  final Set<NMarker> _markers = {};
  bool _isInitialCameraSet = false;
  bool _isLoading = true;
  bool _isInitialLoadComplete = false;
  bool _isModalCurrentlyShowing = false;
  String _errorMessage = '';
  bool _isUpdatingMarkers = false;

  // 소켓 서비스 인스턴스
  late SocketService _socketService;

  // 위치 정보 자동 갱신을 위한 타이머
  Timer? _locationUpdateTimer;

  // 소켓 이벤트 구독자
  StreamSubscription? _locationUpdateSubscription;
  StreamSubscription? _followRequestSubscription;
  StreamSubscription? _followResponseSubscription;
  StreamSubscription? _followCancelledSubscription;
  StreamSubscription? _followStoppedSubscription;

  // 위치 공유 상태 추적 변수들
  bool _iAmSharingLocation = false;
  bool _friendIsSharingLocation = false;

  // 찾아가기 상태 추적 변수들
  String _followStatus = 'none'; // 'none', 'pending', 'accepted'
  bool _isRequester = false; // 내가 요청자인지 여부
  int? _currentRequestId; // 현재 요청 ID

  // 1시간 만료 관련 변수들
  Timer? _findWayExpiryTimer; // 만료 타이머
  DateTime? _findWayStartTime; // 찾아가기 시작 시간
  NLatLng? _friendFixedPosition; // 허용 시점 친구 고정 위치

  // 네이버맵 길찾기 관련 변수들
  Set<NPathOverlay> _pathOverlays = {};
  bool _isNavigating = false; // 길찾기 진행 중인지

  // 마지막 업데이트 시간
  DateTime? _lastUpdateTime;

  // 카메라 상태 관리 변수들
  bool _userManuallyControlledCamera = false;
  DateTime? _lastManualCameraControl;
  double _currentZoom = 15.0;

  // 파동 애니메이션 컨트롤러들
  late AnimationController _waveController1;
  late AnimationController _waveController2;
  late AnimationController _waveController3;
  late Animation<double> _waveAnimation1;
  late Animation<double> _waveAnimation2;
  late Animation<double> _waveAnimation3;

  @override
  void initState() {
    super.initState();

    // 파동 애니메이션 초기화
    _waveController1 = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _waveController2 = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _waveController3 = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _waveAnimation1 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _waveController1, curve: Curves.easeOut));

    _waveAnimation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveController2,
        curve: Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _waveAnimation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveController3,
        curve: Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _socketService = SocketService();
    _initSocket();
    _loadLocations();
    _loadFollowStatus();
    _loadFindWayStartTime();
    _saveFCMToken(); // FCM 토큰 저장 추가

    // 1초마다 위치 정보 갱신
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (_lastUpdateTime == null ||
          now.difference(_lastUpdateTime!).inSeconds > 1) {
        _refreshLocations();
      }
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _locationUpdateSubscription?.cancel();

    // 🔥 찾아가기 관련 리스너들 정리
    _followRequestSubscription?.cancel();
    _followResponseSubscription?.cancel();
    _followCancelledSubscription?.cancel();
    _followStoppedSubscription?.cancel();

    // 애니메이션 컨트롤러 정리
    _waveController1.dispose();
    _waveController2.dispose();
    _waveController3.dispose();

    super.dispose();
  }

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
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

  // 찾아가기 상태 로드 (만료 체크 포함)
  Future<void> _loadFollowStatus() async {
    try {
      print('🔍 찾아가기 상태 로드 시작');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final myUserId = prefs.getString('user_id');

      if (token == null) return;

      final apiBaseUrl = _getApiBaseUrl();
      final url = '$apiBaseUrl/follow/status/${widget.selectedFriend['id']}';
      print('🔍 API 호출: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('🔍 응답 상태코드: ${response.statusCode}');
      print('🔍 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 내가 요청자인지 직접 판단
        bool isRequester = false;
        if (data['status'] == 'pending' || data['status'] == 'accepted') {
          isRequester = (data['requester_id'] == myUserId);
        }

        print('🔍 찾아가기 상태 설정: ${data['status']}, 요청자: $isRequester');

        setState(() {
          _followStatus = data['status'] ?? 'none';
          _isRequester = isRequester; // 직접 계산한 값 사용
          _currentRequestId = data['request_id'];

          // 🔥 추가: accepted 상태일 때 친구 고정 위치 설정
          if (_followStatus == 'accepted' && _friendPosition != null) {
            _friendFixedPosition = _friendPosition;
            print('🔍 친구 고정 위치 설정: $_friendFixedPosition');
          }
        });

        if (_followStatus == 'pending' && !_isRequester) {
          Future.delayed(Duration(milliseconds: 500), () {
            _showFollowRequestModal(
              _currentRequestId ?? 0,
              data['requester_name'] ?? '',
            );
          });
        }
      } else {
        print('❌ 찾아가기 상태 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 찾아가기 상태 로드 오류: $e');
    }
  }

  // 소켓 초기화 및 이벤트 리스너 설정
  Future<void> _initSocket() async {
    try {
      if (!_socketService.isConnected) {
        await _socketService.initSocket();
      }

      // 🔥 기존 리스너들 정리
      _followRequestSubscription?.cancel();
      _followResponseSubscription?.cancel();
      _followCancelledSubscription?.cancel();
      _followStoppedSubscription?.cancel();
      _locationUpdateSubscription?.cancel();

      // 기존 위치 관련 이벤트들
      _locationUpdateSubscription = _socketService.onLocationUpdate.listen((
        data,
      ) {
        if (data['user_id'] == widget.selectedFriend['id'] &&
            _friendIsSharingLocation) {
          setState(() {
            _friendPosition = NLatLng(data['latitude'], data['longitude']);
            _lastUpdateTime = DateTime.now();
          });
          _updateMapMarkersWithoutCameraChange();

          // 길찾기 중이면 경로 업데이트
          if (_isNavigating) {
            _updateNavigationRoute();
          }

          print('소켓으로 친구 위치 업데이트: ${data['latitude']}, ${data['longitude']}');
        }
      });

      _socketService.onLocationSharingStopped.listen((data) {
        if (data['user_id'] == widget.selectedFriend['id']) {
          setState(() {
            _friendIsSharingLocation = false;
            _friendPosition = null;
          });
          _updateMapMarkersWithoutCameraChange();
          _stopNavigation(); // 위치 공유 중단시 네비게이션도 중단
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.selectedFriend['name']}님이 위치 공유를 종료했습니다'),
            ),
          );
        }
      });

      _socketService.onLocationSharingStarted.listen((data) {
        if (data['user_id'] == widget.selectedFriend['id']) {
          setState(() {
            _friendIsSharingLocation = true;
          });
          _refreshLocations();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.selectedFriend['name']}님이 위치 공유를 시작했습니다'),
            ),
          );
        }
      });

      // 찾아가기 요청 리스너
      _followRequestSubscription = _socketService.onFollowRequestReceived
          .listen((data) {
            SharedPreferences.getInstance().then((prefs) {
              final myUserId = prefs.getString('user_id');

              print("🔔 찾아가기 요청 수신: $data");

              // 내가 요청받은 사람인 경우만 모달 표시
              if (data['target_id'].toString() == myUserId) {
                print("✅ 모달 표시: 내가 요청받은 사람");
                _showFollowRequestModal(
                  data['request_id'] ?? 0,
                  data['requester_name'] ?? '',
                );
              } else {
                print("❌ 모달 표시 안함: target=${data['target_id']}, my=$myUserId");
              }
            });
          });

      _followResponseSubscription = _socketService.onFollowRequestResponded
          .listen((data) {
            SharedPreferences.getInstance().then((prefs) {
              final myUserId = prefs.getString('user_id');

              if (data['requester_id'].toString() == myUserId) {
                final response = data['response'];
                final message =
                    response == 'accept'
                        ? '${data['target_name']}님이 찾아가기 요청을 수락했습니다'
                        : '${data['target_name']}님이 찾아가기 요청을 거절했습니다';

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));

                if (response == 'accept') {
                  setState(() {
                    _followStatus = 'accepted';
                  });
                  _startNavigation();
                } else {
                  setState(() {
                    _followStatus = 'none';
                    _isRequester = false;
                    _currentRequestId = null;
                  });
                }
              }
            });
          });

      _followCancelledSubscription = _socketService.onFollowRequestCancelled
          .listen((data) {
            SharedPreferences.getInstance().then((prefs) {
              final myUserId = prefs.getString('user_id');

              if (data['target_id'].toString() == myUserId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${data['requester_name']}님이 찾아가기 요청을 취소했습니다',
                    ),
                  ),
                );
              }
            });
          });

      _followStoppedSubscription = _socketService.onFollowStopped.listen((
        data,
      ) {
        SharedPreferences.getInstance().then((prefs) {
          final myUserId = prefs.getString('user_id');

          if (data['other_user_id'].toString() == myUserId) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${data['stopped_by_name']}님이 찾아가기를 중단했습니다'),
              ),
            );
            setState(() {
              _followStatus = 'none';
              _isRequester = false;
              _currentRequestId = null;
            });
            _stopNavigation();
          }
        });
      });

      print('소켓 이벤트 리스너 설정 완료');
    } catch (e) {
      print('소켓 초기화 오류: $e');
    }
  }

  // 친구 위치 업데이트 처리
  void _handleFriendLocationUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    final lat = double.tryParse(data['latitude'].toString());
    final lng = double.tryParse(data['longitude'].toString());

    if (lat != null && lng != null) {
      setState(() {
        _friendPosition = NLatLng(lat, lng);
        _lastUpdateTime = DateTime.now();
      });

      // 스마트 마커 업데이트 (카메라 변경 없이)
      if (_mapController != null) {
        _updateMapMarkersWithoutCameraChange();
      }

      // 길찾기 중이면 경로 업데이트
      if (_isNavigating) {
        _updateNavigationRoute();
      }
    }
  }

  void _handleFollowRequest(Map<String, dynamic> data) {
    // 이미 소켓 리스너에서 필터링했으므로 바로 모달 표시
    print("모달 표시 준비: $data");
    if (_isModalCurrentlyShowing) return;

    _isModalCurrentlyShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => FollowRequestModal(
            requestId: data['request_id'] ?? 0,
            requesterName: data['requester_name'] ?? '',
            onResponseSent: () {
              _isModalCurrentlyShowing = false;
              _loadFollowStatus(); // 상태 다시 로드
            },
          ),
    ).then((_) {
      _isModalCurrentlyShowing = false;
    });
  }

  // 찾아가기 응답 처리
  void _handleFollowResponse(Map<String, dynamic> data) {
    if (!mounted) return;

    final response = data['response'];
    if (response == 'accept') {
      setState(() {
        _followStatus = 'accepted';
        _findWayStartTime = DateTime.now(); // 허용 시점 시간 저장
        _friendFixedPosition = _friendPosition; // 현재 친구 위치를 고정으로 저장
      });

      // SharedPreferences에 시간 저장
      _saveFindWayStartTime();

      // 1시간 만료 타이머 시작
      _startFindWayExpiryTimer();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('찾아가기 요청이 수락되었습니다')));
      // 추가: 수락 후 잠시 딜레이를 두고 Transit 페이지 안내
      Future.delayed(Duration(seconds: 2), () {
        if (mounted && _followStatus == 'accepted' && _isRequester) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('친구 마커를 클릭하면 길찾기를 시작할 수 있습니다'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    } else {
      setState(() {
        _followStatus = 'none';
        _currentRequestId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('찾아가기 요청이 거절되었습니다')));
    }
  }

  // 찾아가기 취소 처리
  void _handleFollowCancelled(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      _followStatus = 'none';
      _currentRequestId = null;
      _findWayStartTime = null;
      _friendFixedPosition = null;
      _isNavigating = false;
    });

    // 타이머 및 경로 정리
    _findWayExpiryTimer?.cancel();
    _clearNavigationRoute();
    _clearFindWayStartTime();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('찾아가기 요청이 취소되었습니다')));
  }

  // 찾아가기 중단 처리
  void _handleFollowStopped(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      _followStatus = 'none';
      _isNavigating = false;
      _isRequester = false;
      _currentRequestId = null;
      _findWayStartTime = null;
      _friendFixedPosition = null;
    });

    // 타이머 및 경로 정리
    _findWayExpiryTimer?.cancel();
    _clearNavigationRoute();
    _clearFindWayStartTime();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('찾아가기가 중단되었습니다')));
  }

  // 찾아가기 요청 전송
  void _sendFollowRequest() {
    final friendId = widget.selectedFriend['id'].toString();
    _socketService.sendFollowRequest(friendId);

    setState(() {
      _followStatus = 'pending';
      _isRequester = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('찾아가기 요청을 보냈습니다')));
  }

  // 찾아가기 요청 취소
  void _cancelFollowRequest() {
    final friendId = widget.selectedFriend['id'].toString();
    _socketService.cancelFollowRequest(friendId);

    setState(() {
      _followStatus = 'none';
      _isRequester = false;
      _currentRequestId = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('찾아가기 요청을 취소했습니다')));
  }

  // 위치 공유 시작 요청
  Future<void> _requestLocationSharing() async {
    try {
      final friendId = widget.selectedFriend['id'].toString();
      _socketService.startLocationSharing(friendId, null); // 무제한 시간

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.selectedFriend['name']}님에게 위치 공유를 요청했습니다'),
        ),
      );
    } catch (e) {
      print('위치 공유 요청 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 공유 요청에 실패했습니다')));
    }
  }

  // 위치 공유 중단 요청
  Future<void> _stopLocationSharing() async {
    try {
      final friendId = widget.selectedFriend['id'].toString();
      _socketService.stopLocationSharing(friendId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 공유를 중단했습니다')));
    } catch (e) {
      print('위치 공유 중단 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 공유 중단에 실패했습니다')));
    }
  }

  // 내 위치 팔로우
  void _followMyLocation() {
    if (_myPosition != null && _mapController != null) {
      _mapController!.updateCamera(
        NCameraUpdate.withParams(target: _myPosition!, zoom: _currentZoom),
      );
    }
  }

  // 내 위치 데이터베이스 업데이트
  Future<void> _updateMyLocationInDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || TokenService.isTokenExpired(token)) {
        return;
      }

      final myLocationData = await LocationService.getCurrentLocation();
      if (myLocationData != null) {
        await LocationService.updateMyLocation(
          myLocationData.latitude,
          myLocationData.longitude,
        );
      }
    } catch (e) {
      print('위치 업데이트 오류: $e');
    }
  }

  void _showFollowRequestModal(int requestId, String requesterName) {
    if (!mounted || _isModalCurrentlyShowing) return; // 🔥 안전 체크

    _isModalCurrentlyShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => FollowRequestModal(
            requestId: requestId,
            requesterName: requesterName,
            onResponseSent: () {
              print('🔥 모달 응답 완료, 상태 새로고침');
              if (mounted) {
                _isModalCurrentlyShowing = false;
                _loadFollowStatus(); // 상태 다시 로드
              }
            },
          ),
    ).then((_) {
      print('🔥 모달 완전히 닫힘');
      if (mounted) {
        _isModalCurrentlyShowing = false;
        // 🔥 모달 닫힐 때는 상태 새로고침 하지 않음 (중복 방지)
      }
    });
  }

  // 찾아가기 모달 표시
  void _showFindWayModal() {
    if (_isModalCurrentlyShowing) return;

    _isModalCurrentlyShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => FollowModal(
            friend: widget.selectedFriend, // 🔥 수정: friendName -> friend
            currentStatus: _followStatus,
            isRequester: _isRequester,
            onStatusChanged: () {
              _loadFollowStatus();
              _isModalCurrentlyShowing = false;

              // 🔥 추가: 허용된 상태에서 요청자가 길찾기 시작을 눌렀을 때 Transit 페이지로 이동
              Future.delayed(Duration(milliseconds: 500), () {
                if (_followStatus == 'accepted' &&
                    _isRequester &&
                    _friendFixedPosition != null &&
                    _myPosition != null) {
                  print('🔥 조건 만족 - Transit 페이지로 이동');
                  _navigateToTransitPage();
                } else {
                  print(
                    '🔥 조건 불만족 - Transit 이동 안함: status=$_followStatus, isRequester=$_isRequester',
                  );
                }
              });
            },
          ),
    ).then((_) {
      _isModalCurrentlyShowing = false;
    });
  }

  // FCM 토큰 서버에 저장
  Future<void> _saveFCMToken() async {
    try {
      print('🔥 real_time_location_sharing에서 FCM 토큰 저장 시작');

      final token = await PushNotificationService().getCurrentToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        final authToken = prefs.getString('token');

        if (authToken != null) {
          final apiBaseUrl = _getApiBaseUrl();
          final response = await http.post(
            Uri.parse('$apiBaseUrl/account/profile/save-fcm-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: json.encode({'fcm_token': token}),
          );

          print('🔥 FCM 토큰 서버 응답: ${response.statusCode}');
          print('🔥 FCM 토큰 서버 응답 내용: ${response.body}');

          if (response.statusCode == 200) {
            print('🔥 FCM 토큰 서버에 저장 완료');
          }
        } else {
          print('🔥 Auth Token 없음');
        }
      }
    } catch (e) {
      print('🔥 FCM 토큰 저장 오류: $e');
    }
  }

  // 찾아가기 시작 시간 저장
  Future<void> _saveFindWayStartTime() async {
    if (_findWayStartTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'findway_start_time_${widget.selectedFriend['id']}',
        _findWayStartTime!.toIso8601String(),
      );
    }
  }

  // 찾아가기 시작 시간 불러오기
  Future<void> _loadFindWayStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(
      'findway_start_time_${widget.selectedFriend['id']}',
    );

    if (timeString != null) {
      _findWayStartTime = DateTime.parse(timeString);

      // 1시간이 지났는지 확인
      final now = DateTime.now();
      final difference = now.difference(_findWayStartTime!);

      if (difference.inHours >= 1) {
        // 이미 만료됨
        _expireFindWay();
      } else {
        // 아직 유효함 - 남은 시간으로 타이머 설정
        final remainingTime = Duration(hours: 1) - difference;
        _startFindWayExpiryTimer(duration: remainingTime);
      }
    }
  }

  // 1시간 만료 타이머 시작
  void _startFindWayExpiryTimer({Duration? duration}) {
    _findWayExpiryTimer?.cancel(); // 기존 타이머 취소

    final timerDuration = duration ?? Duration(hours: 1);

    _findWayExpiryTimer = Timer(timerDuration, () {
      _expireFindWay();
    });
  }

  // 찾아가기 만료 처리
  void _expireFindWay() {
    if (!mounted) return;

    setState(() {
      _followStatus = 'none';
      _isRequester = false;
      _currentRequestId = null;
      _findWayStartTime = null;
      _friendFixedPosition = null;
      _isNavigating = false;
    });

    // 경로 제거
    _clearNavigationRoute();

    // SharedPreferences에서 시간 정보 제거
    _clearFindWayStartTime();

    // 만료 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('찾아가기 시간이 만료되었습니다'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // 찾아가기 시간 정보 제거
  Future<void> _clearFindWayStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('findway_start_time_${widget.selectedFriend['id']}');
  }

  // 찾아가기 상태에 따른 하단바 메시지 생성
  String _getFindWayStatusMessage() {
    switch (_followStatus) {
      case 'pending':
        if (_isRequester) {
          return '${widget.selectedFriend['name']}님에게 알림을 보냈습니다';
        } else {
          return '${widget.selectedFriend['name']}님이 찾아가기를 요청했습니다';
        }
      case 'accepted':
        if (_isRequester) {
          return '${widget.selectedFriend['name']}님 마커를 클릭하여 길찾기 시작';
        } else {
          return '${widget.selectedFriend['name']}님이 찾아가기 하는중';
        }
      default:
        return '';
    }
  }

  // 찾아가기 상태에 따른 하단바 색상 결정
  Color _getFindWayStatusColor() {
    switch (_followStatus) {
      case 'pending':
        return Colors.blue[50]!;
      case 'accepted':
        return Colors.green[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  // 찾아가기 상태에 따른 하단바 테두리 색상 결정
  Color _getFindWayStatusBorderColor() {
    switch (_followStatus) {
      case 'pending':
        return Colors.blue[300]!;
      case 'accepted':
        return Colors.green[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  // Transit 페이지로 이동
  void _navigateToTransitPage() {
    if (_myPosition == null || _friendFixedPosition == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 정보를 가져올 수 없습니다')));
      return;
    }

    // TransitApp으로 이동 (실제 프로젝트 구조에 맞게)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace: '내 위치',
              initialOriginCoords: _myPosition!,
              initialDestinationPlace: '${widget.selectedFriend['name']}님 위치',
              initialDestinationCoords: _friendFixedPosition!,
            ),
      ),
    );
  }

  // 찾아가기 상태에 따른 아이콘 결정
  IconData _getFindWayStatusIcon() {
    switch (_followStatus) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return _isRequester ? Icons.navigation : Icons.location_on;
      default:
        return Icons.info;
    }
  }

  // 초기 로딩 시에만 로딩 표시와 함께 데이터 로드
  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _fetchLocationData();
      setState(() {
        _isLoading = false;
        _isInitialLoadComplete = true;
      });
    } catch (e) {
      print('위치 정보 로드 오류: $e');
      setState(() {
        _errorMessage = '위치 정보를 불러오는데 실패했습니다. 나중에 다시 시도해주세요.';
        _isLoading = false;
      });
    }
  }

  // 로딩 표시 없이 위치 정보 갱신
  Future<void> _refreshLocations() async {
    if (!_isInitialLoadComplete) return;

    try {
      await _fetchLocationData();
    } catch (e) {
      print('위치 정보 새로고침 오류: $e');
    }
  }

  // 실제 위치 데이터를 가져오는 공통 로직
  Future<void> _fetchLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('user_id');

    if (token == null || TokenService.isTokenExpired(token)) {
      setState(() {
        _errorMessage = '로그인이 필요하거나 세션이 만료되었습니다';
      });
      return;
    }

    print('위치 정보 로드 중... 내 ID: $userId, 친구 ID: ${widget.selectedFriend['id']}');

    // 1. 내 위치 가져오기
    final myLocationData = await LocationService.getCurrentLocation();
    if (myLocationData != null) {
      setState(() {
        _myPosition = NLatLng(
          myLocationData.latitude,
          myLocationData.longitude,
        );
      });

      // 초기 진입 시에만 카메라 이동
      if (_mapController != null && !_isInitialCameraSet) {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
        );
        _isInitialCameraSet = true;
      }
    }

    final friendId = widget.selectedFriend['id'];

    // 2. 위치 공유 상태 확인
    final iAmSharing = await LocationService.checkIAmSharingWith(friendId);
    final friendIsSharing = await LocationService.checkFriendIsSharingWith(
      friendId,
    );

    setState(() {
      _iAmSharingLocation = iAmSharing;
      _friendIsSharingLocation = friendIsSharing;

      if (!friendIsSharing) {
        _friendPosition = null;
      }
    });

    print('위치 공유 상태: 내가 공유 중: $iAmSharing, 친구가 공유 중: $friendIsSharing');

    // 3. 친구 위치 정보 가져오기 - 친구가 공유 중인 경우에만
    if (friendIsSharing) {
      final friendLocationData = await LocationService.getFriendLocation(
        friendId,
      );

      if (friendLocationData != null) {
        setState(() {
          _friendPosition = NLatLng(
            double.parse(friendLocationData['latitude'].toString()),
            double.parse(friendLocationData['longitude'].toString()),
          );
          _lastUpdateTime = DateTime.now();
        });

        // 길찾기 중이면 경로 업데이트
        if (_isNavigating) {
          _updateNavigationRoute();
        }

        print(
          '친구 위치 정보 로드 성공: ${friendLocationData['latitude']}, ${friendLocationData['longitude']}',
        );
      } else {
        print('친구 위치 정보를 가져오는데 실패했습니다.');
      }
    }

    // 위치 데이터를 얻은 후 마커 업데이트
    if (_mapController != null) {
      if (!_isInitialCameraSet) {
        _updateMapMarkers(); // 초기에는 카메라 포함 업데이트
      } else {
        _updateMapMarkersWithoutCameraChange(); // 이후에는 마커만 업데이트
      }
    }
  }

  // 내 위치 마커 생성 함수
  NMarker _createMyLocationMarker() {
    final marker = NMarker(id: 'my_location', position: _myPosition!);
    final overlayImage = NOverlayImage.fromAssetImage('assets/icons/me.png');
    marker.setIcon(overlayImage);
    marker.setSize(NSize(48, 48));
    marker.setAnchor(NPoint(0.5, 1.0));
    marker.setCaption(
      NOverlayCaption(
        text: '내 위치',
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    // 이벤트 리스너 설정
    marker.setOnTapListener((overlay) {
      print("내 위치 터치됨!");
      // 내 위치 관련 로직
    });

    return marker;
  }

  // 친구 위치 마커 생성 함수
  NMarker _createFriendLocationMarker() {
    final marker = NMarker(id: 'friend_location', position: _friendPosition!);
    final overlayImage = NOverlayImage.fromAssetImage(
      'assets/icons/friends.png',
    );
    marker.setIcon(overlayImage);
    marker.setSize(NSize(48, 48));
    marker.setAnchor(NPoint(0.5, 1.0));
    marker.setCaption(
      NOverlayCaption(
        text: widget.selectedFriend['name'],
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    // 친구 마커 클릭 이벤트 수정
    marker.setOnTapListener((overlay) {
      print("친구 위치 터치됨!");
      print("현재 찾아가기 상태: $_followStatus");
      print("내가 요청자인지: $_isRequester");
      print("친구 고정 위치: $_friendFixedPosition");
      print("내 위치: $_myPosition");

      // 🔥 수정된 조건: 모든 경우에 모달을 먼저 표시
      print("찾아가기 모달 표시");
      _showFindWayModal();
    });

    return marker;
  }

  // 카메라 변경 없이 마커만 업데이트하는 함수
  Future<void> _updateMapMarkersWithoutCameraChange() async {
    if (_mapController == null || _isUpdatingMarkers) return;

    _isUpdatingMarkers = true;

    try {
      // 기존 마커 모두 제거
      if (_markers.isNotEmpty) {
        for (final marker in _markers) {
          try {
            await _mapController!.deleteOverlay(marker.info);
          } catch (e) {
            // 이미 삭제된 마커는 무시
          }
        }
        _markers.clear();
      }

      // 내 위치 마커 추가
      if (_myPosition != null && _iAmSharingLocation) {
        final myMarker = _createMyLocationMarker();
        myMarker.setOnTapListener((NMarker marker) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('내 현재 위치')));
        });
        await _mapController!.addOverlay(myMarker);
        _markers.add(myMarker);
      }

      // 친구 위치 마커 추가
      if (_friendPosition != null &&
          _friendIsSharingLocation &&
          _iAmSharingLocation) {
        if (_friendPosition!.latitude != 0 && _friendPosition!.longitude != 0) {
          final friendMarker = _createFriendLocationMarker();

          await _mapController!.addOverlay(friendMarker);
          _markers.add(friendMarker);
        }
      }
    } finally {
      _isUpdatingMarkers = false;
    }
  }

  // 지도 마커 업데이트 (카메라 포함)
  Future<void> _updateMapMarkers() async {
    if (_mapController == null) return;

    // 마커 업데이트
    await _updateMapMarkersWithoutCameraChange();

    // 최초 카메라 위치 조정 (수동 조작하지 않은 경우에만)
    if (!_isInitialCameraSet && !_userManuallyControlledCamera) {
      if (_myPosition != null &&
          _friendPosition != null &&
          _friendIsSharingLocation) {
        _fitBoundsToShowBothMarkers();
      } else if (_myPosition != null) {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
        );
      }
      _isInitialCameraSet = true;
    }
  }

  // 길찾기 시작
  void _startNavigation() {
    if (_friendPosition == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구의 위치 정보가 없습니다')));
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    _updateNavigationRoute();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.selectedFriend['name']}님에게 찾아가기를 시작합니다'),
      ),
    );
  }

  // 길찾기 중단
  void _stopNavigation() {
    if (!_isNavigating) return;

    setState(() {
      _isNavigating = false;
    });

    // 경로 오버레이 제거
    _clearNavigationRoute();

    print('네비게이션 중단됨');

    // 스낵바로 사용자에게 알림
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('찾아가기가 중단되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 네비게이션 경로 업데이트
  Future<void> _updateNavigationRoute() async {
    if (!_isNavigating ||
        _myPosition == null ||
        _friendPosition == null ||
        _mapController == null) {
      return;
    }

    try {
      // 기존 경로 제거
      _clearNavigationRoute();

      // 네이버 방향 API 호출
      final pathOverlay = NPathOverlay(
        id: 'navigation_path',
        coords: [_myPosition!, _friendPosition!],
        color: Colors.blue,
        width: 5,
      );

      setState(() {
        _pathOverlays.add(pathOverlay);
      });

      _mapController!.addOverlay(pathOverlay);
      print('네비게이션 경로 업데이트됨');
    } catch (e) {
      print('네비게이션 경로 업데이트 오류: $e');
    }
  }

  // 네비게이션 경로 제거
  void _clearNavigationRoute() {
    if (_mapController != null) {
      for (final overlay in _pathOverlays) {
        _mapController!.deleteOverlay(overlay.info);
      }
    }
    setState(() {
      _pathOverlays.clear();
    });
  }

  // 두 위치 간 거리 계산 (미터 단위)
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)

    double lat1Rad = point1.latitude * pi / 180;
    double lat2Rad = point2.latitude * pi / 180;
    double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;

    double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // 두 마커가 모두 보이도록 카메라 조정 (거리에 따라 유동적 줌)
  void _fitBoundsToShowBothMarkers() {
    if (_myPosition == null ||
        _friendPosition == null ||
        _mapController == null)
      return;

    // 두 위치 간 거리 계산
    double distance = _calculateDistance(_myPosition!, _friendPosition!);

    // 거리에 따른 적절한 줌 레벨 결정
    double targetZoom;
    if (distance < 100) {
      targetZoom = 17.0; // 100m 이내 - 확대
    } else if (distance < 500) {
      targetZoom = 15.0; // 500m 이내 - 중간 줌
    } else if (distance < 1000) {
      targetZoom = 14.0; // 1km 이내
    } else {
      targetZoom = 13.0; // 1km 이상 - 전체 보기
    }

    // 두 위치의 중심점 계산
    double centerLat = (_myPosition!.latitude + _friendPosition!.latitude) / 2;
    double centerLng =
        (_myPosition!.longitude + _friendPosition!.longitude) / 2;
    NLatLng centerPosition = NLatLng(centerLat, centerLng);

    // 카메라 이동
    _mapController!.updateCamera(
      NCameraUpdate.withParams(target: centerPosition, zoom: targetZoom),
    );

    // 현재 줌 레벨 업데이트
    _currentZoom = targetZoom;
  }

  // 마지막 업데이트 시간 포맷팅
  String _formatLastUpdateTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}초 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${time.month}월 ${time.day}일 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  // 카메라 수동 조작 감지 함수
  void _onCameraChanged() {
    _userManuallyControlledCamera = true;
    _lastManualCameraControl = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${widget.selectedFriend['name']}님과 위치 공유',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // 네이버 맵
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _myPosition ?? NLatLng(37.5666805, 126.9784147),
                zoom: 15,
              ),
              mapType: NMapType.basic,
              contentPadding: EdgeInsets.zero,
              locationButtonEnable: false,
            ),
            onMapReady: (controller) {
              setState(() {
                _mapController = controller;
              });
              _updateMapMarkers();

              if (_myPosition != null) {
                controller.updateCamera(
                  NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
                );
                _isInitialCameraSet = true;
              }
            },
            onCameraIdle: () {
              _onCameraChanged(); // 카메라 수동 조작 감지
              if (_mapController != null) {
                _mapController!.getCameraPosition().then((position) {
                  _currentZoom = position.zoom;
                });
              }
            },
          ),

          // 두 위치 보기 버튼 (👥 아이콘)
          Positioned(
            bottom: 80, // 내 위치 버튼 위에
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              mini: true,
              heroTag: "both_locations",
              child: Text('👥', style: TextStyle(fontSize: 20)),
              onPressed: () {
                if (_myPosition != null &&
                    _friendPosition != null &&
                    _friendIsSharingLocation) {
                  _fitBoundsToShowBothMarkers();
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('친구의 위치 정보가 없습니다.')));
                }
              },
            ),
          ),

          // 현재 위치 버튼
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              mini: true,
              heroTag: "my_location",
              child: Icon(Icons.my_location, color: Colors.black),
              onPressed: () {
                if (_myPosition != null && _mapController != null) {
                  _mapController!.updateCamera(
                    NCameraUpdate.withParams(
                      target: _myPosition!,
                      zoom: _currentZoom,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('내 위치 정보를 가져올 수 없습니다.')),
                  );
                }
              },
            ),
          ),

          // 로딩 표시 (초기 로딩 시에만 표시)
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFFFB233B),
                ),
              ),
            ),

          // 오류 메시지
          if (_errorMessage.isNotEmpty)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 12),
                      Text(
                        _errorMessage,
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLocations,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFB233B),
                        ),
                        child: Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 위치 공유 상태 메시지 - 트렌디한 레이더 디자인
          if (!_isLoading &&
              _errorMessage.isEmpty &&
              !_iAmSharingLocation &&
              _isInitialLoadComplete)
            Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20.0),
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1F2937),
                        Color(0xFF111827),
                        Color(0xFF0F172A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Color(0xFF3B82F6).withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 파동 효과와 중앙 아이콘 - 실제 애니메이션 적용
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _waveAnimation1,
                          _waveAnimation2,
                          _waveAnimation3,
                        ]),
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // 파동 효과 1 - 가장 큰 원
                              Transform.scale(
                                scale: 0.5 + (_waveAnimation1.value * 0.5),
                                child: Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(0xFF3B82F6).withOpacity(
                                        0.4 * (1 - _waveAnimation1.value),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              // 파동 효과 2 - 중간 원
                              Transform.scale(
                                scale: 0.6 + (_waveAnimation2.value * 0.4),
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(0xFF8B5CF6).withOpacity(
                                        0.5 * (1 - _waveAnimation2.value),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              // 파동 효과 3 - 작은 원
                              Transform.scale(
                                scale: 0.7 + (_waveAnimation3.value * 0.3),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(0xFFEC4899).withOpacity(
                                        0.7 * (1 - _waveAnimation3.value),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              // 중앙 아이콘 - 맥박 효과
                              AnimatedContainer(
                                duration: Duration(milliseconds: 1200),
                                curve: Curves.easeInOut,
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF3B82F6).withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                    BoxShadow(
                                      color: Color(0xFF8B5CF6).withOpacity(0.3),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '📡',
                                    style: TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: 24),

                      // 제목
                      Column(
                        children: [
                          Text(
                            'CONNECTION STATUS',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '위치 공유 대기중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      // 상태 박스
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Disconnected',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              '친구 설정에서 위치 공유를 활성화하면\n실시간 추적이 시작됩니다',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // 버튼
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // 뒤로가기
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ).copyWith(
                            backgroundColor: MaterialStateProperty.all(
                              Colors.transparent,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF8B5CF6),
                                  Color(0xFFEC4899),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF3B82F6).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                '🔗 연결하러 가기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 위치 공유 시간 정보
          if (_friendIsSharingLocation &&
              _lastUpdateTime != null &&
              _iAmSharingLocation)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '마지막 업데이트: ${_formatLastUpdateTime(_lastUpdateTime!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ),
            ),

          // 친구 위치 공유 상태 표시 - 내가 공유 중이지만 친구는 아닐 때
          if (!_friendIsSharingLocation && _iAmSharingLocation)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.selectedFriend['name']}님은 아직 위치를 공유하고 있지 않습니다',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ),
              ),
            ),

          // 찾아가기 상태 표시 (통합된 하단바)
          if (_followStatus != 'none' && _getFindWayStatusMessage().isNotEmpty)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getFindWayStatusColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getFindWayStatusBorderColor()),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFindWayStatusIcon(),
                      color: _getFindWayStatusBorderColor(),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getFindWayStatusMessage(),
                        style: TextStyle(color: _getFindWayStatusBorderColor()),
                      ),
                    ),
                    // 상태별 추가 정보 표시
                    if (_followStatus == 'accepted' &&
                        _findWayStartTime != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: StreamBuilder(
                          stream: Stream.periodic(Duration(seconds: 1)),
                          builder: (context, snapshot) {
                            if (_findWayStartTime == null)
                              return SizedBox.shrink();

                            final now = DateTime.now();
                            final elapsed = now.difference(_findWayStartTime!);
                            final remaining = Duration(hours: 1) - elapsed;

                            if (remaining.isNegative) {
                              return Text(
                                '만료됨',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }

                            final minutes = remaining.inMinutes;
                            final seconds = remaining.inSeconds % 60;

                            return Text(
                              '${minutes}:${seconds.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 길찾기 진행 중 표시
          if (_isNavigating)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.navigation, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${widget.selectedFriend['name']}님을 찾아가는 중입니다',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

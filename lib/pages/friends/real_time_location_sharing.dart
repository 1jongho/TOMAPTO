import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/services/location_service.dart';
import 'package:tomapto/services/token_service.dart';

class RealTimeLocationSharingPage extends StatefulWidget {
  final Map<String, dynamic> selectedFriend;

  const RealTimeLocationSharingPage({Key? key, required this.selectedFriend})
    : super(key: key);

  @override
  _RealTimeLocationSharingPageState createState() =>
      _RealTimeLocationSharingPageState();
}

class _RealTimeLocationSharingPageState
    extends State<RealTimeLocationSharingPage> {
  NaverMapController? _mapController;
  NLatLng? _myPosition;
  NLatLng? _friendPosition;
  final Set<NMarker> _markers = {};
  bool _isInitialCameraSet = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // 소켓 서비스 인스턴스
  late SocketService _socketService;
  // 위치 정보 자동 갱신을 위한 타이머
  Timer? _locationUpdateTimer;
  // 소켓 이벤트 구독자
  StreamSubscription? _locationUpdateSubscription;
  // 위치 공유 상태 (현재 활성화 여부)
  bool _isLocationSharingActive = false;
  // 마지막 업데이트 시간
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService();
    _initSocket();
    _loadLocations();

    // 10초마다 위치 정보 갱신 (API 호출) - 백업 메커니즘
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      // 마지막 업데이트 후 10초 이상 지났으면 API로 다시 로드
      final now = DateTime.now();
      if (_lastUpdateTime == null ||
          now.difference(_lastUpdateTime!).inSeconds > 10) {
        _loadLocations();
      }
    });
  }

  @override
  void dispose() {
    // 타이머 정리
    _locationUpdateTimer?.cancel();
    // 소켓 이벤트 구독 취소
    _locationUpdateSubscription?.cancel();
    super.dispose();
  }

  // 소켓 초기화 및 이벤트 리스너 설정
  Future<void> _initSocket() async {
    try {
      if (!_socketService.isConnected) {
        await _socketService.initSocket();
      }

      // 위치 업데이트 이벤트 구독
      _locationUpdateSubscription = _socketService.onLocationUpdate.listen((
        data,
      ) {
        // 친구 ID가 선택한 친구의 ID와 일치하는지 확인
        if (data['user_id'] == widget.selectedFriend['id']) {
          setState(() {
            _friendPosition = NLatLng(data['latitude'], data['longitude']);
            _lastUpdateTime = DateTime.now();
            _updateMapMarkers();
          });
          print('소켓으로 친구 위치 업데이트: ${data['latitude']}, ${data['longitude']}');
        }
      });

      // 위치 공유 종료 이벤트 리스너 추가
      _socketService.onLocationSharingStopped.listen((data) {
        if (data['user_id'] == widget.selectedFriend['id']) {
          setState(() {
            _isLocationSharingActive = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.selectedFriend['name']}님이 위치 공유를 종료했습니다'),
            ),
          );
        }
      });

      print('소켓 이벤트 리스너 설정 완료');
    } catch (e) {
      print('소켓 초기화 오류: $e');
    }
  }

  // DB에서 내 위치와 친구 위치 정보 로드
  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 토큰 유효성 확인
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || TokenService.isTokenExpired(token)) {
        setState(() {
          _errorMessage = '로그인이 필요하거나 세션이 만료되었습니다';
          _isLoading = false;
        });
        return;
      }

      // 1. 내 위치 가져오기
      final myLocationData = await LocationService.getCurrentLocation();
      if (myLocationData != null) {
        setState(() {
          _myPosition = NLatLng(
            myLocationData.latitude,
            myLocationData.longitude,
          );
        });
      } else {
        print('내 위치 정보를 가져오는데 실패했습니다.');
      }

      // 2. 친구 위치 정보 가져오기
      final friendId = widget.selectedFriend['id'];
      final friendLocationData = await LocationService.getFriendLocation(
        friendId,
      );

      if (friendLocationData != null) {
        setState(() {
          _friendPosition = NLatLng(
            friendLocationData['latitude'],
            friendLocationData['longitude'],
          );
          _isLocationSharingActive = true;
          _lastUpdateTime = DateTime.now();
        });
        print(
          '친구 위치 정보 로드 성공: 위도=${friendLocationData['latitude']}, 경도=${friendLocationData['longitude']}',
        );
      } else {
        print('친구 위치 정보를 가져오는데 실패했습니다.');
        setState(() {
          _isLocationSharingActive = false;
        });
      }

      // 위치 데이터를 얻은 후 마커 업데이트
      if (_mapController != null) {
        _updateMapMarkers();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('위치 정보 로드 오류: $e');
      setState(() {
        _errorMessage = '위치 정보를 불러오는데 실패했습니다. 나중에 다시 시도해주세요.';
        _isLoading = false;
      });

      // 에러 발생 시 기본 위치 설정
      if (_myPosition == null && _mapController != null) {
        // 서울 시청 좌표 (기본값)
        _myPosition = NLatLng(37.5666805, 126.9784147);
      }
    }
  }

  // 내 위치 마커 생성 함수 (빨간색)
  NMarker _createMyLocationMarker() {
    final marker = NMarker(id: 'my_location', position: _myPosition!);

    // 마커 이미지 설정
    marker.setIconTintColor(Colors.red);

    // 앵커 포인트 조정
    marker.setAnchor(NPoint(0.5, 1.0));

    // 캡션 설정
    marker.setCaption(
      NOverlayCaption(
        text: '내 위치',
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    return marker;
  }

  // 친구 위치 마커 생성 함수 (초록색)
  NMarker _createFriendLocationMarker() {
    final marker = NMarker(id: 'friend_location', position: _friendPosition!);

    // 마커 이미지 설정
    marker.setIconTintColor(Colors.green);

    // 앵커 포인트 조정
    marker.setAnchor(NPoint(0.5, 1.0));

    // 캡션 설정
    marker.setCaption(
      NOverlayCaption(
        text: widget.selectedFriend['name'],
        textSize: 14,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    );

    return marker;
  }

  // 지도 마커 업데이트
  Future<void> _updateMapMarkers() async {
    if (_mapController == null) return;

    // 기존 마커 모두 제거
    if (_markers.isNotEmpty) {
      for (final marker in _markers) {
        _mapController!.deleteOverlay(marker.info);
      }
      _markers.clear();
    }

    // 내 위치 마커 추가
    if (_myPosition != null) {
      final myMarker = _createMyLocationMarker();

      myMarker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('내 현재 위치')));
      });

      _mapController!.addOverlay(myMarker);
      _markers.add(myMarker);
    }

    // 친구 위치 마커 추가
    if (_friendPosition != null) {
      final friendMarker = _createFriendLocationMarker();

      friendMarker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.selectedFriend['name']}님의 위치')),
        );
      });

      _mapController!.addOverlay(friendMarker);
      _markers.add(friendMarker);
    }

    // 카메라 위치 조정
    if (!_isInitialCameraSet &&
        _myPosition != null &&
        _friendPosition != null) {
      _fitBoundsToShowBothMarkers();
      _isInitialCameraSet = true;
    } else if (!_isInitialCameraSet && _myPosition != null) {
      _mapController!.updateCamera(
        NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
      );
      _isInitialCameraSet = true;
    } else if (!_isInitialCameraSet && _friendPosition != null) {
      _mapController!.updateCamera(
        NCameraUpdate.withParams(target: _friendPosition!, zoom: 15),
      );
      _isInitialCameraSet = true;
    }
  }

  // 두 마커가 모두 보이도록 카메라 조정
  void _fitBoundsToShowBothMarkers() {
    if (_myPosition == null ||
        _friendPosition == null ||
        _mapController == null)
      return;

    // 두 위치의 경계 계산
    double minLat =
        _myPosition!.latitude < _friendPosition!.latitude
            ? _myPosition!.latitude
            : _friendPosition!.latitude;
    double maxLat =
        _myPosition!.latitude > _friendPosition!.latitude
            ? _myPosition!.latitude
            : _friendPosition!.latitude;
    double minLng =
        _myPosition!.longitude < _friendPosition!.longitude
            ? _myPosition!.longitude
            : _friendPosition!.longitude;
    double maxLng =
        _myPosition!.longitude > _friendPosition!.longitude
            ? _myPosition!.longitude
            : _friendPosition!.longitude;

    // 패딩 추가
    minLat -= 0.01;
    maxLat += 0.01;
    minLng -= 0.01;
    maxLng += 0.01;

    // 경계 객체 생성
    final bounds = NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );

    // 경계에 맞게 카메라 조정 - 패딩을 double 값으로 전달
    _mapController!.updateCamera(
      NCameraUpdate.fitBounds(
        bounds,
        padding: EdgeInsets.all(50.0), // EdgeInsets 객체로 변경
      ),
    );
  }

  // 위치 공유 종료 요청
  Future<void> _endLocationSharing() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 종료 확인 다이얼로그
      final result = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('위치 공유 종료'),
              content: Text(
                '${widget.selectedFriend['name']}님과의 위치 공유를 종료하시겠습니까?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('종료'),
                ),
              ],
            ),
      );

      if (result != true) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 소켓을 통한 위치 공유 종료 요청
      _socketService.stopLocationSharing(widget.selectedFriend['id']);

      // API를 통한 위치 공유 종료 요청
      final success = await LocationService.endLocationSharing(
        widget.selectedFriend['id'],
      );

      setState(() {
        _isLoading = false;
        if (success) {
          _isLocationSharingActive = false;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('위치 공유가 종료되었습니다')));
          // 공유 종료 후 페이지 닫기
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('위치 공유 종료 요청 실패. 나중에 다시 시도하세요.')),
          );
        }
      });
    } catch (e) {
      print('위치 공유 종료 오류: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 공유 종료 중 오류가 발생했습니다.')));
    }
  }

  // 위치 공유 시작 요청
  Future<void> _startLocationSharing() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 시작 확인 다이얼로그
      final result = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('위치 공유 시작'),
              content: Text(
                '${widget.selectedFriend['name']}님과 위치 공유를 시작하시겠습니까?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                  child: Text('시작'),
                ),
              ],
            ),
      );

      if (result != true) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 소켓을 통한 위치 공유 시작 요청
      _socketService.startLocationSharing(widget.selectedFriend['id'], null);

      // API를 통한 위치 공유 시작 요청
      final success = await LocationService.requestLocationSharing(
        widget.selectedFriend['id'],
      );

      setState(() {
        _isLoading = false;
        if (success) {
          _isLocationSharingActive = true;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('위치 공유가 시작되었습니다')));
          // 위치 정보 새로고침
          _loadLocations();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('위치 공유 시작 요청 실패. 나중에 다시 시도하세요.')),
          );
        }
      });
    } catch (e) {
      print('위치 공유 시작 오류: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 공유 시작 중 오류가 발생했습니다.')));
    }
  }

  // 친구 위치 히스토리 불러오기
  Future<void> _loadFriendLocationHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // API를 통한 위치 히스토리 조회
      final historyData = await LocationService.getLocationHistory(
        widget.selectedFriend['id'],
      );

      setState(() {
        _isLoading = false;
      });

      if (historyData != null && historyData.isNotEmpty) {
        // 히스토리 데이터를 표시하는 다이얼로그
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('${widget.selectedFriend['name']}님의 위치 기록'),
                content: Container(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.builder(
                    itemCount: historyData.length,
                    itemBuilder: (context, index) {
                      final item = historyData[index];
                      final date = DateTime.parse(item['created_at']);
                      return ListTile(
                        title: Text(
                          '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}:${date.second}',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '위도: ${item['latitude'].toStringAsFixed(6)}, 경도: ${item['longitude'].toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 12),
                        ),
                        // 클릭 시 해당 위치로 이동
                        onTap: () {
                          Navigator.pop(context);
                          if (_mapController != null) {
                            _mapController!.updateCamera(
                              NCameraUpdate.withParams(
                                target: NLatLng(
                                  item['latitude'],
                                  item['longitude'],
                                ),
                                zoom: 16,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('닫기'),
                  ),
                ],
              ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('위치 기록이 없습니다')));
      }
    } catch (e) {
      print('위치 히스토리 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 기록을 불러오는 중 오류가 발생했습니다.')));
    }
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
                target:
                    _myPosition ??
                    NLatLng(37.5666805, 126.9784147), // 기본값: 서울시청
                zoom: 15,
              ),
              mapType: NMapType.basic,
              contentPadding: EdgeInsets.zero,
            ),
            onMapReady: (controller) {
              setState(() {
                _mapController = controller;
              });
              _updateMapMarkers(); // 비동기 함수지만 여기서는 await 없이 호출
            },
          ),

          // 현재 위치 버튼
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              mini: true,
              child: Icon(Icons.my_location, color: Colors.black),
              onPressed: () {
                if (_myPosition != null && _mapController != null) {
                  _mapController!.updateCamera(
                    NCameraUpdate.withParams(target: _myPosition!, zoom: 15),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('내 위치 정보를 가져올 수 없습니다.')),
                  );
                }
              },
            ),
          ),

          // 로딩 표시
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

          // 위치 공유 상태 메시지
          if (!_isLocationSharingActive && !_isLoading && _errorMessage.isEmpty)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off, color: Colors.orange, size: 48),
                      SizedBox(height: 12),
                      Text(
                        '${widget.selectedFriend['name']}님과 위치 공유가 활성화되지 않았습니다.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _startLocationSharing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Text('위치 공유 시작하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 위치 공유 시간 정보
          if (_isLocationSharingActive && _lastUpdateTime != null)
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
        ],
      ),
      // 위치 공유 종료 버튼 (하단에 고정)
      bottomNavigationBar:
          _isLocationSharingActive
              ? Container(
                color: Colors.white,
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _endLocationSharing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '위치 공유 종료',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
              : null,
    );
  }
}

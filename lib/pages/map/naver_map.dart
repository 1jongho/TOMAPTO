import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'package:tomapto/controllers/map/map_controller.dart';
import 'package:tomapto/pages/map/transit.dart';

class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  // 맵 컨트롤러
  final MapController _mapController = MapController();

  NLatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();

  // 현재 선택된 네비게이션 탭 인덱스
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    print("NaverMapPage 초기화 완료");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    // 위치 권한 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위치 권한이 필요합니다.', style: TextStyle(fontSize: 14)),
          ),
        );
        return;
      }
    }

    // 위치 서비스가 활성화 되어있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 서비스를 활성화해주세요.', style: TextStyle(fontSize: 14)),
        ),
      );
      return;
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });

      print('현재 위치: ${position.latitude}, ${position.longitude}');

      // 카메라 이동
      if (_mapController.controller != null && _currentPosition != null) {
        // 기본 줌 레벨 17로 설정
        await _mapController.moveCamera(_currentPosition!, 17);

        // 위치 추적 모드 설정
        try {
          _mapController.controller!.setLocationTrackingMode(
            NLocationTrackingMode.follow,
          );

          print('위치 추적 모드 설정 완료');
        } catch (e) {
          print('위치 추적 모드 설정 실패: $e');
        }
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 가져오기 실패: $e', style: TextStyle(fontSize: 14)),
        ),
      );
    }
  }

  // 네비게이션 탭 변경 처리
  void _handleNavIndexChanged(int index) {
    setState(() {
      _currentNavIndex = index;
    });
  }

  // Transit 페이지로 이동하는 함수
  void _navigateToTransitPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransitApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 사이즈 계산을 위한 값들
    final horizontalPadding = ResponsiveValue.padding(context, base: 16.0);
    final verticalPadding = ResponsiveValue.padding(context, base: 8.0);
    final iconSize = ResponsiveValue.width(context, base: 45.0);
    final bottomPadding = ResponsiveValue.height(context, base: 85.0);
    final rightPadding = ResponsiveValue.width(context, base: 7.0);
    final contentPadding = EdgeInsets.fromLTRB(
      0,
      0,
      0,
      ResponsiveValue.height(context, base: 80.0),
    );

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5666805, 126.9784147), // 서울 시청 (기본값)
                zoom: _mapController.currentZoom,
              ),
              mapType: NMapType.basic,
              contentPadding: contentPadding,
              locationButtonEnable: false,
              logoClickEnable: false,
              scaleBarEnable: true,
            ),
            onMapReady: (controller) {
              print('맵 컨트롤러 준비 완료');
              _mapController.setMapController(controller);
              if (_currentPosition != null) {
                print('현재 위치로 카메라 이동: $_currentPosition');
                _mapController.moveCamera(
                  _currentPosition!,
                  _mapController.currentZoom,
                );
              }
            },
            onCameraIdle: () {
              // 카메라 움직임이 멈추었을 때 줌 레벨 업데이트
              if (_mapController.controller != null) {
                _mapController.getCurrentCameraPosition().then((
                  cameraPosition,
                ) {
                  if (cameraPosition != null) {
                    double zoom = cameraPosition.zoom;
                    _mapController.setZoomLevel(zoom);
                    print('줌 레벨 업데이트됨: $zoom');
                  }
                });
              }
            },
            onMapTapped: (point, latLng) {
              print('지도가 탭되었습니다: $latLng');
            },
          ),

          // 로딩 표시
          if (_mapController.controller == null)
            Center(
              child: CircularProgressIndicator(color: const Color(0xFFFB233B)),
            ),

          // 상단 검색바
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                children: [
                  // 검색 텍스트 필드
                  Expanded(
                    child: Container(
                      height: ResponsiveValue.height(context, base: 45.0),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x19000000),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '검색어를 입력해주세요.',
                          hintStyle: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: ResponsiveValue.width(context, base: 20.0),
                            color: Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveValue.padding(
                              context,
                              base: 11.0,
                            ),
                            vertical: ResponsiveValue.padding(
                              context,
                              base: 11.0,
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

          // 현재 위치 버튼
          Positioned(
            bottom: bottomPadding,
            right: rightPadding,
            child: GestureDetector(
              onTap: () {
                _getCurrentLocation();
              },
              child: SvgPicture.asset(
                'assets/icons/gps_B.svg',
                width: iconSize,
                height: iconSize,
              ),
            ),
          ),

          // Transit 버튼 추가 (현재 위치 버튼 위에 배치)
          Positioned(
            bottom: bottomPadding + iconSize + 10, // 현재 위치 버튼 위에 10픽셀 간격으로 배치
            right: rightPadding,
            child: GestureDetector(
              onTap: _navigateToTransitPage,
              child: Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.directions, // 길찾기 아이콘
                    color: const Color(0xFFFB233B), // TOMAPTO 메인 색상
                    size: iconSize * 0.55, // 아이콘 크기 조정
                  ),
                ),
              ),
            ),
          ),

          // 하단 네비게이션 바
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: _handleNavIndexChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ResponsiveValue 클래스
class ResponsiveValue {
  static double width(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375); // 375는 기준 디자인 너비
  }

  static double height(BuildContext context, {required double base}) {
    final screenHeight = MediaQuery.of(context).size.height;
    return base * (screenHeight / 812); // 812는 기준 디자인 높이
  }

  static double padding(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375); // 375는 기준 디자인 너비
  }
}

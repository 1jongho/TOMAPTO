import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'package:tomapto/controllers/map/map_controller.dart';
import 'package:tomapto/search/search_main.dart';
import 'package:tomapto/pages/map/transit.dart';

class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  final MapController _mapController = MapController();

  NLatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();

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

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 서비스를 활성화해주세요.', style: TextStyle(fontSize: 14)),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });

      print('현재 위치: ${position.latitude}, ${position.longitude}');

      if (_mapController.controller != null && _currentPosition != null) {
        await _mapController.moveCamera(_currentPosition!, 17);

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

          if (_mapController.controller == null)
            Center(
              child: CircularProgressIndicator(color: const Color(0xFFFB233B)),
            ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const SearchMainPage(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
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
                          enabled: false,
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
                  ),
                ],
              ),
            ),
          ),
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

          // 길찾기 버튼 추가
          Positioned(
            bottom: bottomPadding + iconSize + 16, // GPS 버튼 위에 위치
            right: rightPadding,
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
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.directions,
                  color: Color(0xFFFB233B),
                  size: iconSize * 0.6,
                ),
                onPressed: _navigateToTransitPage,
                tooltip: '길찾기',
              ),
            ),
          ),

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

class ResponsiveValue {
  static double width(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375);
  }

  static double height(BuildContext context, {required double base}) {
    final screenHeight = MediaQuery.of(context).size.height;
    return base * (screenHeight / 812);
  }

  static double padding(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  // 네이버 맵 초기화
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
    onAuthFailed: (error) {
      print('네이버 맵 인증 실패: $error');
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '네이버 맵',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const NaverMapPage(),
    );
  }
}

class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  NaverMapController? _mapController;
  NLatLng? _currentPosition;
  final Set<NMarker> _markers = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    print("NaverMapPage 초기화 완료");
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다.')));
        return;
      }
    }

    // 위치 서비스가 활성화 되어있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 서비스를 활성화해주세요.')));
      return;
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });
      print('현재 위치: ${position.latitude}, ${position.longitude}');

      // 카메라 이동
      if (_mapController != null && _currentPosition != null) {
        _mapController!.updateCamera(
          NCameraUpdate.withParams(target: _currentPosition, zoom: 15),
        );

        // 마커 업데이트
        _updateMarkers();
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 가져오기 실패: $e')));
    }
  }

  void _updateMarkers() {
    print('마커 업데이트 시작');
    if (_mapController != null && _currentPosition != null) {
      // 기존 마커 제거
      if (_markers.isNotEmpty) {
        try {
          for (final marker in Set.from(_markers)) {
            // dynamic 캐스팅으로 타입 오류 해결
            _mapController!.deleteOverlay(marker as dynamic);
          }
          print('기존 마커 제거 성공');
        } catch (e) {
          print('마커 제거 실패: $e');
        }
        _markers.clear();
      }

      // 새 마커 생성
      final marker = NMarker(id: '현재위치', position: _currentPosition!);

      // 마커 색상 설정 (빨간색)
      marker.setIconTintColor(Colors.red);

      // 마커 탭 이벤트 설정
      marker.setOnTapListener((NMarker marker) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
            ),
          ),
        );
      });

      try {
        // dynamic 캐스팅으로 타입 오류 해결
        _mapController!.addOverlay(marker as dynamic);
        _markers.add(marker);
        print('마커 추가 성공');
      } catch (e) {
        print('마커 추가 실패: $e');
      }

      print(
        '마커 업데이트 완료: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 맵 뷰
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target:
                    _currentPosition ??
                    NLatLng(37.5666805, 126.9784147), // 서울 시청 (기본값)
                zoom: 15,
              ),
              mapType: NMapType.basic,
              contentPadding: const EdgeInsets.fromLTRB(0, 70, 0, 80),
            ),
            onMapReady: (controller) {
              print('맵 컨트롤러 준비 완료');
              _mapController = controller;

              if (_currentPosition != null) {
                print('현재 위치로 카메라 이동: $_currentPosition');
                _mapController!.updateCamera(
                  NCameraUpdate.withParams(target: _currentPosition, zoom: 15),
                );
                _updateMarkers();
              }
            },
            onCameraChange: (position, reason) {
              print('카메라 변경: $position, 이유: $reason');
            },
            onMapTapped: (point, latLng) {
              print('지도가 탭되었습니다: $latLng');
            },
          ),

          // 로딩 표시
          if (_mapController == null)
            const Center(child: CircularProgressIndicator(color: Colors.red)),

          // 상단 검색바 및 길찾기 버튼
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // 검색 텍스트 필드
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '장소, 주소 검색하기',
                        // prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                // 길찾기 버튼
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.directions),
                    color: Colors.red,
                    onPressed: () {
                      // 길찾기 기능 구현
                      print('길찾기 버튼 클릭됨');
                    },
                  ),
                ),
              ],
            ),
          ),

          // 거리 표시
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 2, color: Colors.black54),
                  const SizedBox(width: 4),
                  const Text(
                    '100m',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // 현재 위치 버튼 (하단 우측)
          Positioned(
            bottom: 90,
            right: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location, size: 20),
                onPressed: _getCurrentLocation,
              ),
            ),
          ),

          // 하단 네비게이션 바
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.navigation, '메인'),
                  _buildNavItem(Icons.sentiment_satisfied_alt, ''),
                  _buildNavItem(Icons.add_circle, '', isCenter: true),
                  _buildNavItem(Icons.star_border, ''),
                  _buildNavItem(Icons.person_outline, ''),
                ],
              ),
            ),
          ),

          // 중앙 빨간색 버튼
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool isCenter = false}) {
    return isCenter
        ? SizedBox(width: 60)
        : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.black54),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        );
  }
}

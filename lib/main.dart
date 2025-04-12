import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'widgets/bottom_nav_bar.dart'; // 네비게이션바 임포트

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 경로
  await dotenv.load(fileName: '.env');
  print('환경변수 확인: ${dotenv.env['API_BASE_URL']}');
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_API_KEY'] ?? '',
    onAuthFailed: (error) {
      print('네이버 맵 인증 실패: $error');
    },
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 디버그 라벨 제거
      title: 'TOMAPTO',
      theme: ThemeData(
        primarySwatch: Colors.red, // 네비게이션바의 테마색상과 맞춤
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainPage(),
    );
  }
}

// 메인 페이지 생성 (네비게이션바를 관리할 부모 위젯)
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  // 각 탭에 해당하는 페이지 목록
  final List<Widget> _pages = [
    const NaverMapPage(), // 메인 페이지 (지도)
    const SearchPage(), // 검색 페이지
    const NavigatePage(), // 네비게이션 페이지
    const FavoritesPage(), // 즐겨찾기 페이지
    const ProfilePage(), // 프로필 페이지
  ];

  // 탭 변경 핸들러
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // 현재 선택된 페이지 표시
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// 기존 네이버 맵 페이지 (일부 수정)
class NaverMapPage extends StatefulWidget {
  const NaverMapPage({super.key});

  @override
  _NaverMapPageState createState() => _NaverMapPageState();
}

class _NaverMapPageState extends State<NaverMapPage> {
  NaverMapController? _mapController;
  NLatLng? _currentPosition;
  final Set<NMarker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // 위치 권한 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
      });

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
    }
  }

  void _updateMarkers() {
    if (_mapController != null && _currentPosition != null) {
      setState(() {
        // 새로운 마커 세트 생성
        _markers.clear();

        final marker = NMarker(id: '현재위치', position: _currentPosition!);

        _markers.add(marker);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TOMAPTO')),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target:
                    _currentPosition ??
                    NLatLng(37.5666805, 126.9784147), // 서울 시청 (기본값)
                zoom: 15,
              ),
              mapType: NMapType.basic,
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                _mapController!.updateCamera(
                  NCameraUpdate.withParams(target: _currentPosition, zoom: 15),
                );
                _updateMarkers();
              }
            },
            onMapTapped: (point, latLng) {
              print('지도가 탭되었습니다: $latLng');
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

// 추가 페이지들 (간단한 구현)
class SearchPage extends StatelessWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      body: const Center(child: Text('검색 페이지')),
    );
  }
}

class NavigatePage extends StatelessWidget {
  const NavigatePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('네비게이션')),
      body: const Center(child: Text('네비게이션 페이지')),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기')),
      body: const Center(child: Text('즐겨찾기 페이지')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: const Center(child: Text('프로필 페이지')),
    );
  }
}

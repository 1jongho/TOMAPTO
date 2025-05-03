// lib/pages/favorites/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/modal/login_services.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // 로그인 상태 확인
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    bool isLoggedIn = token != null;

    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });

    // 로그인되지 않은 경우 로그인 모달 표시 (딜레이 추가)
    if (!isLoggedIn && mounted) {
      // 화면 렌더링 후 모달 표시를 위한 딜레이
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          showLoginServicesModal(context, message: '메뉴는 로그인 후 이용 가능합니다');
        }
      });
    } else if (isLoggedIn) {
      // 로그인된 경우 메뉴뉴 데이터 가져오기
      _fetchFavorites();
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

  // 메뉴뉴 가져오기
  Future<void> _fetchFavorites() async {
    if (!_isLoggedIn) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // SharedPreferences에서 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
        return;
      }

      // API 호출 (API가 없을 경우 예시 데이터 사용)
      // 실제 구현 시에는 아래 주석 해제 후 사용
      /*
      final apiBaseUrl = _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/favorites/list'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _favorites = List<Map<String, dynamic>>.from(data['favorites']);
          _isLoading = false;
        });
      } else {
        print('메뉴 불러오기 실패: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
      */

      // 예시 데이터 사용 (실제 API 구현 시 삭제)
      await Future.delayed(Duration(seconds: 1)); // 로딩 효과를 위한 지연
      setState(() {
        _favorites = [
          {
            'id': '1',
            'name': '집',
            'address': '서울특별시 강남구 삼성동 123-45',
            'latitude': 37.5094,
            'longitude': 127.0669,
          },
          {
            'id': '2',
            'name': '회사',
            'address': '서울특별시 강남구 테헤란로 152',
            'latitude': 37.5033,
            'longitude': 127.0409,
          },
          {
            'id': '3',
            'name': '자주 가는 카페',
            'address': '서울특별시 강남구 역삼동 823-42',
            'latitude': 37.5006,
            'longitude': 127.0374,
          },
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('메뉴 불러오기 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int _currentNavIndex = 3; // 즐겨찾기 탭 인덱스

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '즐겨찾기',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB233B)),
                ),
              )
              : _isLoggedIn
              ? _buildFavoritesContent()
              : _buildLoginRequiredContent(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          // 네비게이션 처리
        },
      ),
    );
  }

  // 로그인한 경우 보여줄 즐겨찾기 콘텐츠
  Widget _buildFavoritesContent() {
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, color: Colors.grey[400], size: 70),
            SizedBox(height: 16),
            Text(
              '즐겨찾기가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '자주 가는 장소를 즐겨찾기에 추가해보세요',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: _favorites.length,
      separatorBuilder: (context, index) => Divider(height: 1),
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        return ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.location_on, color: Color(0xFFFB233B), size: 24),
          ),
          title: Text(
            favorite['name'],
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            favorite['address'],
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // 옵션 메뉴 표시
            },
          ),
        );
      },
    );
  }

  // 로그인하지 않은 경우 보여줄 콘텐츠
  Widget _buildLoginRequiredContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[400], size: 64),
          SizedBox(height: 16),
          Text(
            '로그인이 필요한 서비스입니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '메뉴 기능을 이용하려면 로그인이 필요합니다',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              showLoginServicesModal(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB233B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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

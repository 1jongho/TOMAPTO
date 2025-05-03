// Enhanced navbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tomapto/pages/friends/friends_list_screen.dart';
import 'package:tomapto/pages/map/naver_map.dart';
import 'package:tomapto/pages/profile/login.dart';
import 'package:tomapto/pages/profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/services/token_service.dart';
import 'package:tomapto/services/real_time_location_service.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // 로그인 상태 확인 메서드
  Future<bool> _checkIfUserIsLoggedIn(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // 토큰이 없으면 로그인되지 않은 상태
    if (token == null) {
      return false;
    }

    // 현재 세션에서 로그인한 경우 (is_logged_in이 true)
    if (isLoggedIn) {
      // 토큰 만료 여부만 확인
      try {
        if (TokenService.isTokenExpired(token)) {
          await _logout();
          return false;
        }
        return true; // 현재 세션에서 로그인 상태이고 토큰이 유효하면 로그인 상태
      } catch (e) {
        print('토큰 검증 오류: $e');
        return false;
      }
    }

    // 자동 로그인(remember_me)이 활성화된 경우
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (rememberMe) {
      // 토큰 만료 확인
      try {
        if (TokenService.isTokenExpired(token)) {
          await _logout();
          return false;
        }
        return true;
      } catch (e) {
        print('토큰 검증 오류: $e');
        return false;
      }
    }

    // 로그인 세션도 아니고 자동 로그인도 활성화되지 않은 경우
    return false;
  }

  // 로그아웃 메서드
  Future<void> _logout() async {
    // 실시간 위치 업데이트 서비스 중지
    try {
      final locationService = RealTimeLocationService();
      await locationService.stopLocationUpdates();
    } catch (e) {
      print('위치 업데이트 서비스 중지 오류: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('is_logged_in');
    // remember_me 설정은 유지
  }

  // 페이지 이동 처리 메서드
  Future<void> _handleNavTap(BuildContext context, int index) async {
    onTap(index);

    if (index == currentIndex) return;

    // 네비게이션 전에 로그인 상태 확인 (모든 페이지에 대해)
    bool isLoggedIn = await _checkIfUserIsLoggedIn(context);

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
        // 친구 페이지로 이동 전에 로그인 상태 확인
        if (isLoggedIn) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => FriendScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else {
          // 로그인되지 않은 경우 로그인 페이지로 이동
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => LoginPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
        break;
      case 2:
        // 메뉴 탭 - 로그인 확인 필요시 여기에 추가
        break;
      case 3:
        if (isLoggedIn) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => ProfilePage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => LoginPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double navBarHeight = 88.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 4; // 네 개의 아이템으로 균등하게 분할

    return Container(
      width: screenWidth,
      height: navBarHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(width: 0.6, color: Color(0xFFE2E2E2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context,
            0,
            '메인',
            'assets/icons/main_T.svg',
            'assets/icons/main_F.svg',
            itemWidth,
          ),
          _buildNavItem(
            context,
            1,
            '친구',
            'assets/icons/friend_T.svg',
            'assets/icons/friend_F.svg',
            itemWidth,
          ),
          _buildNavItem(
            context,
            2,
            '메뉴',
            'assets/icons/menu_T.svg',
            'assets/icons/menu_F.svg',
            itemWidth,
          ),
          _buildNavItem(
            context,
            3,
            '마이',
            'assets/icons/my_T.svg',
            'assets/icons/my_F.svg',
            itemWidth,
          ),
        ],
      ),
    );
  }

  // 각 네비게이션 아이템을 구성하는 메서드
  Widget _buildNavItem(
    BuildContext context,
    int index,
    String label,
    String selectedSvgPath,
    String unselectedSvgPath,
    double itemWidth,
  ) {
    final bool isSelected = currentIndex == index;

    // 전체 영역을 탭 가능하게 만들기 위해 InkWell 또는 GestureDetector를
    // Container를 감싸는 방식으로 변경
    return GestureDetector(
      onTap: () => _handleNavTap(context, index),
      // 탭 가능한 영역을 전체 Container로 확장
      behavior: HitTestBehavior.opaque, // 이 속성을 추가하여 투명한 부분도 탭 가능하게 함
      child: Container(
        width: itemWidth,
        height: 88,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(),
        child: Stack(
          children: [
            // 아이콘 위치
            Positioned(
              left: 32, // 요청하신 위치로 수정
              top: 20,
              child: Container(
                width: 26,
                height: 26,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(),
                child: Stack(
                  children: [
                    isSelected
                        ? SvgPicture.asset(
                          selectedSvgPath,
                          width: 26,
                          height: 26,
                        )
                        : SvgPicture.asset(
                          unselectedSvgPath,
                          width: 26,
                          height: 26,
                          color: const Color(0xFF9DB2CE),
                        ),
                  ],
                ),
              ),
            ),
            // 텍스트 (선택된 경우만 표시)
            if (isSelected)
              Positioned(
                left: 36, // 요청하신 위치로 수정
                top: 48,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF1E1E1E),
                    fontSize: 12,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

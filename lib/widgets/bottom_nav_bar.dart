import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tomapto/pages/friends/friends_list_screen.dart'; // 친구 페이지 임포트
import 'package:tomapto/pages/favorites/favorites_screen.dart'; // 즐겨찾기 페이지 임포트
import 'package:tomapto/pages/map/naver_map.dart';
import 'package:tomapto/pages/profile/login.dart'; // 로그인 페이지 임포트
import 'package:tomapto/pages/profile/profile.dart'; // 프로필 페이지 임포트
import 'package:shared_preferences/shared_preferences.dart'; // 로그인 상태 확인용
import 'package:tomapto/services/token_service.dart'; // 토큰 서비스 추가

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final double curveHeight; // 곡선의 높이를 조절하는 속성

  const BottomNavBar({
    super.key,
    required this.currentIndex, // 현재 선택된 탭 인덱스
    required this.onTap, // 탭 선택 시 호출될 콜백 함수
    this.curveHeight = 30.0, // 기본 커브 높이 (더 크게 설정할수록 더 볼록해집니다)
  });

  // 로그인 상태 확인 메서드 (토큰 유효성 검증 포함)
  Future<bool> _checkIfUserIsLoggedIn(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    // 토큰이 없거나 자동 로그인이 활성화되지 않은 경우
    if (token == null || !rememberMe) {
      return false;
    }

    // 토큰 유효성 확인 (만료 여부 검사)
    try {
      if (TokenService.isTokenExpired(token)) {
        // 토큰이 만료된 경우, 로그아웃 처리
        await _logout();
        return false;
      }
      return true;
    } catch (e) {
      print('토큰 검증 오류: $e');
      return false;
    }
  }

  // 로그아웃 메서드
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('remember_me');
  }

  // 페이지 이동 처리 메서드
  Future<void> _handleNavTap(BuildContext context, int index) async {
    // 탭 상태 업데이트를 위해 콜백 호출
    onTap(index);

    // 현재 인덱스와 같으면 아무것도 하지 않음 (이미 같은 페이지에 있음)
    if (index == currentIndex) return;

    // 페이지 이동 로직
    switch (index) {
      case 0:
        // 메인 페이지로 이동
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => NaverMapPage(),
            transitionDuration: Duration.zero, // 애니메이션 시간을 0으로 설정
            reverseTransitionDuration: Duration.zero, // 뒤로가기 애니메이션도 0으로 설정
          ),
          (route) => false,
        );
        break;
      case 1:
        // 친구 페이지로 이동
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => FriendScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case 2:
        // 중앙 버튼 - 카테고리
        // 현재는 메인 페이지의 특정 기능만 활성화 (페이지 이동 없음)
        break;
      case 3:
        // 즐겨찾기 페이지로 이동
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    FriendScreen(), //FavoritesScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case 4:
        // 프로필 탭 - 로그인 상태에 따라 다른 페이지로 이동
        bool isLoggedIn = await _checkIfUserIsLoggedIn(context);
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
          // 로그인이 안 된 상태이거나 토큰이 만료된 경우 로그인 페이지로 이동
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
    // 표준 Flutter 하단 네비게이션 바 높이
    const double kBottomNavigationBarHeight = 80.0;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth,
      height: kBottomNavigationBarHeight,
      child: Stack(
        clipBehavior: Clip.none, // 자식 위젯이 부모 경계를 넘어갈 수 있도록 설정
        children: [
          // 기본 네비게이션 바 배경 (전체 너비)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: kBottomNavigationBarHeight,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                // 상단에 0.2 두께의 구분선 추가
                border: Border(
                  top: BorderSide(
                    width: 0.2,
                    color: Color(0xFFCCCCCC), // 연한 회색 구분선
                  ),
                ),
              ),
              width: screenWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    context,
                    0,
                    '메인',
                    'assets/icons/main_B.svg',
                    'assets/icons/main_W.svg',
                  ),
                  _buildNavItem(
                    context,
                    1,
                    '친구',
                    'assets/icons/friend_B.svg',
                    'assets/icons/friend_W.svg',
                  ),
                  // 중앙 버튼을 위한 공간 - 고정 너비 사용
                  Container(width: 60, height: 50),
                  _buildNavItem(
                    context,
                    3,
                    '저장',
                    'assets/icons/favorites_B.svg',
                    'assets/icons/favorites_W.svg',
                  ),
                  _buildNavItem(
                    context,
                    4,
                    '마이',
                    'assets/icons/user_B.svg',
                    'assets/icons/user_W.svg',
                  ),
                ],
              ),
            ),
          ),

          // 중앙 볼록 부분 (하단 바 위에 추가) - 곡선 개선 및 크기 조정
          Positioned(
            bottom: kBottomNavigationBarHeight - 1,
            left: screenWidth / 2 - 70, // 좌측 위치 더 넓게 조정 (60 -> 70)
            child: ClipPath(
              // CenterCurveClipper에 적절한 값을 전달하여 커브 모양 조절
              clipper: CenterCurveClipper(
                iconRadius: 30, // 아이콘 반지름
                curveBulge: 0.5, // 볼록한 정도 (0.5~1.0 사이 권장, 값이 클수록 더 볼록함)
                curveWidth: 120, // 곡선의 너비 (더 넓게 설정)
              ),
              child: Container(
                width: 140, // 너비 더 넓게 조정 (120 -> 140)
                height: curveHeight * 1.6, // 높이 조정 (1.2 -> 1.5로 증가)
                decoration: BoxDecoration(
                  color: Colors.white,
                  // 상단 경계에 0.2의 구분선 추가 (중앙 볼록 부분에도 동일한 구분선 적용)
                  border: const Border(
                    top: BorderSide(
                      width: 0.2,
                      color: Color(0xFFCCCCCC), // 연한 회색 구분선
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      spreadRadius: 1,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 중앙 둥근 버튼 (Stack의 맨 마지막에 배치하여 항상 최상위에 표시)
          Positioned(
            bottom: kBottomNavigationBarHeight - 45, // 위치 조정
            left: screenWidth / 2 - 30, // 중앙 위치
            child: GestureDetector(
              onTap: () {
                onTap(2);
                _handleNavTap(context, 2);
              },
              child: Container(
                width: 60, // 버튼 크기
                height: 60, // 버튼 크기
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFB233B),
                      const Color(0xFFFB233B).withOpacity(0.7),
                    ],
                    stops: const [0.7, 1.0],
                    radius: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFB233B).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/category_Bf.svg',
                    width: 21, // 아이콘 크기
                    height: 21, // 아이콘 크기
                    color: Colors.white,
                  ),
                ),
              ),
            ),
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
  ) {
    // 현재 선택된 아이템인지 확인
    final bool isSelected = currentIndex == index;

    // 모든 아이템에 고정된 높이와 너비를 부여하여 움직임 방지
    return GestureDetector(
      onTap: () => _handleNavTap(context, index),
      child: Container(
        width: 60, // 모든 아이템에 동일한 너비
        height: 50, // 모든 아이템에 동일한 높이
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              isSelected ? selectedSvgPath : unselectedSvgPath,
              width: 24,
              height: 24,
            ),
            const SizedBox(height: 2),
            // 선택 여부와 관계없이 항상 Text 위젯 표시 (선택되지 않았을 때는 투명하게)
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.transparent,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 종형 곡선 모양의 클리퍼 구현 - 더 볼록하게 수정
class CenterCurveClipper extends CustomClipper<Path> {
  // 커스터마이징 가능한 속성들
  final double iconRadius; // 중앙 아이콘의 반지름
  final double curveBulge; // 곡선의 볼록한 정도 (0.5~1.0 권장, 값이 클수록 더 볼록함)
  final double curveWidth; // 곡선의 너비

  // 생성자: 클리퍼의 속성을 설정할 수 있습니다
  CenterCurveClipper({
    this.iconRadius = 25.0, // 기본 아이콘 반지름
    this.curveBulge = 0.8, // 기본 볼록함 정도
    this.curveWidth = 80.0, // 기본 곡선 너비
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    // 볼록한 정도에 따라 조절되는 높이 계수
    final heightFactor = height * (1.0 - curveBulge);

    // 좌측 하단에서 시작
    path.moveTo(0, height);

    // 왼쪽 하단 직선 부분
    path.lineTo(width * 0.05, height);

    // 왼쪽에서 중앙으로 올라가는 곡선 (더 볼록하게 조정)
    path.cubicTo(
      width * 0.10, // 첫 번째 제어점 X 좌표
      height, // 첫 번째 제어점 Y 좌표
      width * 0.15, // 두 번째 제어점 X 좌표
      heightFactor * 0.9, // 두 번째 제어점 Y 좌표 (낮을수록 더 볼록해짐)
      width * 0.30, // 끝점 X 좌표
      heightFactor * 0.7, // 끝점 Y 좌표 (낮을수록 더 볼록해짐)
    );

    // 중앙 상단 부분 (더 볼록하게 조정)
    path.cubicTo(
      width * 0.38, // 첫 번째 제어점 X 좌표
      heightFactor * 0.3, // 첫 번째 제어점 Y 좌표 (낮을수록 더 볼록해짐)
      width * 0.62, // 두 번째 제어점 X 좌표
      heightFactor * 0.3, // 두 번째 제어점 Y 좌표 (낮을수록 더 볼록해짐)
      width * 0.70, // 끝점 X 좌표
      heightFactor * 0.7, // 끝점 Y 좌표 (낮을수록 더 볼록해짐)
    );

    // 중앙에서 오른쪽으로 내려가는 곡선
    path.cubicTo(
      width * 0.85, // 첫 번째 제어점 X 좌표
      heightFactor * 0.9, // 첫 번째 제어점 Y 좌표 (낮을수록 더 볼록해짐)
      width * 0.90, // 두 번째 제어점 X 좌표
      height, // 두 번째 제어점 Y 좌표
      width * 0.95, // 끝점 X 좌표
      height, // 끝점 Y 좌표
    );

    // 오른쪽 하단 직선 부분
    path.lineTo(width, height);

    // 경로 닫기
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

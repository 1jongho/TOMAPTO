import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapto/services/api_service.dart';
import 'package:tomapto/services/token_service.dart'; // 토큰 서비스 추가

class ProfileController {
  // 사용자 데이터 상태
  String userName = '이름'; // 기본값
  String userNickname = '';
  String userEmail = '';
  int userLevel = 1;
  int userExp = 0; // 경험치 초기값 0으로 설정
  bool isLoading = true;
  String errorMessage = '';

  // 사용자 데이터 로드
  Future<void> loadUserData(BuildContext context, Function setState) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    // 토큰 유효성 검사 추가
    bool isTokenValid = await TokenService.validateToken(context);
    if (!isTokenValid) {
      // 토큰이 유효하지 않으면 여기서 함수 종료
      // TokenService에서 이미 로그인 페이지로 리디렉션 처리함
      return;
    }

    try {
      // API를 통해 프로필 정보 조회
      final response = await ApiService.getProfile();

      if (response['success'] == true) {
        final userData = response['data'];

        setState(() {
          userName = userData['user_name'] ?? '이름';
          userNickname = userData['user_nickname'] ?? '';
          userEmail = userData['user_email'] ?? '';
          userLevel = userData['user_level'] ?? 1;

          // 경험치 값을 정수로 변환해서 저장
          userExp = int.tryParse(userData['user_exp']?.toString() ?? '0') ?? 0;
          isLoading = false;
        });

        print(
          '프로필 데이터 로드 성공: $userName, Lv.$userLevel, 경험치: $userExp (${(userExp ~/ 10)}%),',
        );
      } else {
        setState(() {
          errorMessage = response['message'] ?? '프로필 정보를 불러오는데 실패했습니다.';
          isLoading = false;
        });
      }
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      setState(() {
        errorMessage = '프로필 정보를 불러오는데 실패했습니다. 다시 시도해주세요.';
        isLoading = false;
      });

      // 오류 발생 시 로컬 저장소에서 기본 정보 로드
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? '';

        setState(() {
          userName = userId.isNotEmpty ? userId : '이름';
        });
      } catch (e) {
        print('로컬 저장소 접근 오류: $e');
      }
    }
  }

  // 프로필 새로고침
  Future<void> refreshProfile(BuildContext context, Function setState) async {
    await loadUserData(context, setState);
  }

  // 로그아웃 처리
  Future<bool> logout(BuildContext context) async {
    try {
      setState() => isLoading = true;

      // API를 통해 로그아웃 요청
      final response = await ApiService.logout();

      if (response['success'] == true) {
        // 로그아웃 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? '로그아웃 되었습니다.')),
        );

        // 로그인 페이지로 이동
        return true;
      } else {
        // 로그아웃 실패 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? '로그아웃 처리 중 오류가 발생했습니다.'),
          ),
        );
        return false;
      }
    } catch (e) {
      print('로그아웃 처리 오류: $e');

      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 처리 중 오류가 발생했습니다. 다시 시도해주세요.')),
      );
      return false;
    } finally {
      setState() => isLoading = false;
    }
  }

  // 메뉴 네비게이션 처리
  void navigateToCalendar(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('캘린더 페이지로 이동합니다')));
    // 실제 구현 시 아래와 같이 페이지 이동
    // Navigator.of(context).pushNamed('/calendar');
  }

  void navigateToNotices(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('공지사항 페이지로 이동합니다')));
    // 실제 구현 시 아래와 같이 페이지 이동
    // Navigator.of(context).pushNamed('/notices');
  }

  void navigateToSupport(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('고객센터 페이지로 이동합니다')));
    // 실제 구현 시 아래와 같이 페이지 이동
    // Navigator.of(context).pushNamed('/support');
  }
}

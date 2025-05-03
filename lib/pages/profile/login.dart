import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/controllers/account/login_controller.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'package:tomapto/pages/profile/profile.dart';
import 'package:tomapto/pages/profile/signup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 바인딩 초기화 (비동기 작업 전 필요)
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOMAPTO 로그인',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Pretendard',
      ),
      home: const LoginPage(), // 로그인 페이지를 홈 화면으로 설정
    );
  }
}

// 커스텀 텍스트 필드 위젯
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String labelText;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.labelText,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            color: const Color(0xFF9DB2CE),
            fontSize: 14.0 * MediaQuery.of(context).textScaleFactor,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
          ),
        ),
        const SizedBox(height: 0.1),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            fontSize: 18.0 * MediaQuery.of(context).textScaleFactor,
          ),
          decoration: InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color:
                    focusNode?.hasFocus == true
                        ? const Color(0xFFFB233B) // 앱의 주요 색상 (빨간색)
                        : const Color(0xFF9DB2CE), // 텍스트 보조 색상
              ),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF9DB2CE)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFB233B)),
            ),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }
}

// 기본 버튼 위젯
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final double height = 50.0 * (MediaQuery.of(context).size.height / 812);
    final double radius = 25.0 * (MediaQuery.of(context).size.width / 375);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        minimumSize: Size(MediaQuery.of(context).size.width, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 17.0 * MediaQuery.of(context).textScaleFactor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 컨트롤러 인스턴스 생성
  final LoginController _controller = LoginController();

  @override
  void initState() {
    super.initState();
    // 포커스 노드에 리스너 추가
    _controller.idFocusNode.addListener(() {
      setState(() {});
    });
    _controller.passwordFocusNode.addListener(() {
      setState(() {});
    });

    // 로그인 상태 확인 및 자동 로그인 처리
    _checkLoginStatus();
  }

  // 로그인 상태 확인 메소드
  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _controller.checkLoginStatus();

    if (isLoggedIn && mounted) {
      // 여기서 홈 화면으로 이동 (실제 구현 필요)
      // Navigator.of(context).pushReplacement(
      //   MaterialPageRoute(builder: (context) => HomePage()),
      // );
    }
  }

  @override
  void dispose() {
    // 컨트롤러 리소스 해제
    _controller.dispose();
    super.dispose();
  }

  // 비밀번호 찾기 네비게이션
  void _navigateToPasswordReset() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호 찾기 페이지로 이동합니다')));
  }

  // 회원가입 네비게이션
  void _navigateToSignUp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => SignUpPage()));
  }

  // 로그인 처리
  // login.dart 파일의 _LoginPageState 클래스 내부

  // 로그인 처리
  // login.dart 파일의 _login() 함수 수정
  // 로그인 처리
  Future<void> _login() async {
    // 키보드 숨기기
    FocusScope.of(context).unfocus();

    // _controller.login() 함수에 rememberMe 값을 전달
    final success = await _controller.login(context, setState);
    if (success && mounted) {
      // 로그인 성공 시 프로필 페이지로 이동
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  // 배경 영역을 터치했을 때 포커스 해제
  void _unfocusAll() {
    _controller.idFocusNode.unfocus();
    _controller.passwordFocusNode.unfocus();
  }

  // 로고 위젯 생성 메서드
  Widget _buildLogo(BuildContext context) {
    final double height = 45.0 * (MediaQuery.of(context).size.height / 812);
    final double verticalPadding =
        20.0 * (MediaQuery.of(context).size.height / 812);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: SvgPicture.asset('assets/icons/tomaptologo.svg', height: height),
    );
  }

  Widget _buildIdField() {
    return CustomTextField(
      controller: _controller.idController,
      focusNode: _controller.idFocusNode,
      labelText: '아이디',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '아이디를 입력해주세요';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return CustomTextField(
      controller: _controller.passwordController,
      focusNode: _controller.passwordFocusNode,
      labelText: '비밀번호',
      obscureText: _controller.obscureText,
      suffixIcon: IconButton(
        icon: Icon(
          _controller.obscureText ? Icons.visibility_off : Icons.visibility,
          color: const Color(0xFF363636),
          size: 20.0 * (MediaQuery.of(context).size.width / 375),
        ),
        onPressed: () {
          _controller.togglePasswordVisibility(setState);
        },
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '비밀번호를 입력해주세요';
        }
        return null;
      },
    );
  }

  Widget _buildRememberMeAndPasswordReset(BuildContext context) {
    final double circleSize = 18.0 * (MediaQuery.of(context).size.width / 390);
    final double spaceBetween = 8.0 * (MediaQuery.of(context).size.width / 375);
    final double underlineWidth =
        65.0 * (MediaQuery.of(context).size.width / 375);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 로그인 유지
        GestureDetector(
          onTap: () {
            _controller.toggleRememberMe(setState);
          },
          child: Row(
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _controller.rememberMe
                          ? const Color(0xFFFB233B)
                          : Color.fromARGB(255, 203, 211, 221),
                ),
              ),
              SizedBox(width: spaceBetween),
              Text(
                '로그인 유지',
                style: TextStyle(
                  color: Color(0xFF9DB2CE),
                  fontSize: 14.0 * MediaQuery.of(context).textScaleFactor,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // 비밀번호 찾기
        GestureDetector(
          onTap: _navigateToPasswordReset,
          child: Column(
            children: [
              Text(
                '비밀번호 찾기',
                style: TextStyle(
                  color: const Color(0xFF9DB2CE),
                  fontSize: 14.0 * MediaQuery.of(context).textScaleFactor,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                height: 1,
                width: underlineWidth,
                color: const Color(0xFF9DB2CE),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 사이즈 계산
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final double topSpace = 80.0 * (screenHeight / 812);
    final double logoToFormSpace = 60.0 * (screenHeight / 812);
    final double fieldSpacing = 20.0 * (screenHeight / 812);
    final double smallSpacing = 15.0 * (screenHeight / 812);
    final double buttonSpacing = 35.0 * (screenHeight / 812);
    final double bottomSpace = 20.0 * (screenHeight / 812);
    final double horizontalPadding = 35.0 * (screenWidth / 375);

    return GestureDetector(
      onTap: _unfocusAll, // 배경을 터치하면 모든 포커스 해제
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 메인 콘텐츠
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Form(
                        key: _controller.formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(height: topSpace),

                            // 로고
                            _buildLogo(context),

                            SizedBox(height: logoToFormSpace),

                            // 에러 메시지 표시
                            if (_controller.errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                width: double.infinity,
                                child: Text(
                                  _controller.errorMessage,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize:
                                        14.0 *
                                        MediaQuery.of(context).textScaleFactor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // 아이디 입력 필드
                            _buildIdField(),

                            SizedBox(height: fieldSpacing),

                            // 비밀번호 입력 필드
                            _buildPasswordField(),

                            SizedBox(height: smallSpacing),

                            // 로그인 유지 및 비밀번호 찾기
                            _buildRememberMeAndPasswordReset(context),

                            SizedBox(height: buttonSpacing),

                            // 로그인 버튼
                            PrimaryButton(
                              text: '로그인',
                              onPressed: _login,
                              backgroundColor: const Color(0xFFFB233B),
                            ),

                            SizedBox(height: smallSpacing),

                            // 회원가입 버튼
                            PrimaryButton(
                              text: '회원가입',
                              onPressed: _navigateToSignUp,
                              backgroundColor: Colors.black,
                            ),

                            SizedBox(height: bottomSpace),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 화면 하단에 고정된 내비게이션 바
            Positioned(
              left: 0,
              right: 0,
              bottom: 0, // 화면 최하단에 배치
              child: BottomNavBar(
                currentIndex: 3,
                onTap: (index) {
                  FocusScope.of(context).unfocus();
                },
              ),
            ),

            // 로딩 상태일 때 블러 처리된 오버레이
            if (_controller.isLoading)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFB233B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

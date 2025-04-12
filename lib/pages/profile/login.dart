import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/controllers/login_controller.dart';
import 'package:tomapto/widgets/bottom_nav_bar.dart';
import 'package:tomapto/styles/app_styles.dart';

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
        Text(labelText, style: AppTextStyles.caption(context)),
        SizedBox(height: ResponsiveValue.height(context, base: 2)),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            fontSize: ResponsiveValue.fontSize(context, base: 16),
          ),
          decoration: InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color:
                    focusNode?.hasFocus == true
                        ? AppColors.primary
                        : AppColors.textSecondary,
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.textSecondary),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            suffixIcon: suffixIcon,
            contentPadding: EdgeInsets.symmetric(vertical: 10), // 패딩 조절
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
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        minimumSize: Size(
          MediaQuery.of(context).size.width,
          ResponsiveValue.height(context, base: 50),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveValue.width(context, base: 25),
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: ResponsiveValue.fontSize(context, base: 16),
          fontWeight: FontWeight.bold,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('회원가입 페이지로 이동합니다')));
    // 실제 회원가입 페이지로 이동 (구현 필요)
    // Navigator.of(context).push(
    //   MaterialPageRoute(builder: (context) => SignUpPage()),
    // );
  }

  // 로그인 처리
  Future<void> _login() async {
    final success = await _controller.login(context, setState);
    if (success && mounted) {
      // 홈 화면으로 이동 (실제 구현 필요)
      // Navigator.of(context).pushReplacement(
      //   MaterialPageRoute(builder: (context) => HomePage()),
      // );
    }
  }

  // 배경 영역을 터치했을 때 포커스 해제
  void _unfocusAll() {
    _controller.idFocusNode.unfocus();
    _controller.passwordFocusNode.unfocus();
  }

  // 로고 위젯 생성 메서드
  Widget _buildLogo(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveValue.height(context, base: 10),
      ),
      child: SvgPicture.asset(
        'assets/icons/tomaptologo.svg',
        height: ResponsiveValue.height(context, base: 40),
      ),
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
          color: AppColors.textSecondary,
          size: ResponsiveValue.width(context, base: 20),
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
                width: ResponsiveValue.width(context, base: 20),
                height: ResponsiveValue.width(context, base: 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!),
                  color:
                      _controller.rememberMe
                          ? AppColors.primary
                          : Colors.transparent,
                ),
              ),
              SizedBox(width: ResponsiveValue.width(context, base: 5)),
              Text(
                '로그인 유지',
                style: AppTextStyles.caption(
                  context,
                ).copyWith(color: Colors.grey[600]),
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
                style: AppTextStyles.caption(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
              Container(
                height: 1,
                width: ResponsiveValue.width(context, base: 65),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        horizontal: ResponsiveValue.padding(context, base: 35),
                      ),
                      child: Form(
                        key: _controller.formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: ResponsiveValue.height(context, base: 80),
                            ),

                            // 로고 - 올바른 메서드 호출로 수정
                            _buildLogo(context),

                            SizedBox(
                              height: ResponsiveValue.height(context, base: 60),
                            ),

                            // 에러 메시지 표시
                            if (_controller.errorMessage.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                width: double.infinity,
                                child: Text(
                                  _controller.errorMessage,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: ResponsiveValue.fontSize(
                                      context,
                                      base: 14,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // 아이디 입력 필드
                            _buildIdField(),

                            SizedBox(
                              height: ResponsiveValue.height(context, base: 20),
                            ),

                            // 비밀번호 입력 필드
                            _buildPasswordField(),

                            SizedBox(
                              height: ResponsiveValue.height(context, base: 15),
                            ),

                            // 로그인 유지 및 비밀번호 찾기
                            _buildRememberMeAndPasswordReset(context),

                            SizedBox(
                              height: ResponsiveValue.height(context, base: 35),
                            ),

                            // 로그인 버튼
                            PrimaryButton(
                              text: '로그인',
                              onPressed: _login,
                              backgroundColor: AppColors.primary,
                            ),

                            SizedBox(
                              height: ResponsiveValue.height(context, base: 15),
                            ),

                            // 회원가입 버튼
                            PrimaryButton(
                              text: '회원가입',
                              onPressed: _navigateToSignUp,
                              backgroundColor: Colors.black,
                            ),

                            SizedBox(
                              height: ResponsiveValue.height(context, base: 20),
                            ),
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
              bottom: -30, // 화면 최하단에 배치
              child: BottomNavBar(
                currentIndex: 4,
                onTap: (index) {
                  // 탭 클릭 시 실행할 함수
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
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
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

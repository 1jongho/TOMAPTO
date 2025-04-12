import 'package:flutter/material.dart';
import 'dart:ui';
import '../../main.dart'; // AuthManager 클래스를 사용하기 위해 import

class LoginPage extends StatefulWidget {
  final Function? onLoginSuccess;

  const LoginPage({Key? key, this.onLoginSuccess}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _rememberMe = false;
  bool _obscureText = true;
  bool _isLoading = false; // 로딩 상태 추적

  @override
  void initState() {
    super.initState();
    // 포커스 노드에 리스너 추가
    _idFocusNode.addListener(() {
      setState(() {});
    });
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // 컨트롤러와 포커스 노드 해제
    _idController.dispose();
    _passwordController.dispose();
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      // 로딩 상태 시작
      setState(() {
        _isLoading = true;
      });

      try {
        // 여기에 기존 백엔드 연결 코드를 사용합니다

        // 로그인 성공 시 상태 업데이트
        AuthManager.isLoggedIn = true;

        // 로딩 상태 종료
        setState(() {
          _isLoading = false;
        });

        // 로그인 성공 스낵바
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 성공!')));

        // 로그인 성공 콜백이 있으면 호출
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        // 에러 처리
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
      }
    }
  }

  void _navigateToPasswordReset() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호 찾기 페이지로 이동합니다')));
  }

  void _navigateToSignUp() {
    Navigator.pushNamed(context, '/signup');
  }

  // 배경 영역을 터치했을 때 포커스 해제
  void _unfocusAll() {
    _idFocusNode.unfocus();
    _passwordFocusNode.unfocus();
  }

  Widget _buildLogo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('T', style: AppTextStyles.logoTitle(context)),
        Container(
          width: ResponsiveValue.width(context, base: 25),
          height: ResponsiveValue.width(context, base: 25),
          decoration: BoxDecoration(
            color: AppColors.accent2,
            shape: BoxShape.circle,
          ),
        ),
        Text('MAPTO', style: AppTextStyles.logoTitle(context)),
      ],
    );
  }

  Widget _buildIdField() {
    return CustomTextField(
      controller: _idController,
      focusNode: _idFocusNode,
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
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      labelText: '비밀번호',
      obscureText: _obscureText,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textSecondary,
          size: ResponsiveValue.width(context, base: 20),
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
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
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: Row(
            children: [
              Container(
                width: ResponsiveValue.width(context, base: 20),
                height: ResponsiveValue.width(context, base: 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!),
                  color: _rememberMe ? AppColors.primary : Colors.transparent,
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
        appBar: AppBar(
          title: const Text('로그인'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
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
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: ResponsiveValue.height(context, base: 40),
                            ),

                            // 로고
                            _buildLogo(context),

                            SizedBox(
                              height: ResponsiveValue.height(context, base: 60),
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

            // 로딩 상태일 때 블러 처리된 오버레이
            if (_isLoading)
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

// 앱 색상 상수
class AppColors {
  static const Color primary = Color(0xFFFB233B);
  static const Color accent = Color(0xFFFB233B);
  static const Color accent2 = Color(0xFF02A76A);
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF9DB2CE);
}

// 반응형 크기 계산 유틸리티
class ResponsiveValue {
  static double width(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375.0); // 기준 디자인 너비
  }

  static double height(BuildContext context, {required double base}) {
    final screenHeight = MediaQuery.of(context).size.height;
    return base * (screenHeight / 812.0); // 기준 디자인 높이
  }

  static double fontSize(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375.0);
  }

  static double padding(BuildContext context, {required double base}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return base * (screenWidth / 375.0);
  }
}

// 앱 텍스트 스타일 상수
class AppTextStyles {
  static TextStyle logoTitle(BuildContext context) => TextStyle(
    color: AppColors.textPrimary,
    fontSize: ResponsiveValue.fontSize(context, base: 28),
    fontWeight: FontWeight.bold,
  );

  static TextStyle caption(BuildContext context) => TextStyle(
    fontSize: ResponsiveValue.fontSize(context, base: 12),
    color: AppColors.textSecondary,
  );
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
            contentPadding: const EdgeInsets.symmetric(vertical: 10), // 패딩 조절
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

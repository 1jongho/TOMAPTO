import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/controllers/signup_controller.dart';

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
      title: '회원가입',
      theme: ThemeData(
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SignUpPage(),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final GlobalKey _emailFieldKey = GlobalKey();

  // 커스텀 드롭다운을 위한 변수
  bool _isDropdownOpen = false;
  OverlayEntry? _dropdownOverlay;

  // 텍스트 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // 포커스 노드
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _nicknameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  // 컨트롤러 초기화
  late SignController _signController;

  // 드롭다운 오버레이 표시 메서드
  void _showDropdownOverlay(BuildContext context, GlobalKey emailFieldKey) {
    // 기존 오버레이 제거
    _removeDropdownOverlay();

    // 현재 위젯의 위치 구하기
    final RenderBox renderBox =
        emailFieldKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _dropdownOverlay = OverlayEntry(
      builder:
          (context) => Positioned(
            left: offset.dx + renderBox.size.width - 150, // 오른쪽에서 150px 위치
            top: offset.dy + renderBox.size.height + 5, // 아래로 5px 간격
            child: Material(
              //elevation: 4.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 120,
                height: 110,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 120,
                        height: 110,
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: Offset(0, 1),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ..._signController.domains.asMap().entries.map((entry) {
                      int index = entry.key;
                      String domain = entry.value;
                      return Positioned(
                        left: 12,
                        top: index * 28 + 2, // 각 항목간 21px 간격
                        child: GestureDetector(
                          onTap: () {
                            _signController.updateDomain(domain);
                            _removeDropdownOverlay();
                          },
                          child: Text(
                            domain,
                            style: TextStyle(
                              color: const Color(0xFF363636),
                              fontSize: 13,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w400,
                              height: 1.83,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_dropdownOverlay!);
    setState(() {
      _isDropdownOpen = true;
    });
  }

  // 드롭다운 오버레이 제거 메서드
  void _removeDropdownOverlay() {
    if (_dropdownOverlay != null) {
      _dropdownOverlay!.remove();
      _dropdownOverlay = null;
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // 컨트롤러 초기화
    _signController = SignController(
      nameController: _nameController,
      idController: _idController,
      nicknameController: _nicknameController,
      passwordController: _passwordController,
      confirmPasswordController: _confirmPasswordController,
      emailController: _emailController,
      idFocusNode: _idFocusNode,
      nicknameFocusNode: _nicknameFocusNode,
      emailFocusNode: _emailFocusNode,
      passwordFocusNode: _passwordFocusNode,
      confirmPasswordFocusNode: _confirmPasswordFocusNode,
      scrollController: _scrollController,
      context: context,
      updateUI: setState,
    );

    // 포커스 리스너 추가
    _idFocusNode.addListener(_signController.onIdFocusChange);
    _nicknameFocusNode.addListener(_signController.onNicknameFocusChange);
    _emailFocusNode.addListener(_signController.onEmailFocusChange);

    // 텍스트 컨트롤러 리스너 추가
    _idController.addListener(_signController.onIdChanged);
    _nicknameController.addListener(_signController.onNicknameChanged);
    _emailController.addListener(_signController.onEmailChanged);

    // 스크롤 리스너 추가
    _scrollController.addListener(_signController.onScroll);
  }

  @override
  void dispose() {
    // 드롭다운 오버레이 제거
    _removeDropdownOverlay();

    // 컨트롤러 해제
    _nameController.dispose();
    _idController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();

    // 포커스 노드 해제
    _idFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    // 스크롤 컨트롤러 해제
    _scrollController.removeListener(_signController.onScroll);
    _scrollController.dispose();

    // 컨트롤러 정리
    _signController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 배경 터치 시 드롭다운 닫기 및 포커스 해제
        _removeDropdownOverlay();
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          scrolledUnderElevation: 0,
          title: Text(
            '회원가입',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 16.0,
              color: const Color(0xFF363636),
            ),
          ),
          leading: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/back.svg',
              width: 24,
              height: 24,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 이름 입력 필드
                  buildInputField(
                    controller: _nameController,
                    labelText: '이름',
                    hintText: '이름을 적어주세요.',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '';
                      }
                      return null;
                    },
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),

                  // 아이디 입력 필드
                  buildInputField(
                    controller: _idController,
                    labelText: '아이디',
                    hintText: '아이디를 적어주세요.',
                    focusNode: _idFocusNode,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '';
                      }
                      return null;
                    },
                    isRequired: true,
                    hasError: _signController.isIdDuplicate,
                    suffixIcon:
                        _idController.text.isNotEmpty
                            ? _buildStatusIcon(_signController.isIdDuplicate)
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // 닉네임 입력 필드
                  buildInputField(
                    controller: _nicknameController,
                    labelText: '닉네임',
                    hintText: '닉네임을 적어주세요.',
                    focusNode: _nicknameFocusNode,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '';
                      }
                      return null;
                    },
                    isRequired: true,
                    hasError: _signController.isNicknameDuplicate,
                    suffixIcon:
                        _nicknameController.text.isNotEmpty
                            ? _buildStatusIcon(
                              _signController.isNicknameDuplicate,
                            )
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 필드
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 비밀번호 라벨
                      RichText(
                        text: TextSpan(
                          text: '비밀번호',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: Color(0xFF363636),
                            fontWeight: FontWeight.w500,
                            fontSize: 16.0,
                          ),
                          children: const [
                            TextSpan(
                              text: '*',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFFFB233B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 비밀번호 입력 필드
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        focusNode: _passwordFocusNode,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16.0,
                        ),
                        decoration: InputDecoration(
                          hintText: '비밀번호를 적어주세요.',
                          hintStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16.0,
                            color: Colors.grey,
                          ),
                          suffixIcon: const Icon(
                            Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          // 테두리 스타일
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.blue,
                              width: 1.0,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Color(0xFFFB233B),
                              width: 1.0,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Color(0xFFFB233B),
                              width: 1.0,
                            ),
                          ),
                          errorStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12.0,
                            color: Color(0xFFFB233B),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '';
                          }
                          if (value.length < 8) {
                            _signController.showTooltip(
                              _passwordFocusNode,
                              'password',
                            );
                            return '';
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 5, top: 1),
                        child: Text(
                          '문자와 숫자가 포함된 8자리 이상의 조합으로 설정해주세요.',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: Colors.grey,
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 확인 필드
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 비밀번호 확인 라벨
                      RichText(
                        text: TextSpan(
                          text: '비밀번호 확인',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: Color(0xFF363636),
                            fontWeight: FontWeight.w500,
                            fontSize: 16.0,
                          ),
                          children: const [
                            TextSpan(
                              text: '*',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFFFB233B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 비밀번호 확인 입력 필드
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        focusNode: _confirmPasswordFocusNode,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16.0,
                        ),
                        decoration: InputDecoration(
                          hintText: '비밀번호를 적어주세요.',
                          hintStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16.0,
                            color: Colors.grey,
                          ),
                          suffixIcon: const Icon(
                            Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          // 테두리 스타일
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.blue,
                              width: 1.0,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Color(0xFFFB233B),
                              width: 1.0,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Color(0xFFFB233B),
                              width: 1.0,
                            ),
                          ),
                          errorStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12.0,
                            color: Color(0xFFFB233B),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '';
                          }
                          if (value != _passwordController.text) {
                            _signController.showTooltip(
                              _confirmPasswordFocusNode,
                              'password_confirm',
                            );
                            return null;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 이메일 입력 필드와 드롭다운
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이메일 라벨
                      RichText(
                        text: TextSpan(
                          text: '이메일',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: Color(0xFF363636),
                            fontWeight: FontWeight.w500,
                            fontSize: 16.0,
                          ),
                          children: const [
                            TextSpan(
                              text: '*',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFFFB233B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 통합된 입력 필드와 드롭다운
                      Stack(
                        key: _emailFieldKey,
                        alignment: Alignment.centerRight,
                        children: [
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    (!_signController.isEmailValid ||
                                            _signController.isEmailDuplicate)
                                        ? Color(0xFFFB233B)
                                        : Colors.grey.shade300,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                // 이메일 입력 부분
                                Expanded(
                                  child: TextFormField(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    style: TextStyle(fontFamily: 'Pretendard'),
                                    decoration: InputDecoration(
                                      hintText: '이메일을 적어주세요.',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.grey,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      border: InputBorder.none,
                                      errorStyle: const TextStyle(height: -5),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        _signController.setEmailValid(false);
                                        return '';
                                      }
                                      _signController.setEmailValid(true);
                                      return null;
                                    },
                                  ),
                                ),
                                // 구분선
                                Container(
                                  width: 0.4,
                                  height: 30,
                                  color: Colors.grey.shade300,
                                ),
                                // 커스텀 도메인 드롭다운
                                InkWell(
                                  onTap: () {
                                    if (_isDropdownOpen) {
                                      _removeDropdownOverlay();
                                    } else {
                                      _showDropdownOverlay(
                                        context,
                                        _emailFieldKey,
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 140,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _signController.selectedDomain,
                                          style: TextStyle(
                                            color: const Color(0xFF363636),
                                            fontSize: 13,
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        Icon(
                                          _isDropdownOpen
                                              ? Icons.arrow_drop_up
                                              : Icons.arrow_drop_down,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 상태 아이콘을 위한 공간
                                SizedBox(width: 20),
                              ],
                            ),
                          ),
                          // 상태 아이콘 (이메일이 비어 있지 않을 때만 표시)
                          if (_emailController.text.isNotEmpty)
                            Positioned(
                              right: 16,
                              child: Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  _signController.isEmailDuplicate
                                      ? 'assets/icons/error_circle.svg'
                                      : 'assets/icons/check_circle.svg',
                                  width: 36,
                                  height: 24,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 약관 동의 섹션
                      buildAgreementCheckbox(
                        text: '약관에 모두 동의합니다',
                        value: true,
                        onChanged: (value) {},
                        isAll: true,
                      ),
                      const Divider(),
                      buildAgreementCheckbox(
                        text: '[필수] 서비스 이용약관 동의',
                        value: true,
                        onChanged: (value) {},
                        isRequired: true,
                        hasArrow: true,
                      ),
                      buildAgreementCheckbox(
                        text: '[필수] 개인정보 수집 및 이용 동의',
                        value: true,
                        onChanged: (value) {},
                        isRequired: true,
                        hasArrow: true,
                      ),
                      buildAgreementCheckbox(
                        text: '[선택] 홍보성 정보 수신 동의',
                        value: false,
                        onChanged: (value) {},
                        hasArrow: false,
                      ),
                      const SizedBox(height: 24),

                      // 가입하기 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _signController.signUp(_formKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            '가입하기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 입력 필드 생성 헬퍼 메서드
  Widget buildInputField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    bool obscureText = false,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    bool isRequired = false,
    bool hasError = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: const Color(0xFF363636),
              fontWeight: FontWeight.w500,
              fontSize: 16.0,
            ),
            children:
                isRequired
                    ? [
                      TextSpan(
                        text: '*',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: const Color(0xFFFB233B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]
                    : null,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          style: TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16.0,
              color: Colors.grey,
            ),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            // 테두리 스타일
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? Color(0xFFFB233B) : Colors.blue,
                width: 1.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFFB233B), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFFB233B), width: 1.0),
            ),
            errorStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.0,
              color: Color(0xFFFB233B),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // 상태 아이콘 생성 헬퍼 메서드
  Widget _buildStatusIcon(bool isError) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 20),
      child:
          isError
              ? SvgPicture.asset('assets/icons/error_circle.svg')
              : SvgPicture.asset('assets/icons/check_circle.svg'),
    );
  }

  // 약관 동의 체크박스 생성 헬퍼 메서드
  Widget buildAgreementCheckbox({
    required String text,
    required bool value,
    required Function(bool?) onChanged,
    bool isRequired = false,
    bool isAll = false,
    bool hasArrow = false,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          shape: const CircleBorder(),
          activeColor: isAll ? Color(0xFFB6B6B6) : Color(0xFFFB233B),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: isAll ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15.0,
              color: Color(0xFF363636),
            ),
          ),
        ),
        if (hasArrow) const Icon(Icons.chevron_right, color: Color(0xFFB6B6B6)),
      ],
    );
  }
}

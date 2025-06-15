// signup.dart (완전한 파일 - 하이브리드 방식)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tomapto/controllers/account/signup_controller.dart';
import 'package:tomapto/modal/terms_policy.dart';

// 스타일 상수 정의
class SignupStyles {
  // 색상
  static const Color primaryRed = Color(0xFFFB233B);
  static const Color primaryText = Color(0xFF363636);
  static const Color secondaryText = Color(0xFFB6B6B6);
  static const Color borderColor = Color(0xFFE0E0E0);

  // 크기
  static const double inputHeight = 56.0;
  static const double borderRadius = 16.0;
  static const double labelFontSize = 16.0;
  static const double hintFontSize = 16.0;
  static const double buttonFontSize = 18.0;

  // 패딩 및 마진
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
  static const double fieldSpacing = 16.0;
  static const double smallSpacing = 8.0;

  // 텍스트 스타일
  static const TextStyle labelStyle = TextStyle(
    fontFamily: 'Pretendard',
    color: primaryText,
    fontWeight: FontWeight.w500,
    fontSize: labelFontSize,
  );

  static const TextStyle hintStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: hintFontSize,
    color: Colors.grey,
  );

  static const TextStyle errorStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12.0,
    color: primaryRed,
  );

  static const TextStyle buttonStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: buttonFontSize,
    fontWeight: FontWeight.bold,
  );

  // 입력 필드 테두리 스타일
  static OutlineInputBorder getDefaultBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: borderColor, width: 1.0),
    );
  }

  static OutlineInputBorder getFocusedBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.0),
    );
  }

  static OutlineInputBorder getErrorBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: primaryRed, width: 1.0),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // 폼 키
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 스크롤 컨트롤러
  final ScrollController _scrollController = ScrollController();

  // 이메일 필드 키
  final GlobalKey _emailFieldKey = GlobalKey();

  // 드롭다운 오버레이
  OverlayEntry? _dropdownOverlay;

  // 컨트롤러 맵
  late final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'id': TextEditingController(),
    'nickname': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'email': TextEditingController(),
    'verificationCode': TextEditingController(),
  };

  // 포커스 노드 맵
  late final Map<String, FocusNode> _focusNodes = {
    'name': FocusNode(),
    'id': FocusNode(),
    'nickname': FocusNode(),
    'password': FocusNode(),
    'confirmPassword': FocusNode(),
    'email': FocusNode(),
    'verificationCode': FocusNode(),
  };

  TextEditingController get _verificationCodeController =>
      _controllers['verificationCode']!;

  // 회원가입 컨트롤러
  late SignupController _signupController;

  // 약관 동의 상태 변수
  bool _allAgreements = false;
  bool _serviceAgreement = false;
  bool _privacyAgreement = false;
  final bool _marketingAgreement = false;

  @override
  void initState() {
    super.initState();

    // 컨트롤러 초기화
    _signupController = SignupController(
      context: context,
      controllers: _controllers,
      focusNodes: _focusNodes,
      scrollController: _scrollController,
      updateUI: setState,
    );

    // 텍스트 변경 리스너 - 실시간 검증
    _controllers['name']?.addListener(() {
      _signupController.validateName(_controllers['name']!.text);
    });

    _controllers['id']?.addListener(() {
      _signupController.validateIdAndCheckDuplicate(_controllers['id']!.text);
    });

    _controllers['nickname']?.addListener(() {
      _signupController.validateNicknameAndCheckDuplicate(
        _controllers['nickname']!.text,
      );
    });

    _controllers['password']?.addListener(() {
      _signupController.validatePassword(_controllers['password']!.text);
    });

    _controllers['email']?.addListener(() {
      _signupController.validateEmailAndCheckDuplicate(
        _controllers['email']!.text,
      );
    });

    // 포커스 이벤트 리스너 - 툴팁 표시용
    _focusNodes['password']?.addListener(() {
      if (!_focusNodes['password']!.hasFocus &&
          _controllers['password']!.text.isNotEmpty) {
        if (!_signupController.isPasswordValid) {
          _signupController.showTooltip(_focusNodes['password']!, 'password');
        }
      }
    });

    _focusNodes['confirmPassword']?.addListener(() {
      if (!_focusNodes['confirmPassword']!.hasFocus &&
          _controllers['confirmPassword']!.text.isNotEmpty) {
        if (_validateConfirmPasswordStatus()) {
          _signupController.showTooltip(
            _focusNodes['confirmPassword']!,
            'password_confirm',
          );
        }
      }
    });

    _focusNodes['email']?.addListener(() {
      setState(() {}); // UI 업데이트
    });
  }

  @override
  void dispose() {
    // 드롭다운 오버레이 제거
    _removeDropdownOverlay();

    // 컨트롤러와 포커스 노드 해제
    _controllers.forEach((_, controller) => controller.dispose());
    _focusNodes.forEach((_, node) => node.dispose());

    // 스크롤 컨트롤러 해제
    _scrollController.dispose();

    // 회원가입 컨트롤러 정리
    _signupController.dispose();

    super.dispose();
  }

  // 비밀번호 확인 검증
  bool _validateConfirmPasswordStatus() {
    return _controllers['password']!.text !=
        _controllers['confirmPassword']!.text;
  }

  // 약관 동의 변경 처리
  void _handleAgreementChange(String type, bool? value) {
    setState(() {
      switch (type) {
        case 'all':
          _allAgreements = value ?? false;
          _serviceAgreement = _allAgreements;
          _privacyAgreement = _allAgreements;
          // _marketingAgreement 제거
          break;
        case 'service':
          _serviceAgreement = value ?? false;
          break;
        case 'privacy':
          _privacyAgreement = value ?? false;
          break;
      }

      // 전체 동의 상태 업데이트 (필수 약관만으로)
      _allAgreements = _serviceAgreement && _privacyAgreement;
    });
  }

  // 드롭다운 오버레이 제거
  void _removeDropdownOverlay() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  // 가입하기 버튼 이벤트
  Future<void> _handleSignup() async {
    // 약관 동의 확인 (필수 약관만)
    if (!_serviceAgreement || !_privacyAgreement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 약관에 동의해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final email =
        _controllers['email']!.text + _signupController.selectedDomain;
    final verificationCode = _controllers['verificationCode']!.text;

    if (verificationCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증번호를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 인증번호 확인
    await _signupController.verifyCode(email, verificationCode);

    // 인증이 완료되었는지 확인
    if (!_signupController.isEmailVerified) {
      return; // verifyCode 메서드에서 이미 에러 메시지를 표시함
    }

    // 회원가입 처리는 컨트롤러에 위임
    await _signupController.signup(_formKey);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _removeDropdownOverlay();
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
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
                  _buildNameField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 아이디 입력 필드
                  _buildIdField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 닉네임 입력 필드
                  _buildNicknameField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 비밀번호 필드
                  _buildPasswordField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 비밀번호 확인 필드
                  _buildConfirmPasswordField(),
                  const SizedBox(height: SignupStyles.fieldSpacing),

                  // 이메일 입력 필드
                  _buildEmailField(),
                  const SizedBox(height: 24),

                  // 인증번호 입력 필드
                  _buildVerificationCodeField(),
                  const SizedBox(height: 24),

                  // 약관 동의 섹션
                  _buildAgreementsSection(),
                  const SizedBox(height: 24),

                  // 가입하기 버튼
                  _buildSignupButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 앱바 구성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      scrolledUnderElevation: 0,
      title: const Text(
        '회원가입',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 22.0,
          color: Color(0xFF363636),
        ),
      ),
      leading: IconButton(
        icon: SvgPicture.asset('assets/icons/back.svg', width: 24, height: 24),
        onPressed: () => Navigator.pop(context),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
    );
  }

  // 이름 필드
  Widget _buildNameField() {
    final validation = _signupController.nameValidation;
    final hasText = _controllers['name']!.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        RichText(
          text: const TextSpan(
            text: '이름',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 입력 필드
        TextFormField(
          controller: _controllers['name'],
          focusNode: _focusNodes['name'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '이름을 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon:
                hasText ? _buildValidationIcon(validation.isValid) : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                validation.isValid
                    ? SignupStyles.getDefaultBorder()
                    : SignupStyles.getErrorBorder(),
            focusedBorder:
                validation.isValid
                    ? SignupStyles.getFocusedBorder()
                    : SignupStyles.getErrorBorder(),
          ),
          validator: (value) => validation.isValid ? null : validation.message,
        ),

        // 에러 메시지 표시
        if (hasText && !validation.isValid)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              validation.message ?? '',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
      ],
    );
  }

  // 아이디 필드
  Widget _buildIdField() {
    final formatValidation = _signupController.idFormatValidation;
    final isDuplicate = _signupController.isIdDuplicate;
    final isChecking = _signupController.isCheckingDuplicate;
    final hasText = _controllers['id']!.text.isNotEmpty;
    final isValid = formatValidation.isValid && !isDuplicate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        RichText(
          text: const TextSpan(
            text: '아이디',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 입력 필드
        TextFormField(
          controller: _controllers['id'],
          focusNode: _focusNodes['id'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '아이디를 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon:
                hasText
                    ? isChecking
                        ? _buildLoadingIcon()
                        : _buildValidationIcon(isValid)
                    : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                isValid
                    ? SignupStyles.getDefaultBorder()
                    : SignupStyles.getErrorBorder(),
            focusedBorder:
                isValid
                    ? SignupStyles.getFocusedBorder()
                    : SignupStyles.getErrorBorder(),
          ),
          validator: (value) {
            if (!formatValidation.isValid) return formatValidation.message;
            if (isDuplicate) return '이미 사용 중인 아이디입니다.';
            return null;
          },
        ),

        // 에러 메시지 표시
        if (hasText && !isValid)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              !formatValidation.isValid
                  ? formatValidation.message ?? ''
                  : '이미 사용 중인 아이디입니다.',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
      ],
    );
  }

  // 닉네임 필드
  Widget _buildNicknameField() {
    final formatValidation = _signupController.nicknameFormatValidation;
    final isDuplicate = _signupController.isNicknameDuplicate;
    final isChecking = _signupController.isCheckingDuplicate;
    final hasText = _controllers['nickname']!.text.isNotEmpty;
    final isValid = formatValidation.isValid && !isDuplicate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        RichText(
          text: const TextSpan(
            text: '닉네임',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 입력 필드
        TextFormField(
          controller: _controllers['nickname'],
          focusNode: _focusNodes['nickname'],
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '닉네임을 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon:
                hasText
                    ? isChecking
                        ? _buildLoadingIcon()
                        : _buildValidationIcon(isValid)
                    : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                isValid
                    ? SignupStyles.getDefaultBorder()
                    : SignupStyles.getErrorBorder(),
            focusedBorder:
                isValid
                    ? SignupStyles.getFocusedBorder()
                    : SignupStyles.getErrorBorder(),
          ),
          validator: (value) {
            if (!formatValidation.isValid) return formatValidation.message;
            if (isDuplicate) return '이미 사용 중인 닉네임입니다.';
            return null;
          },
        ),

        // 에러 메시지 표시
        if (hasText && !isValid)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              !formatValidation.isValid
                  ? formatValidation.message ?? ''
                  : '이미 사용 중인 닉네임입니다.',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
      ],
    );
  }

  // 비밀번호 필드
  Widget _buildPasswordField() {
    final validation = _signupController.passwordValidation;
    final hasText = _controllers['password']!.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        RichText(
          text: const TextSpan(
            text: '비밀번호',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 입력 필드
        TextFormField(
          controller: _controllers['password'],
          focusNode: _focusNodes['password'],
          obscureText: true,
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '비밀번호를 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon:
                hasText ? _buildValidationIcon(validation.isValid) : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                validation.isValid
                    ? SignupStyles.getDefaultBorder()
                    : SignupStyles.getErrorBorder(),
            focusedBorder:
                validation.isValid
                    ? SignupStyles.getFocusedBorder()
                    : SignupStyles.getErrorBorder(),
          ),
          validator: (value) => validation.isValid ? null : validation.message,
        ),

        // 에러 메시지 표시
        if (hasText && !validation.isValid)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              validation.message ?? '',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
      ],
    );
  }

  // 비밀번호 확인 필드
  Widget _buildConfirmPasswordField() {
    final hasText = _controllers['confirmPassword']!.text.isNotEmpty;
    final isMatching =
        _controllers['password']!.text == _controllers['confirmPassword']!.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        RichText(
          text: const TextSpan(
            text: '비밀번호 확인',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 입력 필드
        TextFormField(
          controller: _controllers['confirmPassword'],
          focusNode: _focusNodes['confirmPassword'],
          obscureText: true,
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16.0),
          decoration: InputDecoration(
            hintText: '비밀번호를 다시 입력해주세요.',
            hintStyle: SignupStyles.hintStyle,
            suffixIcon: hasText ? _buildValidationIcon(isMatching) : null,
            contentPadding: SignupStyles.fieldPadding,
            border: SignupStyles.getDefaultBorder(),
            enabledBorder:
                isMatching
                    ? SignupStyles.getDefaultBorder()
                    : SignupStyles.getErrorBorder(),
            focusedBorder:
                isMatching
                    ? SignupStyles.getFocusedBorder()
                    : SignupStyles.getErrorBorder(),
          ),
          validator: (value) {
            if (value != _controllers['password']!.text) {
              return '비밀번호가 일치하지 않습니다.';
            }
            return null;
          },
          onChanged: (value) => setState(() {}),
        ),

        // 에러 메시지 표시
        if (hasText && !isMatching)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              '비밀번호가 일치하지 않습니다.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
      ],
    );
  }

  // 이메일 필드
  Widget _buildEmailField() {
    final formatValidation = _signupController.emailFormatValidation;
    final isDuplicate = _signupController.isEmailDuplicate;
    final isChecking = _signupController.isCheckingDuplicate;
    final hasText = _controllers['email']!.text.isNotEmpty;
    final isValid = formatValidation.isValid && !isDuplicate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        RichText(
          text: const TextSpan(
            text: '이메일',
            style: SignupStyles.labelStyle,
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SignupStyles.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SignupStyles.smallSpacing),

        // 이메일 입력 필드와 도메인 선택
        Row(
          children: [
            // 이메일 입력 필드
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: _controllers['email'],
                focusNode: _focusNodes['email'],
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16.0,
                ),
                decoration: InputDecoration(
                  hintText: '이메일',
                  hintStyle: SignupStyles.hintStyle,
                  suffixIcon:
                      hasText
                          ? isChecking
                              ? _buildLoadingIcon()
                              : _buildValidationIcon(isValid)
                          : null,
                  contentPadding: SignupStyles.fieldPadding,
                  border: SignupStyles.getDefaultBorder(),
                  enabledBorder:
                      isValid
                          ? SignupStyles.getDefaultBorder()
                          : SignupStyles.getErrorBorder(),
                  focusedBorder:
                      isValid
                          ? SignupStyles.getFocusedBorder()
                          : SignupStyles.getErrorBorder(),
                ),
                validator: (value) {
                  if (!formatValidation.isValid)
                    return formatValidation.message;
                  if (isDuplicate) return '이미 사용 중인 이메일입니다.';
                  return null;
                },
                onChanged: (value) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            // 도메인 선택 드롭다운
            Expanded(flex: 2, child: _buildDomainDropdown()),
          ],
        ),

        // 에러 메시지 표시
        if (hasText && !isValid)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              !formatValidation.isValid
                  ? formatValidation.message ?? ''
                  : '이미 사용 중인 이메일입니다.',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
      ],
    );
  }

  // 도메인 선택 드롭다운 (크기 수정)
  Widget _buildDomainDropdown() {
    return Container(
      height: 56, // 이메일 입력 필드와 동일한 높이
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), // 패딩 줄임
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _signupController.selectedDomain,
          isExpanded: true,
          onChanged: (String? newValue) {
            if (newValue != null) {
              _signupController.setSelectedDomain(newValue);
            }
          },
          items:
              _signupController.domains.map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14, // 폰트 크기 줄임
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  // 인증번호 입력 필드
  // 인증번호 입력 필드 (개선된 버전)
  Widget _buildVerificationCodeField() {
    final email =
        _controllers['email']!.text + _signupController.selectedDomain;
    final hasEmail = _controllers['email']!.text.isNotEmpty;
    final isEmailValid = _signupController.emailFormatValidation.isValid;
    final isDuplicate = _signupController.isEmailDuplicate;
    final isTimerActive = _signupController.verificationTimeLeft > 0;

    // 버튼 활성화 조건: 이메일이 있고, 형식이 유효하고, 중복이 아닐 때
    final isButtonEnabled = hasEmail && isEmailValid && !isDuplicate;

    return Padding(
      padding: const EdgeInsets.only(right: 24.0), // 오른쪽 여백 추가
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨
          RichText(
            text: const TextSpan(
              text: '인증번호',
              style: SignupStyles.labelStyle,
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: SignupStyles.primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SignupStyles.smallSpacing),

          // 인증번호 입력 필드, 타이머, 전송/재전송 버튼을 한 줄에 배치
          Row(
            children: [
              // 인증번호 입력 필드 (가로 길이 축소)
              SizedBox(
                width: 200, // 고정 너비로 축소
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _focusNodes['verificationCode']!.hasFocus
                              ? SignupStyles.primaryRed
                              : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    controller: _controllers['verificationCode'],
                    focusNode: _focusNodes['verificationCode'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16.0,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: '인증번호',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontFamily: 'Pretendard',
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // 타이머 표시 (인증번호 발송 후)
              if (isTimerActive)
                Container(
                  width: 50,
                  height: 56,
                  alignment: Alignment.center,
                  child: Text(
                    '${_signupController.verificationTimeLeft ~/ 60}:${(_signupController.verificationTimeLeft % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: SignupStyles.primaryRed,
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(width: 4),

              // 전송/재전송 버튼 (더 작고 둥근 모양)
              SizedBox(
                width: 72,
                height: 40,
                child: ElevatedButton(
                  onPressed:
                      isButtonEnabled
                          ? () => _signupController.sendVerificationEmail(email)
                          : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      if (states.contains(WidgetState.disabled) ||
                          !isButtonEnabled) {
                        return Colors.grey[300]!;
                      }
                      return SignupStyles.primaryRed;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      if (states.contains(WidgetState.disabled) ||
                          !isButtonEnabled) {
                        return Colors.grey[600]!;
                      }
                      return Colors.white;
                    }),
                    elevation: WidgetStateProperty.all(0),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  child: Text(
                    isTimerActive ? '재전송' : '전송',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // 남은 공간을 채워서 재전송 버튼이 오른쪽으로 이동
              Expanded(child: Container()),
            ],
          ),
        ],
      ),
    );
  }

  // 약관 동의 섹션
  Widget _buildAgreementsSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white, // 하얀색 배경
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          // 전체 동의
          _buildAgreementCheckbox(
            text: '약관에 모두 동의합니다',
            value: _allAgreements,
            onChanged: (value) => _handleAgreementChange('all', value),
            isAll: true,
          ),

          // 구분선
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16.0),
            height: 1,
            color: Colors.grey[300],
          ),

          // 필수 약관 1
          _buildAgreementCheckbox(
            text: '[필수] 서비스 이용약관 동의',
            value: _serviceAgreement,
            onChanged: (value) => _handleAgreementChange('service', value),
            isRequired: true,
            hasArrow: true,
          ),

          // 필수 약관 2
          _buildAgreementCheckbox(
            text: '[필수] 개인정보 수집 및 이용 동의',
            value: _privacyAgreement,
            onChanged: (value) => _handleAgreementChange('privacy', value),
            isRequired: true,
            hasArrow: true,
          ),
        ],
      ),
    );
  }

  // 약관 동의 체크박스
  Widget _buildAgreementCheckbox({
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
          activeColor: SignupStyles.primaryRed, // 체크된 상태에서는 빨간색
          checkColor: Colors.white, // 체크 마크는 흰색
          side: BorderSide(color: Colors.grey[400]!, width: 2), // 테두리 회색
        ),
        Expanded(
          child: GestureDetector(
            onTap: hasArrow ? () => _showTermsModal(text) : null,
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400, // 모든 텍스트 동일한 굵기
                fontSize: 15.0,
                color: Colors.grey[600], // 모든 텍스트 동일한 회색
                // decoration 제거 (밑줄 없애기)
              ),
            ),
          ),
        ),
        if (hasArrow)
          GestureDetector(
            onTap: () => _showTermsModal(text),
            child: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ),
      ],
    );
  }

  void _showTermsModal(String agreementText) {
    TermsModalData? termsData;

    if (agreementText.contains('서비스 이용약관')) {
      termsData = AppTermsData.serviceTerms;
    } else if (agreementText.contains('개인정보 수집')) {
      termsData = AppTermsData.privacyCollection;
    }

    if (termsData != null) {
      TermsModal.show(context, termsData);
    }
  }

  // 가입하기 버튼
  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _handleSignup,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(SignupStyles.primaryRed),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.pressed)) {
              return SignupStyles.primaryRed.withOpacity(0.1);
            }
            return Colors.transparent;
          }),
        ),
        child: const Text(
          '가입하기',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // 헬퍼 메서드들
  Widget _buildValidationIcon(bool isValid) {
    return Icon(
      isValid ? Icons.check_circle : Icons.error,
      color: isValid ? Colors.green : Colors.red,
      size: 20,
    );
  }

  Widget _buildLoadingIcon() {
    return Container(
      width: 20,
      height: 20,
      padding: const EdgeInsets.all(12),
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
      ),
    );
  }
}

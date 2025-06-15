import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

// 상수 정의
class SignupConstants {
  // 툴팁 이미지 경로
  static const Map<String, String> tooltipImages = {
    'id': 'assets/icons/id_tooltip.svg',
    'nickname': 'assets/icons/nickname_tooltip.svg',
    'password': 'assets/icons/password_tooltip.svg',
    'password_confirm': 'assets/icons/password_confirm_tooltip.svg',
    'email': 'assets/icons/email_tooltip.svg',
    'name': 'assets/icons/name_tooltip.svg',
  };

  // 이메일 도메인 리스트
  static const List<String> domains = [
    '@naver.com',
    '@kakao.com',
    '@daum.net',
    '@hanmail.net',
  ];

  // 클라이언트 검증 규칙
  static const int minNameLength = 2;
  static const int maxNameLength = 20;
  static const int minIdLength = 4;
  static const int maxIdLength = 20;
  static const int minNicknameLength = 2;
  static const int maxNicknameLength = 15;
  static const int minPasswordLength = 8;
}

// 클라이언트 사이드 검증 유틸리티
class ClientValidator {
  // 이름 검증 (즉시)
  static ValidationResult validateName(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(isValid: false, message: '이름을 입력해주세요.');
    }
    if (value.length < SignupConstants.minNameLength) {
      return ValidationResult(
        isValid: false,
        message: '이름은 ${SignupConstants.minNameLength}자 이상이어야 합니다.',
      );
    }
    if (value.length > SignupConstants.maxNameLength) {
      return ValidationResult(
        isValid: false,
        message: '이름은 ${SignupConstants.maxNameLength}자 이하여야 합니다.',
      );
    }
    if (!RegExp(r'^[가-힣]+$').hasMatch(value)) {
      return ValidationResult(isValid: false, message: '이름은 한글만 입력 가능합니다.');
    }
    return ValidationResult(isValid: true);
  }

  // 아이디 형식 검증 (즉시)
  static ValidationResult validateIdFormat(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(isValid: false, message: '아이디를 입력해주세요.');
    }
    if (value.length < SignupConstants.minIdLength) {
      return ValidationResult(
        isValid: false,
        message: '아이디는 ${SignupConstants.minIdLength}자 이상이어야 합니다.',
      );
    }
    if (value.length > SignupConstants.maxIdLength) {
      return ValidationResult(
        isValid: false,
        message: '아이디는 ${SignupConstants.maxIdLength}자 이하여야 합니다.',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        message: '아이디는 영문, 숫자만 입력 가능합니다.',
      );
    }
    if (!RegExp(r'^[a-zA-Z]').hasMatch(value)) {
      return ValidationResult(isValid: false, message: '아이디는 영문으로 시작해야 합니다.');
    }
    return ValidationResult(isValid: true);
  }

  // 닉네임 형식 검증 (즉시)
  static ValidationResult validateNicknameFormat(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(isValid: false, message: '닉네임을 입력해주세요.');
    }
    if (value.length < SignupConstants.minNicknameLength) {
      return ValidationResult(
        isValid: false,
        message: '닉네임은 ${SignupConstants.minNicknameLength}자 이상이어야 합니다.',
      );
    }
    if (value.length > SignupConstants.maxNicknameLength) {
      return ValidationResult(
        isValid: false,
        message: '닉네임은 ${SignupConstants.maxNicknameLength}자 이하여야 합니다.',
      );
    }
    if (!RegExp(r'^[가-힣a-zA-Z0-9]+$').hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        message: '닉네임은 한글, 영문, 숫자만 입력 가능합니다.',
      );
    }
    return ValidationResult(isValid: true);
  }

  // 비밀번호 검증 (즉시)
  static ValidationResult validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(isValid: false, message: '비밀번호를 입력해주세요.');
    }
    if (value.length < SignupConstants.minPasswordLength) {
      return ValidationResult(
        isValid: false,
        message: '비밀번호는 ${SignupConstants.minPasswordLength}자 이상이어야 합니다.',
      );
    }
    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(value)) {
      return ValidationResult(
        isValid: false,
        message: '비밀번호는 영문과 숫자를 포함해야 합니다.',
      );
    }
    if (value.contains(' ')) {
      return ValidationResult(
        isValid: false,
        message: '비밀번호에는 공백을 포함할 수 없습니다.',
      );
    }
    return ValidationResult(isValid: true);
  }

  // 이메일 형식 검증 (즉시)
  static ValidationResult validateEmailFormat(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(isValid: false, message: '이메일을 입력해주세요.');
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+$').hasMatch(value)) {
      return ValidationResult(isValid: false, message: '올바른 이메일 형식이 아닙니다.');
    }
    return ValidationResult(isValid: true);
  }
}

// 검증 결과 클래스
class ValidationResult {
  final bool isValid;
  final String? message;

  ValidationResult({required this.isValid, this.message});
}

// API 서비스 클래스 - 서버 통신만 담당
class SignupApiService {
  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      return baseUrl.replaceAll('localhost', '10.0.2.2');
    }
    return baseUrl;
  }

  // 중복 확인 API 호출 (서버 검증)
  static Future<Map<String, dynamic>> checkDuplicate(
    String field,
    String value,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final encodedValue = Uri.encodeComponent(value);
      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/account/check-duplicate?field=$field&value=$encodedValue',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'isDuplicate': data['isDuplicate'] ?? false};
      }
      return {'success': false, 'isDuplicate': false};
    } catch (e) {
      print('중복 확인 오류: $e');
      return {'success': false, 'isDuplicate': false};
    }
  }

  // 회원가입 API 호출
  static Future<Map<String, dynamic>> signup(
    Map<String, String> userData,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'message': '회원가입이 완료되었습니다.'};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? '회원가입 중 오류가 발생했습니다.',
        };
      }
    } catch (e) {
      print('회원가입 오류: $e');
      return {'success': false, 'message': '회원가입 중 오류가 발생했습니다.'};
    }
  }

  // 이메일 인증번호 발송 API 호출
  static Future<Map<String, dynamic>> sendVerificationEmail(
    String email,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/verification/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '인증번호가 이메일로 발송되었습니다.'};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? '인증번호 발송에 실패했습니다.',
        };
      }
    } catch (e) {
      print('이메일 인증 발송 오류: $e');
      return {'success': false, 'message': '서버 연결에 실패했습니다.'};
    }
  }

  // 이메일 인증번호 확인 API 호출
  static Future<Map<String, dynamic>> verifyCode(
    String email,
    String code,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/account/verification/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['verified'] ?? false,
          'verified': data['verified'] ?? false,
          'message':
              data['message'] ??
              (data['verified'] == true
                  ? '이메일 인증이 완료되었습니다.'
                  : '인증번호가 일치하지 않습니다.'),
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'verified': false,
          'message': errorData['message'] ?? '인증번호가 일치하지 않습니다.',
        };
      }
    } catch (e) {
      print('이메일 인증 확인 오류: $e');
      return {'success': false, 'verified': false, 'message': '서버 연결에 실패했습니다.'};
    }
  }
}

// 툴팁 관리 클래스
class TooltipManager {
  OverlayEntry? _currentTooltip;
  String? _currentTooltipType;

  void showTooltip(BuildContext context, FocusNode node, String tooltipType) {
    removeTooltip();

    final overlay = Overlay.of(context);
    final RenderBox fieldBox = node.context!.findRenderObject() as RenderBox;
    final fieldPosition = fieldBox.localToGlobal(Offset.zero);
    final fieldSize = fieldBox.size;

    final String imagePath =
        SignupConstants.tooltipImages[tooltipType] ??
        'assets/icons/error_circle.svg';

    double left = fieldPosition.dx + fieldSize.width - 135;
    double top = fieldPosition.dy + fieldSize.height + 3;

    if (tooltipType == 'email') {
      left = fieldPosition.dx + fieldSize.width + 18;
    }

    _currentTooltipType = tooltipType;

    _currentTooltip = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: removeTooltip,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: SvgPicture.asset(
                  imagePath,
                  width: 186,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_currentTooltip!);
  }

  void removeTooltip() {
    if (_currentTooltip != null) {
      _currentTooltip!.remove();
      _currentTooltip = null;
      _currentTooltipType = null;
    }
  }

  void dispose() {
    removeTooltip();
  }
}

// 하이브리드 회원가입 컨트롤러 (클라이언트 + 서버 검증)
class SignupController {
  final BuildContext context;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final ScrollController scrollController;
  final Function(VoidCallback) updateUI;

  // UI 상태
  String _selectedDomain = SignupConstants.domains[0];

  // 클라이언트 검증 상태 (즉시)
  ValidationResult _nameValidation = ValidationResult(isValid: true);
  ValidationResult _idFormatValidation = ValidationResult(isValid: true);
  ValidationResult _nicknameFormatValidation = ValidationResult(isValid: true);
  ValidationResult _passwordValidation = ValidationResult(isValid: true);
  ValidationResult _emailFormatValidation = ValidationResult(isValid: true);

  // 서버 검증 상태 (디바운스)
  bool _isIdDuplicate = false;
  bool _isNicknameDuplicate = false;
  bool _isEmailDuplicate = false;
  bool _isCheckingDuplicate = false;

  // 이메일 인증 상태
  bool _isVerificationSent = false;
  bool _isEmailVerified = false;
  int _verificationTimeLeft = 0;
  Timer? _verificationTimer;

  // 디바운스 타이머
  Timer? _idDebounceTimer;
  Timer? _nicknameDebounceTimer;
  Timer? _emailDebounceTimer;

  final TooltipManager _tooltipManager = TooltipManager();

  SignupController({
    required this.context,
    required this.controllers,
    required this.focusNodes,
    required this.scrollController,
    required this.updateUI,
  });

  // Getters - 클라이언트 검증
  ValidationResult get nameValidation => _nameValidation;
  ValidationResult get idFormatValidation => _idFormatValidation;
  ValidationResult get nicknameFormatValidation => _nicknameFormatValidation;
  ValidationResult get passwordValidation => _passwordValidation;
  ValidationResult get emailFormatValidation => _emailFormatValidation;

  // Getters - 서버 검증
  bool get isIdDuplicate => _isIdDuplicate;
  bool get isNicknameDuplicate => _isNicknameDuplicate;
  bool get isEmailDuplicate => _isEmailDuplicate;
  bool get isCheckingDuplicate => _isCheckingDuplicate;

  // Getters - 기타
  String get selectedDomain => _selectedDomain;
  List<String> get domains => SignupConstants.domains;
  bool get isVerificationSent => _isVerificationSent;
  bool get isEmailVerified => _isEmailVerified;
  int get verificationTimeLeft => _verificationTimeLeft;

  // 전체 유효성 상태
  bool get isNameValid => _nameValidation.isValid;
  bool get isIdValid => _idFormatValidation.isValid && !_isIdDuplicate;
  bool get isNicknameValid =>
      _nicknameFormatValidation.isValid && !_isNicknameDuplicate;
  bool get isEmailValid => _emailFormatValidation.isValid && !_isEmailDuplicate;
  bool get isPasswordValid => _passwordValidation.isValid;

  // 도메인 선택
  void setSelectedDomain(String domain) {
    updateUI(() {
      _selectedDomain = domain;
    });

    // 이메일이 입력되어 있다면 중복 확인
    if (controllers['email']!.text.isNotEmpty) {
      validateEmailAndCheckDuplicate(controllers['email']!.text);
    }
  }

  // 이름 검증 (즉시)
  void validateName(String value) {
    updateUI(() {
      _nameValidation = ClientValidator.validateName(value);
    });
  }

  // 아이디 검증 (즉시 형식 + 디바운스 중복)
  void validateIdAndCheckDuplicate(String value) {
    // 1. 즉시 형식 검증
    updateUI(() {
      _idFormatValidation = ClientValidator.validateIdFormat(value);
    });

    // 2. 형식이 유효하면 중복 확인 (디바운스)
    if (_idFormatValidation.isValid && value.isNotEmpty) {
      _idDebounceTimer?.cancel();
      _idDebounceTimer = Timer(Duration(milliseconds: 500), () {
        _checkDuplicate('user_id', value);
      });
    } else {
      // 형식이 유효하지 않으면 중복 상태 초기화
      updateUI(() {
        _isIdDuplicate = false;
      });
    }
  }

  // 닉네임 검증 (즉시 형식 + 디바운스 중복)
  void validateNicknameAndCheckDuplicate(String value) {
    // 1. 즉시 형식 검증
    updateUI(() {
      _nicknameFormatValidation = ClientValidator.validateNicknameFormat(value);
    });

    // 2. 형식이 유효하면 중복 확인 (디바운스)
    if (_nicknameFormatValidation.isValid && value.isNotEmpty) {
      _nicknameDebounceTimer?.cancel();
      _nicknameDebounceTimer = Timer(Duration(milliseconds: 500), () {
        _checkDuplicate('user_nickname', value);
      });
    } else {
      updateUI(() {
        _isNicknameDuplicate = false;
      });
    }
  }

  // 비밀번호 검증 (즉시)
  void validatePassword(String value) {
    updateUI(() {
      _passwordValidation = ClientValidator.validatePassword(value);
    });
  }

  // 이메일 검증 (즉시 형식 + 디바운스 중복)
  void validateEmailAndCheckDuplicate(String value) {
    // 1. 즉시 형식 검증
    updateUI(() {
      _emailFormatValidation = ClientValidator.validateEmailFormat(value);
    });

    // 2. 형식이 유효하면 중복 확인 (디바운스)
    if (_emailFormatValidation.isValid && value.isNotEmpty) {
      final fullEmail = value + _selectedDomain;
      _emailDebounceTimer?.cancel();
      _emailDebounceTimer = Timer(Duration(milliseconds: 500), () {
        _checkDuplicate('user_email', fullEmail);
      });
    } else {
      updateUI(() {
        _isEmailDuplicate = false;
        _isVerificationSent = false;
        _isEmailVerified = false;
        _verificationTimer?.cancel();
      });
    }
  }

  // 중복 확인 (서버 통신)
  Future<void> _checkDuplicate(String field, String value) async {
    updateUI(() {
      _isCheckingDuplicate = true;
    });

    final result = await SignupApiService.checkDuplicate(field, value);

    updateUI(() {
      _isCheckingDuplicate = false;

      if (result['success']) {
        switch (field) {
          case 'user_id':
            _isIdDuplicate = result['isDuplicate'];
            break;
          case 'user_nickname':
            _isNicknameDuplicate = result['isDuplicate'];
            break;
          case 'user_email':
            _isEmailDuplicate = result['isDuplicate'];
            // 이메일이 중복되면 인증 상태 초기화
            if (_isEmailDuplicate) {
              _isVerificationSent = false;
              _isEmailVerified = false;
              _verificationTimer?.cancel();
            }
            break;
        }
      }
    });
  }

  // 이메일 인증번호 발송
  Future<void> sendVerificationEmail(String email) async {
    _verificationTimer?.cancel();

    updateUI(() {
      _isVerificationSent = true;
      _isEmailVerified = false;
      _verificationTimeLeft = 300; // 5분
    });

    // 타이머 시작
    _verificationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      updateUI(() {
        if (_verificationTimeLeft > 0) {
          _verificationTimeLeft--;
        } else {
          timer.cancel();
          _isVerificationSent = false;
        }
      });
    });

    final result = await SignupApiService.sendVerificationEmail(email);

    _showMessage(result['message'], isError: !result['success']);

    if (!result['success']) {
      updateUI(() {
        _isVerificationSent = false;
        _verificationTimer?.cancel();
      });
    }
  }

  // 인증번호 확인
  Future<void> verifyCode(String email, String code) async {
    final result = await SignupApiService.verifyCode(email, code);

    updateUI(() {
      _isEmailVerified = result['verified'];
      if (_isEmailVerified) {
        _verificationTimer?.cancel();
      }
    });

    _showMessage(result['message'], isError: !result['success']);
  }

  // 툴팁 표시
  void showTooltip(FocusNode node, String tooltipType) {
    _tooltipManager.showTooltip(context, node, tooltipType);
  }

  // 회원가입 처리
  Future<void> signup(GlobalKey<FormState> formKey) async {
    try {
      // 전체 검증 확인
      if (!isNameValid) {
        _showMessage(_nameValidation.message ?? '이름을 확인해주세요.', isError: true);
        return;
      }

      if (!isIdValid) {
        if (!_idFormatValidation.isValid) {
          _showMessage(
            _idFormatValidation.message ?? '아이디를 확인해주세요.',
            isError: true,
          );
        } else if (_isIdDuplicate) {
          _showMessage('이미 사용 중인 아이디입니다.', isError: true);
        }
        return;
      }

      if (!isNicknameValid) {
        if (!_nicknameFormatValidation.isValid) {
          _showMessage(
            _nicknameFormatValidation.message ?? '닉네임을 확인해주세요.',
            isError: true,
          );
        } else if (_isNicknameDuplicate) {
          _showMessage('이미 사용 중인 닉네임입니다.', isError: true);
        }
        return;
      }

      if (!isPasswordValid) {
        _showMessage(
          _passwordValidation.message ?? '비밀번호를 확인해주세요.',
          isError: true,
        );
        return;
      }

      if (!isEmailValid) {
        if (!_emailFormatValidation.isValid) {
          _showMessage(
            _emailFormatValidation.message ?? '이메일을 확인해주세요.',
            isError: true,
          );
        } else if (_isEmailDuplicate) {
          _showMessage('이미 사용 중인 이메일입니다.', isError: true);
        }
        return;
      }

      if (!_isEmailVerified) {
        _showMessage('이메일 인증이 필요합니다.', isError: true);
        return;
      }

      // 회원가입 데이터 준비
      final userData = {
        'user_name': controllers['name']?.text ?? '',
        'user_id': controllers['id']?.text ?? '',
        'user_nickname': controllers['nickname']?.text ?? '',
        'user_password': controllers['password']?.text ?? '',
        'user_email': (controllers['email']?.text ?? '') + _selectedDomain,
      };

      // API 호출
      final result = await SignupApiService.signup(userData);

      _showMessage(result['message'], isError: !result['success']);

      if (result['success'] == true) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('회원가입 처리 중 오류: $e');
      _showMessage('회원가입 처리 중 오류가 발생했습니다.', isError: true);
    }
  }

  // 메시지 표시 헬퍼
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Pretendard'),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // 정리
  void dispose() {
    _verificationTimer?.cancel();
    _idDebounceTimer?.cancel();
    _nicknameDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _tooltipManager.dispose();
  }
}

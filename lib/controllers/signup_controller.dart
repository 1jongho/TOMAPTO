import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class SignController {
  // Context for showing tooltips
  final BuildContext context;

  // Text controllers
  final TextEditingController nameController;
  final TextEditingController idController;
  final TextEditingController nicknameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController emailController;

  // Focus nodes
  final FocusNode idFocusNode;
  final FocusNode nicknameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final FocusNode confirmPasswordFocusNode;

  // Scroll controller
  final ScrollController scrollController;

  // Function to update the UI
  final Function(VoidCallback) updateUI;

  // Email domain related variables - _domains를 public 변수로 변경
  String _selectedDomain = '@naver.com';
  final List<String> domains = [
    '@naver.com',
    '@kakao.com',
    '@daum.net',
    '@hanmail.net',
  ];

  // Status variables
  bool _isIdDuplicate = false;
  bool _isNicknameDuplicate = false;
  bool _isEmailDuplicate = false;
  bool _isEmailValid = true;

  // Debounce timers
  Timer? _idDebounceTimer;
  Timer? _nicknameDebounceTimer;
  Timer? _emailDebounceTimer;

  // Tooltip related variables
  OverlayEntry? _currentTooltip;
  String? _currentTooltipType;
  final GlobalKey _fixedTooltipKey = GlobalKey();

  // Tooltip image paths
  final Map<String, String> _tooltipImages = {
    'id': 'assets/icons/id_tooltip.svg',
    'nickname': 'assets/icons/nickname_tooltip.svg',
    'password': 'assets/icons/password_tooltip.svg',
    'password_confirm': 'assets/icons/password_confirm_tooltip.svg',
    'email': 'assets/icons/email_tooltip.svg',
  };

  // Getters for private properties
  bool get isIdDuplicate => _isIdDuplicate;
  bool get isNicknameDuplicate => _isNicknameDuplicate;
  bool get isEmailDuplicate => _isEmailDuplicate;
  bool get isEmailValid => _isEmailValid;
  String get selectedDomain => _selectedDomain;

  SignController({
    required this.context,
    required this.nameController,
    required this.idController,
    required this.nicknameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.emailController,
    required this.idFocusNode,
    required this.nicknameFocusNode,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.confirmPasswordFocusNode,
    required this.scrollController,
    required this.updateUI,
  });

  // Clean up resources
  void dispose() {
    // Cancel timers
    _idDebounceTimer?.cancel();
    _nicknameDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();

    // Remove tooltip
    _removeTooltip();
  }

  // Scroll event handler - remove tooltip if displayed
  void onScroll() {
    if (_currentTooltip != null) {
      _removeTooltip();
    }
  }

  // Focus change handlers
  void onIdFocusChange() {
    if (!idFocusNode.hasFocus && idController.text.isNotEmpty) {
      _checkIdDuplicate(idController.text);
    } else if (!idFocusNode.hasFocus) {
      _removeTooltip();
    }
  }

  void onNicknameFocusChange() {
    if (!nicknameFocusNode.hasFocus && nicknameController.text.isNotEmpty) {
      _checkNicknameDuplicate(nicknameController.text);
    } else if (!nicknameFocusNode.hasFocus) {
      _removeTooltip();
    }
  }

  void onEmailFocusChange() {
    if (!emailFocusNode.hasFocus && emailController.text.isNotEmpty) {
      _checkEmailDuplicate(emailController.text + _selectedDomain);
    } else if (!emailFocusNode.hasFocus) {
      _removeTooltip();
    }
  }

  // Get API base URL
  String get _apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';

  // Text change handlers
  void onIdChanged() {
    _idDebounceTimer?.cancel();
    if (idController.text.isNotEmpty) {
      _idDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _checkIdDuplicate(idController.text);
      });
    } else {
      updateUI(() {
        _isIdDuplicate = false;
      });
      _removeTooltip();
    }
  }

  void onNicknameChanged() {
    _nicknameDebounceTimer?.cancel();
    if (nicknameController.text.isNotEmpty) {
      _nicknameDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _checkNicknameDuplicate(nicknameController.text);
      });
    } else {
      updateUI(() {
        _isNicknameDuplicate = false;
      });
      _removeTooltip();
    }
  }

  void onEmailChanged() {
    _emailDebounceTimer?.cancel();
    if (emailController.text.isNotEmpty) {
      _emailDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _checkEmailDuplicate(emailController.text + _selectedDomain);
      });
    } else {
      updateUI(() {
        _isEmailDuplicate = false;
      });
      _removeTooltip();
    }
  }

  // Duplicate check API call functions
  Future<void> _checkIdDuplicate(String id) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/account/check-duplicate?field=user_id&value=$id',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        updateUI(() {
          _isIdDuplicate = data['isDuplicate'] ?? false;
        });

        if (_isIdDuplicate) {
          showTooltip(idFocusNode, 'id');
        } else {
          _removeTooltip();
        }
      } else {
        print('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('ID 중복 확인 중 오류 발생: $e');
    }
  }

  Future<void> _checkNicknameDuplicate(String nickname) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/account/check-duplicate?field=user_nickname&value=$nickname',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        updateUI(() {
          _isNicknameDuplicate = data['isDuplicate'] ?? false;
        });

        if (_isNicknameDuplicate) {
          showTooltip(nicknameFocusNode, 'nickname');
        } else {
          _removeTooltip();
        }
      } else {
        print('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('닉네임 중복 확인 중 오류 발생: $e');
    }
  }

  Future<void> _checkEmailDuplicate(String email) async {
    try {
      final encodedEmail = Uri.encodeComponent(email);

      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/account/check-duplicate?field=user_email&value=$encodedEmail',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        updateUI(() {
          _isEmailDuplicate = data['isDuplicate'] ?? false;
        });

        if (_isEmailDuplicate) {
          showTooltip(emailFocusNode, 'email');
        } else {
          _removeTooltip();
        }
      } else {
        print('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('이메일 중복 확인 중 오류 발생: $e');
    }
  }

  // Tooltip display function - uses a fixed overlay on the entire app
  void showTooltip(FocusNode node, String tooltipType) {
    // Remove previous tooltip
    _removeTooltip();

    // Get current screen state
    final overlay = Overlay.of(context);

    // Get the actual screen position of the field
    final RenderBox fieldBox = node.context!.findRenderObject() as RenderBox;
    final fieldPosition = fieldBox.localToGlobal(Offset.zero);
    final fieldSize = fieldBox.size;

    // Get tooltip image path
    final String imagePath =
        _tooltipImages[tooltipType] ?? 'assets/icons/error_circle.svg';

    // Calculate tooltip position - handle differently based on field type
    double left = fieldPosition.dx + fieldSize.width - 135;
    double top = fieldPosition.dy + fieldSize.height + 3;

    // Special handling for email field
    if (tooltipType == 'email') {
      left = fieldPosition.dx + fieldSize.width + 18;
    }

    // Save current type
    _currentTooltipType = tooltipType;

    // Create OverlayEntry - displayed at a fixed position on the screen
    _currentTooltip = OverlayEntry(
      // Important: OverlayEntry spans the entire screen and is independent of scrolling
      builder: (context) {
        return Stack(
          children: [
            // Transparent full screen - for handling touches outside the tooltip
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeTooltip,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Display tooltip at fixed position
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

    // Add tooltip to overlay
    overlay.insert(_currentTooltip!);
  }

  // Remove tooltip function
  void _removeTooltip() {
    if (_currentTooltip != null) {
      _currentTooltip!.remove();
      _currentTooltip = null;
      _currentTooltipType = null;
    }
  }

  // Update email validation status
  void setEmailValid(bool isValid) {
    updateUI(() {
      _isEmailValid = isValid;
    });
  }

  // Update domain selection
  void updateDomain(String newDomain) {
    updateUI(() {
      _selectedDomain = newDomain;
    });
    if (emailController.text.isNotEmpty) {
      _checkEmailDuplicate(emailController.text + _selectedDomain);
    }
  }

  // Signup execution function
  Future<void> signUp(GlobalKey<FormState> formKey) async {
    bool isEmailValid = emailController.text.isNotEmpty;
    updateUI(() {
      _isEmailValid = isEmailValid;
    });

    // Only proceed with signup if validation passes
    if (formKey.currentState!.validate() &&
        !_isIdDuplicate &&
        !_isNicknameDuplicate &&
        !_isEmailDuplicate &&
        _isEmailValid) {
      try {
        // Prepare signup data
        final userData = {
          'user_name': nameController.text,
          'user_id': idController.text,
          'user_nickname': nicknameController.text,
          'user_password': passwordController.text,
          'user_email': emailController.text + _selectedDomain,
        };

        // API call
        final response = await http.post(
          Uri.parse('$_apiBaseUrl/account/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(userData),
        );

        // Handle response
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '회원가입이 완료되었습니다.',
                style: TextStyle(fontFamily: 'Pretendard'),
              ),
            ),
          );

          // Navigate to login page (commented out)
          // Navigator.of(context).pushReplacementNamed('/login');
        } else {
          // Error handling
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['message'] ?? '회원가입 중 오류가 발생했습니다.',
                style: TextStyle(fontFamily: 'Pretendard'),
              ),
            ),
          );
        }
      } catch (e) {
        print('회원가입 중 오류 발생: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '회원가입 중 오류가 발생했습니다.',
              style: TextStyle(fontFamily: 'Pretendard'),
            ),
          ),
        );
      }
    }
  }
}

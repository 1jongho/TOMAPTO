import 'package:flutter/material.dart';

// transit.dart
class AppStyles {
  // 앱의 기본 테마
  static ThemeData get theme => ThemeData(
    primarySwatch: Colors.red,
    fontFamily: 'Pretendard',
    // 필요한 다른 테마 속성들 추가
  );

  // 색상 상수
  static const Color primaryColor = Color(0xFFFB233B);
  static const Color searchBarColor = Color(0xFFFB5063);
  static const Color busNumberColor = Color(0xFF00C73C);

  // 텍스트 스타일
  static const TextStyle searchTextStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle routeTimeStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  // 기타 필요한 스타일 추가
}

//
//
//
// login.dart

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

// 폰트 사이즈 상수 정의
class AppFontSize {
  static const double small = 12.0;
  static const double medium = 14.0;
  static const double regular = 16.0;
  static const double large = 18.0;
  static const double extraLarge = 20.0;
  static const double headline = 24.0;
}

// 폰트 웨이트 상수 정의
class AppFontWeight {
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

// 텍스트 스타일 상수 정의
class AppTextStyle {
  static TextStyle get smallRegular => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.small,
    fontWeight: AppFontWeight.regular,
  );

  static TextStyle get mediumRegular => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.medium,
    fontWeight: AppFontWeight.regular,
  );

  static TextStyle get regularRegular => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.regular,
    fontWeight: AppFontWeight.regular,
  );

  static TextStyle get regularSemiBold => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.regular,
    fontWeight: AppFontWeight.semiBold,
  );

  static TextStyle get regularBold => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.regular,
    fontWeight: AppFontWeight.bold,
  );

  static TextStyle get largeBold => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: AppFontSize.large,
    fontWeight: AppFontWeight.bold,
  );
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

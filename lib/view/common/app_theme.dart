import 'package:flutter/material.dart';

// FITPICK 관리자 앱 공통 색상과 글꼴
class AppColors {
  static const sidebar = Color(0xFF161B26);
  static const sidebarSelected = Color(0xFF2A3142);
  static const background = Color(0xFFF7F8FA);
  static const card = Colors.white;
  static const border = Color(0xFFE8EBEF);
  static const text = Color(0xFF161B26);
  static const subText = Color(0xFF8A919E);
  static const mint = Color(0xFFAFD6CE);
  static const teal = Color(0xFF0F6B57);
  static const coral = Color(0xFFF0707A);
  static const amberBg = Color(0xFFFFF1D6);
  static const amberText = Color(0xFF8A5A00);
  static const greenBg = Color(0xFFDDF3E8);
  static const greenText = Color(0xFF1A6B45);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    // 글꼴을 인터넷에서 내려받지 않고 기기의 기본 한글 글꼴(안드로이드는 Noto Sans CJK)을 사용
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    );
  }
}

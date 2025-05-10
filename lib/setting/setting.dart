// setting.dart
import 'package:flutter/material.dart';
import 'noti.dart';
import 'mapSetting.dart';
import 'naviSetting.dart';
import 'moveHistory.dart';
import 'termsPolicy.dart';
// Import ProfilePage
import 'package:tomapto/pages/profile/profile.dart'; // 프로필 페이지 import 추가

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '설정 화면',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const SettingsScreen(),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {
            // 프로필 페이지로 돌아가기
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 2),
            _buildMenuItem(
              context,
              title: '알림',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 5),
            _buildMenuItem(
              context,
              title: '지도',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MapSettingsScreen(),
                  ),
                );
              },
              bottomSpace: 1,
            ),
            _buildMenuItem(
              context,
              title: '내비게이션',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NavigationSettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 5),
            _buildMenuItem(
              context,
              title: '이동 이력 관리',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MoveHistoryScreen(),
                  ),
                );
              },
              bottomSpace: 1,
            ),
            _buildMenuItem(
              context,
              title: '이용 약관 및 정책',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsAndPolicyScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 5),
            _buildVersionItem(context),
            const SizedBox(height: 5),
            _buildLogoutButton(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
    double bottomSpace = 0,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomSpace),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionItem(BuildContext context) {
    return Container(
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '버전',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Text(
                '현재 버전 0.0 / 최신 버전 0.0',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () {
            // 회원탈퇴 동작
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '회원탈퇴',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

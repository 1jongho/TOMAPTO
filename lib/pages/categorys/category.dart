import 'package:flutter/material.dart';
import 'package:tomapto/widgets/navbar.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('카테고리')),
      body: Center(child: Text('category.dart 화면')),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2, // 카테고리 페이지는 인덱스 2번
        onTap: (index) {
          // 탭 이벤트 처리는 BottomNavBar 내부에서 이미 구현되어 있습니다
        },
      ),
    );
  }
}

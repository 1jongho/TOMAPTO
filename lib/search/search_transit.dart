import 'package:flutter/material.dart';
import 'package:tomapto/styles/app_styles.dart';

// 검색 모드를 정의하는 enum
enum SearchMode {
  origin, // 출발지 검색
  destination, // 도착지 검색
}

class SearchPage extends StatefulWidget {
  final SearchMode mode;

  const SearchPage({super.key, required this.mode});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentSearches = [
    '강릉역',
    '강원대학교',
    '강릉 중앙시장',
    '강릉커피거리',
    '경포대해수욕장',
  ];

  List<String> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      // 실제로는 API 호출이나 데이터베이스 쿼리가 들어갈 부분
      _searchResults = [
        '$query역',
        '$query 시장',
        '$query 학교',
        '$query 병원',
        '$query 마트',
      ];
    });
  }

  void _selectPlace(String place) {
    // 선택된 장소를 이전 화면으로 반환
    Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width;
    final isSmallScreen = width < 360;
    final fontSize = isSmallScreen ? 14.0 : 16.0;

    final String title = widget.mode == SearchMode.origin ? '출발지 검색' : '도착지 검색';
    final String hintText =
        widget.mode == SearchMode.origin ? '출발지를 입력해주세요' : '도착지를 입력해주세요';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppStyles.primaryColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 검색 입력 필드
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(width * 0.04),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppStyles.primaryColor),
                ),
              ),
            ),
          ),

          // 구분선
          const Divider(height: 1),

          // 검색 결과 또는 최근 검색어 목록
          Expanded(
            child:
                _isSearching
                    ? _buildSearchResults(fontSize)
                    : _buildRecentSearches(fontSize),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(double fontSize) {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.grey),
          title: Text(
            _searchResults[index],
            style: TextStyle(fontSize: fontSize),
          ),
          onTap: () => _selectPlace(_searchResults[index]),
        );
      },
    );
  }

  Widget _buildRecentSearches(double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '최근 검색',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(
                  _recentSearches[index],
                  style: TextStyle(fontSize: fontSize),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: () => _selectPlace(_recentSearches[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

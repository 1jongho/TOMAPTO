import 'package:flutter/material.dart';
import 'package:tomapto/controllers/search/search_main_controller.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/pages/map/transit.dart';

// 검색 결과 페이지
class SearchResultPage extends StatefulWidget {
  final String searchTerm;
  final String currentOriginPlace; // 현재 출발지
  final String currentDestinationPlace; // 현재 도착지
  final bool isSearchingOrigin; // 출발지 검색인지 도착지 검색인지 구분

  const SearchResultPage({
    super.key,
    required this.searchTerm,
    required this.currentOriginPlace,
    required this.currentDestinationPlace,
    required this.isSearchingOrigin,
  });

  @override
  _SearchResultPageState createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  late SearchMainController _controller;
  List<SearchResult> searchResults = [];
  String sortOption = '내 위치 중심';
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = SearchMainController();
    _initializeAndSearch();
  }

  Future<void> _initializeAndSearch() async {
    try {
      // 컨트롤러 초기화 (위치 정보 등)
      await _controller.initialize();

      // 검색 수행
      await _performSearch(widget.searchTerm);
    } catch (e) {
      setState(() {
        errorMessage = '검색 중 오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 검색 실행
      _controller.searchController.text = query;
      _controller.onSearchChanged(query);

      // 컨트롤러의 상태 변경 감지를 위한 리스너 추가
      _controller.addListener(_onControllerUpdate);

      // 검색이 완료될 때까지 대기 (debounce 시간 + 약간의 여유)
      // 컨트롤러에 리스너를 추가했으므로 자동으로 상태 업데이트됨
    } catch (e) {
      setState(() {
        errorMessage = '검색 중 오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
  }

  // 컨트롤러 상태 변경 시 호출되는 메서드
  void _onControllerUpdate() {
    // 컨트롤러의 상태가 변경되면 위젯 상태도 업데이트
    if (mounted) {
      setState(() {
        isLoading = _controller.isLoading;
        searchResults = _controller.searchResults;
        errorMessage = _controller.errorMessage;
      });

      // 검색 완료되고 결과가 있으면 거리 순으로 정렬
      if (!isLoading && searchResults.isNotEmpty) {
        _sortByDistance();
      }
    }
  }

  void _sortByDistance() {
    setState(() {
      searchResults.sort((a, b) => a.distance.compareTo(b.distance));
    });
  }

  void _toggleFavorite(int index) {
    // 실제로는 즐겨찾기 상태를 저장하는 로직 필요
    setState(() {
      // 현재는 임시로 상태만 토글
      final result = searchResults[index];
      // 여기서는 임의로 반전시키지만, 실제로는 DB에 저장하는 로직 필요
      // 실제 구현에서는 컨트롤러를 통해 DB 업데이트 필요
    });
  }

  // 출발지로 설정하고 길찾기 페이지로 바로 이동하는 메서드
  void _setAsOrigin(SearchResult result) {
    // 기존 도착지 정보를 유지하면서 새로운 출발지 설정
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace: result.name,
              initialDestinationPlace:
                  widget.currentDestinationPlace != '도착지 입력'
                      ? widget.currentDestinationPlace
                      : null,
            ),
      ),
      (route) => false, // 모든 이전 라우트 제거
    );
  }

  // 도착지로 설정하고 길찾기 페이지로 바로 이동하는 메서드
  void _setAsDestination(SearchResult result) {
    // 기존 출발지 정보를 유지하면서 새로운 도착지 설정
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => TransitApp(
              initialOriginPlace:
                  widget.currentOriginPlace != '위치 확인 중...' &&
                          widget.currentOriginPlace != '위치 권한 없음' &&
                          widget.currentOriginPlace != '위치 확인 실패'
                      ? widget.currentOriginPlace
                      : null,
              initialDestinationPlace: result.name,
            ),
      ),
      (route) => false, // 모든 이전 라우트 제거
    );
  }

  // 항목 선택 시 현재 검색 모드에 따라 출발지 또는 도착지로 설정
  void _selectSearchResult(SearchResult result) {
    if (widget.isSearchingOrigin) {
      _setAsOrigin(result);
    } else {
      _setAsDestination(result);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: Column(
          children: [
            _buildAppBar(context),
            _buildSortOptions(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (searchResults.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다. 다른 검색어를 입력해보세요.'));
    }

    return _buildSearchResultsList();
  }

  Widget _buildAppBar(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            height: 50,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_left_rounded,
                    size: 36,
                    color: Color(0xFF363636),
                  ),
                  padding: EdgeInsets.zero, // 패딩 제거하여 정확한 터치 영역 설정
                  constraints: BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),

                Expanded(
                  child: Text(
                    widget.searchTerm,
                    style: const TextStyle(
                      color: Color(0xFF363636),
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.grey,
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 0.6,
          width: double.infinity,
          color: Color(0xFFE2E2E2), // 테마 색상 사용 또는 직접 색상 지정
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildSortButton('내 위치 중심', Icons.arrow_drop_down),
          const SizedBox(width: 10),
          _buildSortButton('거리순', Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Widget _buildSortButton(String text, IconData icon) {
    final isSelected = sortOption == text;
    return InkWell(
      onTap: () {
        setState(() {
          sortOption = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: "Pretendard",
                color: isSelected ? Color(0xFF0771EB) : Color(0xFF363636),
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
              ),
            ),
            Icon(
              icon,
              color: isSelected ? Color(0xFF0771EB) : Color(0xFF363636),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: searchResults.length,
      separatorBuilder:
          (context, index) =>
              const Divider(height: 1, color: Color(0xFFE2E2E2)),
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return GestureDetector(
          onTap: () => _selectSearchResult(result), // 항목 자체를 탭하면 선택 처리
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    result.name,
                                    style: const TextStyle(
                                      fontFamily: "Pretendard",
                                      color: Color(0xFF0771EB),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    result.category.isNotEmpty
                                        ? result.category
                                        : '기타',
                                    style: TextStyle(
                                      fontFamily: "Pretendard",
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${result.distance.toStringAsFixed(1)}km',
                                  style: const TextStyle(
                                    fontFamily: "Pretendard",
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF363636),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    result.address,
                                    style: TextStyle(
                                      fontFamily: "Pretendard",
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _buildActionButton(
                        '도착',
                        Color(0xFF0771EB),
                        Icons.directions,
                        onPressed: () => _setAsDestination(result),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        '출발',
                        Colors.white,
                        Icons.place_rounded,
                        borderColor: Color(0xFF0771EB),
                        textColor: Color(0xFF0771EB),
                        onPressed: () => _setAsOrigin(result),
                      ),

                      const SizedBox(width: 8),
                      _buildSaveButton(
                        '저장',
                        Colors.white,
                        _isFavorite(result.name)
                            ? Icons.star_rounded
                            : Icons.star_rounded,
                        borderColor: Color(0xFFA0A0A0),
                        textColor: Color(0xFF000000),
                        iconColor:
                            _isFavorite(result.name)
                                ? Colors.red
                                : Colors.grey[600]!,
                        onPressed: () => _toggleFavorite(index),
                      ),
                      const Spacer(), // Spacer 위치 변경
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 임시로 즐겨찾기 상태를 확인하는 메서드
  bool _isFavorite(String name) {
    // 실제로는 DB에서 확인하는 로직 필요
    return name.contains('대학교'); // 임시로 대학교가 포함된 경우만 즐겨찾기로 표시
  }

  Widget _buildActionButton(
    String text,
    Color color,
    IconData icon, {
    Color textColor = Colors.white,
    Color borderColor = Colors.transparent,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.6),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    String text,
    Color color,
    IconData icon, {
    Color textColor = Colors.white,
    Color borderColor = Colors.transparent,
    Color iconColor = Colors.grey, // 기본값 설정
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.6),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 2),
              Text(
                text,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

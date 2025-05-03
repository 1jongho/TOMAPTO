import 'package:flutter/material.dart';
import 'package:tomapto/search/search_transit.dart';

class SearchBarWidget extends StatelessWidget {
  final String originPlace;
  final String destinationPlace;
  final Function(String) onOriginChanged;
  final Function(String) onDestinationChanged;
  final VoidCallback onSwapLocations;
  final VoidCallback onClosePressed;

  const SearchBarWidget({
    super.key,
    required this.originPlace,
    required this.destinationPlace,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onSwapLocations,
    required this.onClosePressed,
  });

  @override
  Widget build(BuildContext context) {
    // 화면 크기 가져오기
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final bool isSmallScreen = width < 360;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    // 반응형 크기 계산
    final double searchAreaPadding = width * 0.04; // 화면 너비의 4%
    final double iconSize = isSmallScreen ? 22.0 : 28.0; // 작은 화면에서는 작은 아이콘

    return Container(
      color: Color(0xFFFB233B),
      padding: EdgeInsets.only(
        top: statusBarHeight + 8, // 상태바 높이 + 추가 패딩
        bottom: width * 0.035, // 화면 너비에 따른 패딩
        left: width * 0.02,
        right: width * 0.02,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 최대 너비 계산
          final maxWidth = constraints.maxWidth;

          return Stack(
            children: [
              // 검색바 영역
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 화살표 위아래 아이콘
                  Container(
                    margin: EdgeInsets.only(left: maxWidth * 0.000001),
                    child: IconButton(
                      icon: const Icon(Icons.swap_vert, color: Colors.white),
                      onPressed: onSwapLocations,
                      iconSize: iconSize,
                    ),
                  ),

                  // 검색바 컨테이너
                  Expanded(
                    child: Column(
                      children: [
                        // 출발지 검색창
                        GestureDetector(
                          onTap: () async {
                            // 출발지 검색 페이지로 이동
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const SearchPage(
                                      mode: SearchMode.origin,
                                    ),
                              ),
                            );

                            // 검색 결과가 있으면 출발지 업데이트
                            if (result != null) {
                              onOriginChanged(result as String);
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.only(
                              top: maxWidth * 0.0001,
                              bottom: 0,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFFB5063),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: searchAreaPadding,
                                vertical: maxWidth * 0.035,
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      originPlace,
                                      style: TextStyle(
                                        fontFamily: "Pretendard",
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 목적지 검색창
                        GestureDetector(
                          onTap: () async {
                            // 도착지 검색 페이지로 이동
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const SearchPage(
                                      mode: SearchMode.destination,
                                    ),
                              ),
                            );

                            // 검색 결과가 있으면 도착지 업데이트
                            if (result != null) {
                              onDestinationChanged(result as String);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 1, bottom: 0),
                            decoration: BoxDecoration(
                              color: Color(0xFFFB5063),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: searchAreaPadding,
                                vertical: maxWidth * 0.035,
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      destinationPlace,
                                      style: TextStyle(
                                        fontFamily: "Pretendard",
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // X 버튼 자리 공간 확보
                  SizedBox(width: iconSize + 20),
                ],
              ),

              // X 버튼을 절대 위치로 배치
              Positioned(
                top: maxWidth * 0.0000009,
                right: -5,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClosePressed,
                  iconSize: iconSize,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

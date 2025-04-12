import 'package:flutter/material.dart';
import 'package:tomapto/styles/app_styles.dart';
import 'package:tomapto/search/search_transit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대중교통 길찾기 앱',
      theme: AppStyles.theme,
      home: const TransitApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TransitApp extends StatefulWidget {
  const TransitApp({super.key});

  @override
  State<TransitApp> createState() => _TransitAppState();
}

class _TransitAppState extends State<TransitApp> {
  int _selectedIndex = 0;

  // 출발지와 도착지를 저장할 변수
  String _originPlace = '강원 강릉시 포남동';
  String _destinationPlace = '도착지 입력';

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
    final double routeItemPadding = width * 0.035; // 화면 너비의 3.5%
    final double fontSize = isSmallScreen ? 12.0 : 14.0; // 작은 화면에서는 작은 폰트

    return Scaffold(
      backgroundColor: Colors.white, // 배경색을 흰색으로 설정
      body: Column(
        children: [
          // 상단 빨간색 배경의 검색창
          Container(
            color: AppStyles.primaryColor,
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
                            icon: const Icon(
                              Icons.swap_vert,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              // 출발지와 도착지 교환
                              setState(() {
                                final temp = _originPlace;
                                _originPlace = _destinationPlace;
                                _destinationPlace = temp;
                              });
                            },
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
                                    setState(() {
                                      _originPlace = result as String;
                                    });
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: maxWidth * 0.0001,
                                    bottom: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppStyles.searchBarColor,
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
                                            _originPlace,
                                            style: AppStyles.searchTextStyle,
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
                                    setState(() {
                                      _destinationPlace = result as String;
                                    });
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    top: 1,
                                    bottom: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppStyles.searchBarColor,
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
                                            _destinationPlace,
                                            style: AppStyles.searchTextStyle,
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
                        onPressed: () {
                          // 검색 초기화 또는 뒤로가기
                        },
                        iconSize: iconSize,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 대중교통 옵션 선택 바 - 그림자 추가
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTransitOption(
                  0,
                  Icons.directions_subway,
                  '대중교통',
                  iconSize: iconSize,
                ),
                _buildTransitOption(
                  1,
                  Icons.directions_car,
                  '자동차',
                  iconSize: iconSize,
                ),
                _buildTransitOption(
                  2,
                  Icons.directions_walk,
                  '도보',
                  iconSize: iconSize,
                ),
              ],
            ),
          ),

          // 시간 및 날짜 선택 바 - 그림자 추가
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.04,
              vertical: width * 0.025,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: Colors.white)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('오늘 오후 9:41 출발', style: TextStyle(fontSize: fontSize)),
                    Icon(Icons.keyboard_arrow_down, size: fontSize + 4),
                  ],
                ),
                Row(
                  children: [
                    Text('추천순', style: TextStyle(fontSize: fontSize)),
                    Icon(Icons.keyboard_arrow_down, size: fontSize + 4),
                  ],
                ),
              ],
            ),
          ),

          // 경로 목록 - 배경색을 흰색으로 설정
          Expanded(
            child: Container(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    padding: EdgeInsets.only(top: width * 0.02),
                    children: [
                      _buildRouteItem(
                        '14분',
                        '도보 4분',
                        '카드 1,530원',
                        '225',
                        '교보생명 정류장',
                        constraints.maxWidth,
                        fontSize,
                      ),
                      _buildRouteItem(
                        '9분',
                        '도보 4분',
                        '카드 1,530원',
                        '104, 104-1',
                        '교보생명 정류장',
                        constraints.maxWidth,
                        fontSize,
                      ),
                      _buildRouteItem(
                        '12분',
                        '도보 4분',
                        '카드 1,530원',
                        '330, 302',
                        '교보생명 정류장',
                        constraints.maxWidth,
                        fontSize,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitOption(
    int index,
    IconData icon,
    String label, {
    double iconSize = 28.0,
  }) {
    // 텍스트 크기는 아이콘 크기에 비례하게 조정
    final double textSize = iconSize * 0.42;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: iconSize * 0.42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    _selectedIndex == index
                        ? AppStyles.primaryColor
                        : Colors.grey,
                size: iconSize,
              ),
              SizedBox(height: iconSize * 0.14),
              Text(
                label,
                style: TextStyle(
                  color:
                      _selectedIndex == index
                          ? AppStyles.primaryColor
                          : Colors.grey,
                  fontSize: textSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteItem(
    String time,
    String walkTime,
    String price,
    String busNumber,
    String stationName,
    double maxWidth,
    double fontSize,
  ) {
    // 화면 너비에 따라 마진과 패딩 계산
    final double horizontalMargin = maxWidth * 0.04;
    final double verticalMargin = maxWidth * 0.02;
    final double containerPadding = maxWidth * 0.035;

    // 아이콘과 텍스트 크기 계산
    final double iconSize = maxWidth < 360 ? 14.0 : 16.0;
    final double timeTextSize = AppStyles.routeTimeStyle.fontSize ?? 24.0;
    final double adjustedTimeTextSize =
        maxWidth < 360 ? timeTextSize * 0.8 : timeTextSize;

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: verticalMargin,
        horizontal: horizontalMargin,
      ),
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // 그림자 진하게 설정
            blurRadius: 12, // 블러 증가
            spreadRadius: 1, // 그림자 확산
            offset: const Offset(0, 3), // 약간 더 아래로
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                time,
                style: AppStyles.routeTimeStyle.copyWith(
                  fontSize: adjustedTimeTextSize,
                ),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: verticalMargin * 0.5),
          Row(
            children: [
              Text(
                walkTime,
                style: TextStyle(fontSize: fontSize, color: Colors.black54),
              ),
              SizedBox(width: horizontalMargin * 0.25),
              Text(
                price,
                style: TextStyle(fontSize: fontSize, color: Colors.black54),
              ),
            ],
          ),
          SizedBox(height: verticalMargin * 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 버스 아이콘
              Container(
                padding: EdgeInsets.all(maxWidth * 0.015),
                decoration: BoxDecoration(
                  color: AppStyles.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              SizedBox(width: horizontalMargin * 0.4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '버스시장',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize + 1,
                          ),
                        ),
                        SizedBox(width: horizontalMargin * 0.2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: maxWidth * 0.02,
                            vertical: maxWidth * 0.008,
                          ),
                          decoration: BoxDecoration(
                            color: AppStyles.busNumberColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            busNumber,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSize - 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: verticalMargin * 3),
                    // 직선
                    Container(
                      width: 1,
                      height: maxWidth * 0.07,
                      color: Colors.grey.withOpacity(0.3),
                      margin: EdgeInsets.only(left: maxWidth * 0.02),
                    ),
                    SizedBox(height: verticalMargin),
                    // 도착지
                    Row(
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.circle,
                              size: iconSize * 0.5,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        SizedBox(width: horizontalMargin * 0.4),
                        Expanded(
                          child: Text(
                            stationName,
                            style: TextStyle(fontSize: fontSize + 1),
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
        ],
      ),
    );
  }
}

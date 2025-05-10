import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SearchMainController extends ChangeNotifier {
  // 검색어 컨트롤러
  final TextEditingController searchController = TextEditingController();
  // 포커스 노드
  final FocusNode searchFocusNode = FocusNode();

  // 검색 딜레이 타이머 (API 호출 최적화)
  Timer? _debounce;

  // 최근 검색 기록 (실제로는 DB나 SharedPreferences에서 가져옴)
  List<SearchItem> recentSearches = [
    SearchItem('테라로사 경포호수점', '24.12.31'),
    SearchItem('장보는강아지와고양이 강릉점', '24.12.31'),
  ];

  // 검색 결과
  List<SearchResult> searchResults = [];

  // 검색 진행 중 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners(); // 상태 변경 시 리스너에게 알림
  }

  // 검색 오류 메시지
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  set errorMessage(String? value) {
    _errorMessage = value;
    notifyListeners(); // 상태 변경 시 리스너에게 알림
  }

  // 사용자 현재 위치
  Position? userPosition;

  // 네이버 API 키 설정 (dotenv 사용)
  String get _clientId => dotenv.env['NAVER_DEV_KEY'] ?? '';
  String get _clientSecret => dotenv.env['NAVER_DEV_SECRET_KEY'] ?? '';

  // 네이버 Maps API 키 설정 (dotenv 사용)
  String get _mapClientId => dotenv.env['NAVER_API_KEY'] ?? '';
  String get _mapClientSecret => dotenv.env['NAVER_SECRET_KEY'] ?? '';

  // 네이버 지역 검색 API URL
  final String _baseUrl = 'https://openapi.naver.com/v1/search/local.json';

  // 네이버 Directions API URL
  final String _directionsUrl =
      'https://naveropenapi.apigw.ntruss.com/map-direction/v1/driving';

  // 초기화 메서드 (initState에서 호출)
  Future<void> initialize() async {
    // 사용자 위치 가져오기 시도
    try {
      userPosition = await getCurrentPosition();
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 키보드 포커스 요청 메서드
  void requestFocus(BuildContext context) {
    // 약간의 딜레이 후 포커스 요청 (화면 전환 후 작동을 위해)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (searchFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(searchFocusNode);
      }
    });
  }

  // 검색어 변경 시 처리할 메서드
  void onSearchChanged(String query) {
    // 디바운스 처리 (타이핑 중에 API 요청이 너무 많이 발생하는 것을 방지)
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      searchResults = [];
      errorMessage = null;
      notifyListeners(); // 상태 변경 리스너에게 알림
      return;
    }

    // 검색 시작 상태 설정
    isLoading = true;

    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        errorMessage = null;

        // 네이버 API로 검색 수행
        final naverResults = await searchPlaces(query);

        // 검색 결과 변환
        final updatedResults =
            naverResults.map((naverResult) {
              // 사용자 위치가 있으면 거리 계산
              double distance = 0.0;
              if (userPosition != null) {
                distance = calculateDistance(
                  userPosition!.latitude,
                  userPosition!.longitude,
                  naverResult.mapy, // 위도
                  naverResult.mapx, // 경도
                );
              }

              return SearchResult(
                naverResult.title,
                naverResult.address,
                distance,
                category: _extractCategory(naverResult.category),
                mapx: naverResult.mapx,
                mapy: naverResult.mapy,
              );
            }).toList();

        // 상태 업데이트
        searchResults = updatedResults;
        isLoading = false;

        // 새로 notifyListeners 호출하지 않아도 됨 - isLoading의 setter에서 이미 호출됨
      } catch (e) {
        searchResults = [];
        isLoading = false;
        errorMessage = '검색 중 오류가 발생했습니다: $e';
        // 새로 notifyListeners 호출하지 않아도 됨 - errorMessage의 setter에서 이미 호출됨
      }
    });
  }

  // 카테고리 문자열에서 주요 카테고리 추출
  String _extractCategory(String fullCategory) {
    // 네이버 API에서는 "음식점 > 카페 > 커피전문점" 형태로 제공됨
    final categories = fullCategory.split('>');
    if (categories.length > 1) {
      return categories[1].trim(); // 두 번째 카테고리 반환 (더 구체적인 정보)
    }
    return categories.isNotEmpty ? categories[0].trim() : '';
  }

  Future<List<NaverSearchResult>> searchPlaces(
    String query, {
    int display = 10,
  }) async {
    try {
      if (_clientId.isEmpty || _clientSecret.isEmpty) {
        throw Exception('네이버 API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      // 한글 인코딩 처리 개선
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse('$_baseUrl?query=$encodedQuery&display=$display');

      print('요청 URL: $url');
      print('사용 중인 API 키: $_clientId (길이: ${_clientId.length})');

      final response = await http.get(
        url,
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
        },
      );

      print('응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes); // UTF-8 디코딩
        print('응답 바디: $responseBody');

        final Map<String, dynamic> data = json.decode(responseBody);

        // 응답 구조 확인
        print('total: ${data['total']}');
        print('start: ${data['start']}');
        print('display: ${data['display']}');

        if (data['total'] == 0 ||
            !data.containsKey('items') ||
            data['items'].isEmpty) {
          print('검색 결과가 없습니다.');
          return [];
        }

        final List<dynamic> items = data['items'];
        print('검색 결과 수: ${items.length}');

        // 첫 번째 아이템 출력
        if (items.isNotEmpty) {
          print('첫 번째 아이템: ${items[0]}');
        }

        final results =
            items
                .map<NaverSearchResult>(
                  (item) => NaverSearchResult.fromJson(item),
                )
                .toList();
        print('변환된 결과 수: ${results.length}');
        return results;
      } else {
        print('API 요청 실패: ${response.statusCode}');
        print('응답 바디: ${response.body}');
        throw Exception('API 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('검색 중 오류 발생: $e');
      throw Exception('검색 중 오류 발생: $e');
    }
  }

  // 네이버 Directions API 호출 (경로 안내)
  Future<Map<String, dynamic>> getDirections({
    required double startLat,
    required double startLng,
    required double goalLat,
    required double goalLng,
    String option =
        'trafast', // 옵션: trafast(빠른길), tracomfort(편한길), traoptimal(최적), traavoidtoll(무료우선)
  }) async {
    try {
      // mapClientId나 mapClientSecret이 비어있으면 예외 처리
      if (_mapClientId.isEmpty || _mapClientSecret.isEmpty) {
        throw Exception('네이버 Maps API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      // 출발지와 목적지 좌표 포맷팅
      final start = '$startLng,$startLat';
      final goal = '$goalLng,$goalLat';

      final url = Uri.parse(
        '$_directionsUrl?start=$start&goal=$goal&option=$option',
      );

      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _mapClientId,
          'X-NCP-APIGW-API-KEY': _mapClientSecret,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else {
        throw Exception('경로 안내 API 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('경로 안내 중 오류 발생: $e');
    }
  }

  // 경로 거리와 시간 계산
  Map<String, dynamic> parseDirectionsResult(
    Map<String, dynamic> directionsData,
  ) {
    try {
      final route = directionsData['route'];
      if (route == null ||
          route['trafast'] == null ||
          route['trafast'].isEmpty) {
        throw Exception('경로 정보가 없습니다.');
      }

      final path = route['trafast'][0];
      final summary = path['summary'];

      return {
        'distance': summary['distance'] / 1000, // 미터를 킬로미터로 변환
        'duration': summary['duration'] / 60000, // 밀리초를 분으로 변환
        'tollFare': summary['tollFare'],
        'fuelPrice': summary['fuelPrice'],
        'path': path['path'], // 경로 좌표 목록
      };
    } catch (e) {
      throw Exception('경로 정보 파싱 오류: $e');
    }
  }

  // 위치 권한 요청 및 확인
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스가 활성화되어 있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 권한 요청
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // 두 지점 간의 거리 계산 (Haversine 공식 사용)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  // 최근 검색어에 추가
  void addToRecentSearches(String name) {
    // 현재 날짜 포맷팅 (YY.MM.DD 형식)
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().substring(2)}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    // 동일한 검색어가 있는지 확인
    final existingIndex = recentSearches.indexWhere(
      (item) => item.name == name,
    );
    if (existingIndex != -1) {
      // 이미 있으면 삭제
      recentSearches.removeAt(existingIndex);
    }

    // 새 검색어를 최상단에 추가
    recentSearches.insert(0, SearchItem(name, dateStr));
    notifyListeners(); // 상태 변경 리스너에게 알림

    // 여기서 SharedPreferences나 로컬 DB에 저장하는 코드 추가
    // 예: _saveRecentSearches();
  }

  // 최근 검색어 삭제
  void removeRecentSearch(int index) {
    if (index >= 0 && index < recentSearches.length) {
      recentSearches.removeAt(index);
      notifyListeners(); // 상태 변경 리스너에게 알림
      // DB에 저장하는 코드 추가
    }
  }

  // 항목 클릭 시 처리할 메서드
  void onItemSelected(BuildContext context, SearchResult result) {
    // 선택한 항목을 최근 검색어에 추가
    addToRecentSearches(result.name);

    // 선택한 항목을 메인 화면으로 전달하고 현재 화면 닫기
    Navigator.pop(context, result);
  }

  // 뒤로가기 처리
  void onBackPressed(BuildContext context) {
    Navigator.pop(context);
  }

  // 리소스 해제
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

// 최근 검색 항목 클래스
class SearchItem {
  final String name;
  final String date;

  SearchItem(this.name, this.date);
}

// 검색 결과 항목 클래스
class SearchResult {
  final String name;
  final String address;
  final double distance; // km 단위
  final String category; // 카테고리 정보
  final double mapx; // X 좌표 (경도)
  final double mapy; // Y 좌표 (위도)

  SearchResult(
    this.name,
    this.address,
    this.distance, {
    this.category = '',
    this.mapx = 0,
    this.mapy = 0,
  });
}

class NaverSearchResult {
  final String title; // 장소명
  final String address; // 주소
  final String roadAddress; // 도로명 주소
  final double mapx; // X 좌표 (경도)
  final double mapy; // Y 좌표 (위도)
  final String category; // 카테고리

  NaverSearchResult({
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.mapx,
    required this.mapy,
    required this.category,
  });

  factory NaverSearchResult.fromJson(Map<String, dynamic> json) {
    try {
      String titleText = json['title'] ?? '';
      // HTML 태그 제거
      titleText = titleText.replaceAll(RegExp(r'<[^>]*>'), '');

      // mapx와 mapy 값 처리 개선
      double mapxValue;
      double mapyValue;

      try {
        mapxValue = double.parse(json['mapx'] ?? '0');
      } catch (e) {
        print('mapx 파싱 오류: ${json['mapx']}');
        mapxValue = 0;
      }

      try {
        mapyValue = double.parse(json['mapy'] ?? '0');
      } catch (e) {
        print('mapy 파싱 오류: ${json['mapy']}');
        mapyValue = 0;
      }

      return NaverSearchResult(
        title: titleText,
        address: json['address'] ?? '',
        roadAddress: json['roadAddress'] ?? '',
        mapx: mapxValue,
        mapy: mapyValue,
        category: json['category'] ?? '',
      );
    } catch (e) {
      print('NaverSearchResult 생성 중 오류: $e');
      print('원본 데이터: $json');
      // 오류 발생 시 기본값 반환
      return NaverSearchResult(
        title: '오류 발생',
        address: '',
        roadAddress: '',
        mapx: 0,
        mapy: 0,
        category: '',
      );
    }
  }
}

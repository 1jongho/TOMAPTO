import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RouteData {
  final String totalTime;
  final String walkTime;
  final String price;
  final String busNumber;
  final String stationName;

  RouteData({
    required this.totalTime,
    required this.walkTime,
    required this.price,
    required this.busNumber,
    required this.stationName,
  });
}

class RouteController {
  // API 키 캐싱
  String? _cachedApiKey;
  String? _cachedSecretKey;
  String? _cachedApiUrl;

  // 마지막으로 계산된 경로 캐싱
  List<RouteData>? _cachedPublicTransportRoutes;
  Map<String, dynamic>? _cachedCarRoute;
  Map<String, dynamic>? _cachedWalkRoute;

  Future<void> testApiConnection() async {
    bool keysInitialized = await _initApiKeys();
    print('API 키 초기화 결과: $keysInitialized');
    print('API URL: $_cachedApiUrl');
    print('API Key (처음 5자): ${_cachedApiKey?.substring(0, 5)}...');
    print('Secret Key (처음 5자): ${_cachedSecretKey?.substring(0, 5)}...');
  }

  // API 키 초기화
  Future<bool> _initApiKeys() async {
    if (_cachedApiKey != null &&
        _cachedSecretKey != null &&
        _cachedApiUrl != null) {
      return true;
    }

    _cachedApiKey = dotenv.env['NAVER_API_KEY'];
    _cachedSecretKey = dotenv.env['NAVER_SECRET_KEY'];
    _cachedApiUrl = dotenv.env['NAVER_DIRECTION5_API_URL'];

    if (_cachedApiKey == null ||
        _cachedSecretKey == null ||
        _cachedApiUrl == null) {
      print('네이버 API 키가 설정되지 않았습니다.');
      return false;
    }
    return true;
  }

  // 대중교통 경로 검색
  Future<List<RouteData>> searchPublicTransportRoutes(
    String start,
    String end,
  ) async {
    // 이미 캐시된 결과가 있으면 반환
    if (_cachedPublicTransportRoutes != null) {
      return _cachedPublicTransportRoutes!;
    }

    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      // 실제 API 호출 실패 시, 예시 데이터 반환
      return _getMockPublicTransportData();
    }

    try {
      // 실제로는 네이버 경로 검색 API 호출 필요
      // 여기서는 예시 코드만 작성
      /*
      final url = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-direction/v1/transit?'
        'start=${Uri.encodeComponent(start)}&goal=${Uri.encodeComponent(end)}'
      );
      
      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
          'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 응답 파싱 로직 필요
      }
      */

      // 지금은 예시 데이터 반환
      _cachedPublicTransportRoutes = _getMockPublicTransportData();
      return _cachedPublicTransportRoutes!;
    } catch (e) {
      print('대중교통 경로 검색 오류: $e');
      return _getMockPublicTransportData();
    }
  }

  // 자동차 경로 검색
  Future<Map<String, dynamic>> searchCarRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    // 이미 캐시된 결과가 있으면 반환
    if (_cachedCarRoute != null) {
      return _cachedCarRoute!;
    }

    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return _getMockCarRouteData(start, end);
    }

    try {
      final url = Uri.parse(
        '$_cachedApiUrl/driving?'
        'start=${start.longitude},${start.latitude}&'
        'goal=${end.longitude},${end.latitude}&'
        'option=trafast',
      );

      print('API URL: $url'); // URL 로깅 추가
      print('API Key ID: $_cachedApiKey'); // API 키 확인

      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
          'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
        },
      );

      print('응답 상태 코드: ${response.statusCode}'); // 상태 코드 로깅
      print('응답 내용: ${response.body}'); // 응답 내용 로깅

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // API 응답 파싱
        if (data['route'] != null && data['route']['trafast'] != null) {
          final route = data['route']['trafast'][0];

          // 경로 좌표 추출
          final List<NLatLng> pathCoordinates = [];
          if (route['path'] != null) {
            final path = route['path'] as List;
            // 응답 구조 디버깅
            print('path 길이: ${path.length}');
            print('첫 번째 path 요소: ${path[0]}');

            // path가 1차원 배열인지 2차원 배열인지 확인
            if (path.isNotEmpty && path[0] is! List) {
              // 1차원 배열인 경우
              for (int i = 0; i < path.length; i += 2) {
                if (i + 1 < path.length) {
                  double longitude = (path[i] as num).toDouble();
                  double latitude = (path[i + 1] as num).toDouble();
                  pathCoordinates.add(NLatLng(latitude, longitude));
                }
              }
            } else {
              // 2차원 배열인 경우 [longitude, latitude] 형태
              for (var point in path) {
                if (point is List && point.length >= 2) {
                  double longitude = (point[0] as num).toDouble();
                  double latitude = (point[1] as num).toDouble();
                  pathCoordinates.add(NLatLng(latitude, longitude));
                }
              }
            }
          }

          _cachedCarRoute = {
            'routes': [
              {'path': pathCoordinates, 'summary': route['summary']},
            ],
            'distance': route['summary']?['distance'] ?? 0,
            'duration': route['summary']?['duration'] ?? 0,
            'toll': route['summary']?['tollFare'] ?? 0,
          };
          return _cachedCarRoute!;
        }
      }

      print('경로 검색 실패: ${response.statusCode} - ${response.body}');
      return _getMockCarRouteData(start, end);
    } catch (e) {
      print('경로 검색 오류: $e');
      return _getMockCarRouteData(start, end);
    }
  }

  // 도보 경로 검색
  Future<Map<String, dynamic>> searchWalkRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    // 이미 캐시된 결과가 있으면 반환
    if (_cachedWalkRoute != null) {
      return _cachedWalkRoute!;
    }

    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return _getMockWalkRouteData(start, end);
    }

    try {
      final url = Uri.parse(
        // 'pedestrian' 대신 'driving'으로 시도해보세요
        '$_cachedApiUrl/driving?'
        'start=${start.longitude},${start.latitude}&'
        'goal=${end.longitude},${end.latitude}&'
        'option=optimal', // option도 추가해보세요
      );

      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
          'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
        },
      );

      // searchWalkRoute 메서드에서
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 응답 구조 확인
        print('응답 구조: ${data['route']?.keys}');

        // traoptimal을 체크하도록 수정
        if (data['route'] != null) {
          Map<String, dynamic>? route;

          // 우선순위: trafast > traoptimal
          if (data['route']['trafast'] != null) {
            route = data['route']['trafast'][0];
            print('trafast 경로 사용');
          } else if (data['route']['traoptimal'] != null) {
            route = data['route']['traoptimal'][0];
            print('traoptimal 경로 사용');
          }

          if (route != null) {
            // 경로 좌표 추출 (이전과 동일한 로직)
            final List<NLatLng> pathCoordinates = [];
            if (route['path'] != null) {
              final path = route['path'] as List;
              print('path 길이: ${path.length}');
              print('첫 번째 path 요소: ${path[0]}');

              if (path.isNotEmpty && path[0] is! List) {
                // 1차원 배열인 경우
                for (int i = 0; i < path.length; i += 2) {
                  if (i + 1 < path.length) {
                    double longitude = (path[i] as num).toDouble();
                    double latitude = (path[i + 1] as num).toDouble();
                    pathCoordinates.add(NLatLng(latitude, longitude));
                  }
                }
              } else {
                // 2차원 배열인 경우
                for (var point in path) {
                  if (point is List && point.length >= 2) {
                    double longitude = (point[0] as num).toDouble();
                    double latitude = (point[1] as num).toDouble();
                    pathCoordinates.add(NLatLng(latitude, longitude));
                  }
                }
              }
            }

            _cachedWalkRoute = {
              'routes': [
                {'path': pathCoordinates, 'summary': route['summary']},
              ],
              'distance': route['summary']?['distance'] ?? 0,
              'duration': route['summary']?['duration'] ?? 0,
            };
            return _cachedWalkRoute!;
          }
        }

        print('예상된 경로 타입을 찾을 수 없음');
        return _getMockWalkRouteData(start, end);
      }

      print('도보 경로 검색 실패: ${response.statusCode} - ${response.body}');
      return _getMockWalkRouteData(start, end);
    } catch (e) {
      print('도보 경로 검색 오류: $e');
      return _getMockWalkRouteData(start, end);
    }
  }

  // 캐시 무효화 (출발지/도착지 변경 시 호출)
  void invalidateCache() {
    _cachedPublicTransportRoutes = null;
    _cachedCarRoute = null;
    _cachedWalkRoute = null;
  }

  // 예시 대중교통 데이터
  List<RouteData> _getMockPublicTransportData() {
    return [
      RouteData(
        totalTime: '14분',
        walkTime: '도보 4분',
        price: '카드 1,530원',
        busNumber: '225',
        stationName: '교보생명 정류장',
      ),
      RouteData(
        totalTime: '9분',
        walkTime: '도보 4분',
        price: '카드 1,530원',
        busNumber: '104, 104-1',
        stationName: '교보생명 정류장',
      ),
      RouteData(
        totalTime: '12분',
        walkTime: '도보 4분',
        price: '카드 1,530원',
        busNumber: '330, 302',
        stationName: '교보생명 정류장',
      ),
    ];
  }

  // 예시 자동차 경로 데이터
  Map<String, dynamic> _getMockCarRouteData(NLatLng start, NLatLng end) {
    return {
      'distance': 5000, // 미터 단위
      'duration': 900, // 초 단위 (15분)
      'toll': 0, // 통행료
      'routes': [
        {
          'path': [
            start,
            NLatLng(start.latitude + 0.005, start.longitude + 0.003),
            NLatLng(start.latitude + 0.010, start.longitude + 0.008),
            NLatLng(start.latitude + 0.015, start.longitude + 0.012),
            end,
          ],
          'segments': [
            {'name': '강남대로', 'distance': 2000, 'duration': 360},
            {'name': '테헤란로', 'distance': 3000, 'duration': 540},
          ],
        },
      ],
    };
  }

  // 예시 도보 경로 데이터
  Map<String, dynamic> _getMockWalkRouteData(NLatLng start, NLatLng end) {
    return {
      'distance': 1200, // 미터 단위
      'duration': 840, // 초 단위 (14분)
      'routes': [
        {
          'path': [
            start,
            NLatLng(start.latitude + 0.001, start.longitude + 0.002),
            NLatLng(start.latitude + 0.002, start.longitude + 0.003),
            NLatLng(start.latitude + 0.003, start.longitude + 0.004),
            end,
          ],
          'segments': [
            {'name': '강남대로', 'distance': 500, 'duration': 350},
            {'name': '역삼로', 'distance': 700, 'duration': 490},
          ],
        },
      ],
    };
  }
}

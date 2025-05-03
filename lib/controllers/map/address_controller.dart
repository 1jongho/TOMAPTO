import 'dart:convert';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddressController {
  // Dio 인스턴스
  late final Dio _dio;

  // API 키 캐싱
  String? _cachedApiKey;
  String? _cachedSecretKey;

  // 생성자에서 Dio 초기화
  AddressController() {
    _dio = Dio(
      BaseOptions(
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json', 'Accept-Charset': 'utf-8'},
      ),
    );
  }

  // API 키 초기화
  Future<bool> _initApiKeys() async {
    if (_cachedApiKey != null && _cachedSecretKey != null) {
      return true;
    }

    _cachedApiKey = dotenv.env['NAVER_API_KEY'];
    _cachedSecretKey = dotenv.env['NAVER_SECRET_KEY'];

    if (_cachedApiKey == null || _cachedSecretKey == null) {
      print('네이버 API 키가 설정되지 않았습니다.');
      return false;
    }
    return true;
  }

  // 좌표를 주소로 변환 (역지오코딩)
  Future<String> getAddressFromLatLng(NLatLng position) async {
    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return '서울특별시 강남구'; // 기본 주소
    }

    final url =
        'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc?'
        'coords=${position.longitude},${position.latitude}&output=json';

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
            'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 디버깅: 전체 응답 로깅 (개발중에만 사용)
        print('API 응답: ${json.encode(data)}');

        if (data['results'] != null && data['results'].isNotEmpty) {
          String address = _parseAddress(data);

          if (address.isNotEmpty && address != '주소를 찾을 수 없음') {
            print('주소 변환 성공: $address');
            return address;
          }
        }
      }

      print('주소 변환 실패: ${response.statusCode}');
      return '강원특별자치도 강릉시'; // 변환 실패 시 기본 주소
    } catch (e) {
      print('주소 변환 오류: $e');
      return '강원특별자치도 강릉시'; // 오류 발생 시 기본 주소
    }
  }

  // 네이버 역지오코딩 API 응답에서 주소 파싱
  String _parseAddress(Map<String, dynamic> response) {
    try {
      if (!response.containsKey('results') ||
          response['results'] == null ||
          response['results'].isEmpty) {
        return '주소를 찾을 수 없음';
      }

      // results를 가져옴
      final results = response['results'];

      // 디버깅을 위해 각 유형별 응답 구조 확인
      print('주소 파싱 시작...');

      // 도로명 주소 찾기 (가장 상세한 주소)
      var roadAddrResult;
      for (var result in results) {
        if (result['name'] == 'roadaddr') {
          roadAddrResult = result;
          print('도로명 주소 찾음: ${json.encode(roadAddrResult)}');
          break;
        }
      }

      // 도로명 주소가 있으면 사용
      if (roadAddrResult != null) {
        try {
          final region = roadAddrResult['region'];
          final area1 = region['area1']['name']; // 시/도
          final area2 = region['area2']['name']; // 구/군
          final area3 = region['area3']['name']; // 동/읍/면

          // area4가 없을 수 있으므로 안전하게 접근
          final area4 =
              region['area4'] != null ? (region['area4']['name'] ?? '') : '';

          // 도로명 관련 정보
          String roadName = '';
          String buildingNumber = '';
          String buildingNumber2 = '';

          if (roadAddrResult.containsKey('land')) {
            final land = roadAddrResult['land'];
            roadName = land['name'] ?? '';
            buildingNumber = land['number1'] ?? '';
            buildingNumber2 = land['number2'] ?? '';
          }

          // 추가 정보 (동/호수)
          String dongName = '';
          if (roadAddrResult.containsKey('addition0')) {
            final addition0 = roadAddrResult['addition0'];
            dongName = addition0['value'] ?? '';
          }

          // 모든 주소 부분 조합
          String fullAddress = '$area1 $area2 $area3';

          // 리/통이 있으면 추가
          if (area4.isNotEmpty) {
            fullAddress += ' $area4';
          }

          // 도로명이 있으면 추가
          if (roadName.isNotEmpty) {
            fullAddress += ' $roadName';

            // 건물번호가 있으면 추가
            if (buildingNumber.isNotEmpty) {
              fullAddress += ' $buildingNumber';

              // 추가 번호가 있으면 추가
              if (buildingNumber2.isNotEmpty) {
                fullAddress += '-$buildingNumber2';
              }
            }
          }

          // 동/호수 정보가 있으면 추가
          if (dongName.isNotEmpty) {
            fullAddress += ' ($dongName)';
          }

          print('최종 도로명 주소: $fullAddress');
          return fullAddress;
        } catch (e) {
          print('도로명 주소 파싱 오류: $e');
          // 도로명 주소 파싱에 실패하면 다음 방식으로 진행
        }
      }

      // 법정동 주소 찾기
      var legalcodeResult;
      for (var result in results) {
        if (result['name'] == 'legalcode') {
          legalcodeResult = result;
          print('법정동 주소 찾음: ${json.encode(legalcodeResult)}');
          break;
        }
      }

      if (legalcodeResult != null) {
        try {
          final region = legalcodeResult['region'];
          final area1 = region['area1']['name']; // 시/도
          final area2 = region['area2']['name']; // 구/군
          final area3 = region['area3']['name']; // 동/읍/면

          // area4가 없을 수 있으므로 안전하게 접근
          final area4 =
              region['area4'] != null ? (region['area4']['name'] ?? '') : '';

          // 토지 정보
          String number1 = '';
          String number2 = '';

          if (legalcodeResult.containsKey('land')) {
            final land = legalcodeResult['land'];
            number1 = land['number1'] ?? '';
            number2 = land['number2'] ?? '';
          }

          // 모든 주소 부분 조합
          String fullAddress = '$area1 $area2 $area3';

          // 리/통이 있으면 추가
          if (area4.isNotEmpty) {
            fullAddress += ' $area4';
          }

          // 지번이 있으면 추가
          if (number1.isNotEmpty) {
            fullAddress += ' $number1';

            // 추가 번호가 있으면 추가
            if (number2.isNotEmpty && number2 != '0') {
              fullAddress += '-$number2';
            }
          }

          print('최종 법정동 주소: $fullAddress');
          return fullAddress;
        } catch (e) {
          print('법정동 주소 파싱 오류: $e');
        }
      }

      // 행정동 주소 찾기
      var admcodeResult;
      for (var result in results) {
        if (result['name'] == 'admcode') {
          admcodeResult = result;
          print('행정동 주소 찾음: ${json.encode(admcodeResult)}');
          break;
        }
      }

      if (admcodeResult != null) {
        try {
          final region = admcodeResult['region'];
          final area1 = region['area1']['name']; // 시/도
          final area2 = region['area2']['name']; // 구/군
          final area3 = region['area3']['name']; // 동/읍/면

          // area4가 없을 수 있으므로 안전하게 접근
          final area4 =
              region['area4'] != null ? (region['area4']['name'] ?? '') : '';

          String fullAddress = '$area1 $area2 $area3';
          if (area4.isNotEmpty) {
            fullAddress += ' $area4';
          }

          print('최종 행정동 주소: $fullAddress');
          return fullAddress;
        } catch (e) {
          print('행정동 주소 파싱 오류: $e');
        }
      }

      // 다른 형식의 주소가 있는지 확인
      if (results.isNotEmpty) {
        print('기타 주소 형식 확인 중...');
        final firstResult = results[0];
        if (firstResult['region'] != null) {
          try {
            final region = firstResult['region'];
            final area1 = region['area1']['name']; // 시/도
            final area2 = region['area2']['name']; // 구/군
            final area3 = region['area3']['name']; // 동/읍/면

            // area4가 없을 수 있으므로 안전하게 접근
            final area4 =
                region['area4'] != null ? (region['area4']['name'] ?? '') : '';

            String fullAddress = '$area1 $area2 $area3';
            if (area4.isNotEmpty) {
              fullAddress += ' $area4';
            }

            print('최종 기타 주소: $fullAddress');
            return fullAddress;
          } catch (e) {
            print('기타 주소 파싱 오류: $e');
          }
        }
      }

      print('사용 가능한 주소 형식을 찾지 못함');
      return '주소를 찾을 수 없음';
    } catch (e) {
      print('주소 파싱 전체 오류: $e');
      return '주소 파싱 실패';
    }
  }

  // 주소 검색 기능 (키워드로 주소 찾기)
  Future<List<Map<String, dynamic>>> searchAddressByKeyword(
    String keyword,
  ) async {
    // API 키 확인
    bool keysInitialized = await _initApiKeys();
    if (!keysInitialized) {
      return [];
    }

    final url =
        'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?'
        'query=${Uri.encodeComponent(keyword)}';

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'X-NCP-APIGW-API-KEY-ID': _cachedApiKey!,
            'X-NCP-APIGW-API-KEY': _cachedSecretKey!,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['addresses'] != null && data['addresses'].isNotEmpty) {
          return List<Map<String, dynamic>>.from(data['addresses']);
        }
      }

      print('주소 검색 실패: ${response.statusCode}');
      return [];
    } catch (e) {
      print('주소 검색 오류: $e');
      return [];
    }
  }
}

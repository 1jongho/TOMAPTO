import 'package:flutter_naver_map/flutter_naver_map.dart';

class MapController {
  NaverMapController? _mapController;
  double _currentZoom = 19.0; // 기본 줌 레벨 설정

  // 맵 컨트롤러 getter
  NaverMapController? get controller => _mapController;

  // 현재 줌 레벨 getter
  double get currentZoom => _currentZoom;

  // 맵 컨트롤러 설정
  void setMapController(NaverMapController controller) {
    _mapController = controller;

    // 바로 locationOverlay를 활성화하지 않고, enableLocationTracking 메서드를 통해 설정
    // 직접적인 locationOverlay.setActive 호출 제거
  }

  // 위치 추적 모드 설정 (파란색 동그라미 표시)
  void enableLocationTracking(NLocationTrackingMode mode) {
    if (_mapController != null) {
      _mapController!.setLocationTrackingMode(mode);
    }
  }

  // 내 위치 오버레이 설정
  void configureLocationOverlay({bool isActive = true}) {
    if (_mapController != null) {
      // 위치 추적 모드를 통해 내 위치 오버레이 설정
      // 활성화하려면 위치 추적 모드를 설정하고, 비활성화하려면 none으로 설정
      _mapController!.setLocationTrackingMode(
        isActive ? NLocationTrackingMode.noFollow : NLocationTrackingMode.none,
      );
    }
  }

  // 줌 레벨 설정
  void setZoomLevel(double zoom) {
    _currentZoom = zoom;
  }

  // 카메라 이동
  Future<void> moveCamera(NLatLng target, double zoom) async {
    if (_mapController != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(target: target, zoom: zoom),
      );
      _currentZoom = zoom;
    }
  }

  // 현재 카메라 위치 가져오기
  Future<NCameraPosition?> getCurrentCameraPosition() async {
    if (_mapController != null) {
      try {
        return await _mapController!.getCameraPosition();
      } catch (e) {
        print('카메라 위치 가져오기 실패: $e');
        return null;
      }
    }
    return null;
  }

  // 거리 스케일 계산
  DistanceScale getDistanceScale(double zoom) {
    // 줌 레벨에 따라 스케일 값 계산
    double distance;
    String text;
    double width;

    if (zoom <= 5) {
      distance = 500000; // 500km
      text = '500km';
      width = 100;
    } else if (zoom <= 7) {
      distance = 200000; // 200km
      text = '200km';
      width = 80;
    } else if (zoom <= 9) {
      distance = 100000; // 100km
      text = '100km';
      width = 70;
    } else if (zoom <= 11) {
      distance = 50000; // 50km
      text = '50km';
      width = 60;
    } else if (zoom <= 13) {
      distance = 10000; // 10km
      text = '10km';
      width = 50;
    } else if (zoom <= 15) {
      distance = 1000; // 1km
      text = '1km';
      width = 40;
    } else if (zoom <= 17) {
      distance = 500; // 500m
      text = '500m';
      width = 50;
    } else if (zoom <= 18) {
      distance = 200; // 200m
      text = '200m';
      width = 40;
    } else if (zoom <= 19) {
      distance = 100; // 100m
      text = '100m';
      width = 30;
    } else {
      distance = 50; // 50m
      text = '50m';
      width = 20;
    }

    return DistanceScale(distance: distance, text: text, width: width);
  }

  // 마커 추가
  void addMarker(NMarker marker) {
    if (_mapController != null) {
      try {
        _mapController!.addOverlay(marker);
      } catch (e) {
        print('마커 추가 실패: $e');
      }
    }
  }

  // 마커 제거
  void removeMarker(NMarker marker) {
    if (_mapController != null) {
      try {
        _mapController!.deleteOverlay(marker.info);
      } catch (e) {
        print('마커 제거 실패: $e');
      }
    }
  }

  // 마커 모두 제거
  void removeAllMarkers(Set<NMarker> markers) {
    if (_mapController != null) {
      for (final marker in markers) {
        try {
          _mapController!.deleteOverlay(marker.info);
        } catch (e) {
          print('마커 제거 실패: $e');
        }
      }
    }
  }

  // 카메라 업데이트
  void updateCamera(NCameraUpdate nCameraUpdate) {
    if (_mapController != null) {
      _mapController!.updateCamera(nCameraUpdate);
    }
  }

  // 컨트롤러 해제
  void dispose() {
    _mapController = null;
  }
}

// 거리 스케일 정보를 담는 클래스
class DistanceScale {
  final double distance; // 실제 거리 (미터)
  final String text; // 표시할 텍스트
  final double width; // UI에 표시할 너비

  DistanceScale({
    required this.distance,
    required this.text,
    required this.width,
  });
}

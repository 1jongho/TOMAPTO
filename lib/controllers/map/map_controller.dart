import 'package:flutter_naver_map/flutter_naver_map.dart';

class MapController {
  NaverMapController? _mapController;
  double _currentZoom = 19.0; // 기본 줌 레벨 설정
  bool _firstLocationUpdate = true;
  double _currentBearing = 0.0; // 현재 베어링 (방향) 값

  // 맵 컨트롤러 getter
  NaverMapController? get controller => _mapController;

  // 현재 줌 레벨 getter
  double get currentZoom => _currentZoom;

  // 맵 컨트롤러 설정
  void setMapController(NaverMapController controller) {
    _mapController = controller;

    // 컨트롤러 옵션 설정
    if (_mapController != null) {
      try {
        // 위치 오버레이 표시를 위해 noFollow 모드로 설정
        _mapController!.setLocationTrackingMode(NLocationTrackingMode.noFollow);

        // 위치 오버레이 스타일 설정 (follow 모드처럼 보이게 설정)
        _configureLocationOverlay();
      } catch (e) {
        print('위치 추적 모드 설정 실패: $e');
      }
    }
  }

  // 위치 오버레이 스타일 설정
  void _configureLocationOverlay() {
    if (_mapController != null) {
      try {
        // 위치 오버레이 가져오기
        final locationOverlay = _mapController!.getLocationOverlay();

        // 원과 방향 화살표를 모두 표시 (follow 모드와 동일한 설정)
        locationOverlay.setIsVisible(true); // 위치 오버레이
        locationOverlay.setCircleRadius(0); // 원 크기 조정 (0으로 설정하면 기본값 사용)
        locationOverlay.setSubIcon(
          NLocationOverlay.defaultSubIcon,
        ); // 기본 방향 표시 아이콘 사용

        // 초기 베어링 설정 (북쪽 방향)
        locationOverlay.setBearing(_currentBearing);

        print('위치 오버레이 스타일 설정 완료');
      } catch (e) {
        print('위치 오버레이 스타일 설정 실패: $e');
      }
    }
  }

  // 위치 오버레이를 지속적으로 표시하기 위한 메서드
  void ensureLocationOverlayVisible() {
    if (_mapController != null) {
      try {
        // 위치 추적 모드를 noFollow로 설정하여 위치 오버레이는 보이되 카메라는 고정하지 않음
        _mapController!.setLocationTrackingMode(NLocationTrackingMode.noFollow);

        // 위치 오버레이 스타일 다시 설정 (방향 포함)
        final locationOverlay = _mapController!.getLocationOverlay();
        locationOverlay.setIsVisible(true);
        locationOverlay.setSubIcon(NLocationOverlay.defaultSubIcon);
        locationOverlay.setBearing(_currentBearing);
      } catch (e) {
        print('위치 오버레이 표시 실패: $e');
      }
    }
  }

  // 위치 업데이트 및 (첫 번째 업데이트일 경우에만) 카메라 이동
  Future<void> updateLocation(NLatLng position) async {
    if (_mapController == null) return;

    try {
      // 첫 위치 업데이트인 경우에만 카메라를 해당 위치로 이동
      if (_firstLocationUpdate) {
        await moveCamera(position, 17); // 초기 줌 레벨은 17
        _firstLocationUpdate = false;
      }
      // 위치 오버레이 표시 유지
      ensureLocationOverlayVisible();
    } catch (e) {
      print('위치 업데이트 실패: $e');
    }
  }

  // 방향(베어링) 업데이트
  void updateBearing(double bearing) {
    if (_mapController == null) return;

    _currentBearing = bearing;

    try {
      // 베어링 값을 0-360도 범위로 정규화
      while (_currentBearing < 0) {
        _currentBearing += 360;
      }
      while (_currentBearing >= 360) {
        _currentBearing -= 360;
      }

      // 위치 오버레이 방향 업데이트
      _mapController!.getLocationOverlay().setBearing(_currentBearing);
    } catch (e) {
      print('방향 업데이트 실패: $e');
    }
  }

  // 위치와 방향을 함께 업데이트
  Future<void> updateLocationAndBearing(
    NLatLng position,
    double bearing,
  ) async {
    if (_mapController == null) return;

    try {
      // 베어링 업데이트
      updateBearing(bearing);

      // 위치 업데이트
      await updateLocation(position);
    } catch (e) {
      print('위치 및 방향 업데이트 실패: $e');
    }
  }

  // 줌 레벨 설정
  void setZoomLevel(double zoom) {
    _currentZoom = zoom;
  }

  // 카메라 이동
  Future<void> moveCamera(NLatLng target, double zoom) async {
    if (_mapController != null) {
      // 카메라 이동
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(target: target, zoom: zoom),
      );
      _currentZoom = zoom;

      // 카메라 이동 후 위치 오버레이 표시 유지
      ensureLocationOverlayVisible();
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

      // 카메라 업데이트 후 위치 오버레이 표시 유지
      ensureLocationOverlayVisible();
    }
  }

  // 현재 위치로 이동 (위치 버튼 눌렀을 때)
  Future<void> moveToCurrentLocation(NLatLng position) async {
    if (_mapController == null) return;

    try {
      // 현재 위치로 카메라 이동
      await moveCamera(position, _currentZoom);

      // 위치 오버레이 위치 설정
      _mapController!.getLocationOverlay().setPosition(position);

      // 위치 오버레이 표시 유지 (베어링 유지)
      ensureLocationOverlayVisible();
    } catch (e) {
      print('현재 위치로 이동 실패: $e');
    }
  }

  // 컨트롤러 해제
  void dispose() {
    _mapController = null;
  }
}

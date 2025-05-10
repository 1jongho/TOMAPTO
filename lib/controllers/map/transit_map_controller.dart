// transit_map_controller.dart 수정 내용

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/map_controller.dart';

enum TransitMode { car, walk }

class TransitMapController {
  // 자동차 모드와 도보 모드를 위한 맵 컨트롤러
  final MapController _carMapController = MapController();
  final MapController _walkMapController = MapController();

  // 각 모드별 마커 세트
  final Set<NMarker> _carMarkers = {};
  final Set<NMarker> _walkMarkers = {};

  // 맵 초기화 상태 추적
  bool _isCarMapInitialized = false;
  bool _isWalkMapInitialized = false;

  // 출발지와 도착지 좌표 저장
  NLatLng? _currentPosition;
  NLatLng? _destinationPosition;

  // Getters
  MapController get carMapController => _carMapController;
  MapController get walkMapController => _walkMapController;
  Set<NMarker> get carMarkers => _carMarkers;
  Set<NMarker> get walkMarkers => _walkMarkers;
  bool get isCarMapInitialized => _isCarMapInitialized;
  bool get isWalkMapInitialized => _isWalkMapInitialized;

  // 맵 컨트롤러 초기화 상태 설정
  void setMapInitialized(TransitMode mode, bool isInitialized) {
    if (mode == TransitMode.car) {
      _isCarMapInitialized = isInitialized;
    } else {
      _isWalkMapInitialized = isInitialized;
    }
  }

  // 모드에 따른 맵 컨트롤러 반환
  MapController getControllerByMode(TransitMode mode) {
    return mode == TransitMode.car ? _carMapController : _walkMapController;
  }

  // 모드에 따른 마커 세트 반환
  Set<NMarker> getMarkersByMode(TransitMode mode) {
    return mode == TransitMode.car ? _carMarkers : _walkMarkers;
  }

  // 현재 위치(출발지) 설정
  void setCurrentPosition(NLatLng position) {
    _currentPosition = position;
  }

  // 현재 위치(출발지) 반환
  NLatLng? getCurrentPosition() {
    return _currentPosition;
  }

  // 도착지 위치 설정
  void setDestinationPosition(NLatLng? position) {
    _destinationPosition = position;
  }

  // 도착지 위치 반환
  NLatLng? getCurrentDestinationPosition() {
    return _destinationPosition;
  }

  // 모드에 따른 기본 줌 레벨 반환
  double getDefaultZoomLevel(TransitMode mode) {
    return mode == TransitMode.car ? 15.0 : 16.0; // 도보는 더 확대해서 보여줌
  }

  // 맵 카메라 이동
  Future<void> moveCamera(
    TransitMode mode,
    NLatLng target, [
    double? zoom,
  ]) async {
    final controller = getControllerByMode(mode);
    final defaultZoom = zoom ?? getDefaultZoomLevel(mode);

    if (controller.controller != null) {
      await controller.moveCamera(target, defaultZoom);
    }
  }

  // 마커 업데이트
  void updateMarkers(TransitMode mode, NLatLng position, String title) {
    final controller = getControllerByMode(mode);
    final markers = getMarkersByMode(mode);

    if (controller.controller != null) {
      // 기존 마커 제거
      if (markers.isNotEmpty) {
        controller.removeAllMarkers(markers);
        markers.clear();
      }

      // 새 마커 생성 - 캡션 없음
      final marker = NMarker(
        id: '출발지_${mode == TransitMode.car ? '자동차' : '도보'}',
        position: position,
      );

      // 모든 모드에서 동일한 색상(빨간색) 사용
      marker.setIconTintColor(Color(0xFFFB233B));

      // 마커 추가
      try {
        controller.addMarker(marker);
        markers.add(marker);
      } catch (e) {
        print('마커 추가 실패: $e');
      }
    }
  }

  // 모든 마커와 경로 제거 (새로운 메서드)
  void clearMarkersAndRoutes(TransitMode mode) {
    final controller = getControllerByMode(mode);
    final markers = getMarkersByMode(mode);

    if (controller.controller != null) {
      // 모든 마커 제거
      controller.removeAllMarkers(markers);
      markers.clear();
    }
  }

  // 모든 맵 컨트롤러의 모든 마커와 경로 제거 (새로 추가된 메서드)
  void clearAllMarkersAndRoutes() {
    // 자동차 모드 마커 및 경로 제거
    clearMarkersAndRoutes(TransitMode.car);

    // 도보 모드 마커 및 경로 제거
    clearMarkersAndRoutes(TransitMode.walk);
  }

  // 리소스 해제
  void dispose() {
    _carMapController.dispose();
    _walkMapController.dispose();
  }
}

// walk_modal.dart 수정 내용 - 마커 표시 개선

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/utils/route_renderer.dart';
import 'package:tomapto/pages/map/navigation_page.dart';

class WalkModal extends StatefulWidget {
  final NLatLng? initialPosition;
  final String originPlace;
  final String destinationPlace;
  final TransitMapController transitMapController;
  final Function(NLatLng) onLocationUpdated;

  const WalkModal({
    super.key,
    required this.initialPosition,
    required this.originPlace,
    required this.destinationPlace,
    required this.transitMapController,
    required this.onLocationUpdated,
  });

  @override
  State<WalkModal> createState() => _WalkModalState();
}

class _WalkModalState extends State<WalkModal> {
  bool _isLoading = true;
  bool _isRouteLoading = false;
  bool _hasRoute = false;
  bool _routeHasBeenSearched = false;

  int _estimatedTime = 0;
  int _totalDistance = 0;

  // 출발지/도착지 좌표 저장
  NLatLng? _destinationCoords;

  NPathOverlay? _routePathOverlay;
  NMarker? _startMarker;
  NMarker? _destinationMarker;

  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _isLoading = !widget.transitMapController.isWalkMapInitialized;
  }

  @override
  void didUpdateWidget(WalkModal oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 좌표나 주소가 변경된 경우 마커 및 경로 업데이트
    if (oldWidget.initialPosition != widget.initialPosition ||
        oldWidget.destinationPlace != widget.destinationPlace) {
      if (widget.transitMapController.isWalkMapInitialized) {
        // 기존 마커와 경로 제거
        _clearRouteAndMarkers();

        if (widget.initialPosition != null) {
          // 출발지 마커 추가 (캡션 없이)
          _addOriginMarker(widget.initialPosition!);
        }

        // 도착지가 설정된 경우에만 마커 추가 및 경로 검색
        if (widget.destinationPlace != '도착지 입력') {
          // didUpdateWidget에서는 좌표만 전달받고 경로 계산은 하지 않음
          // transit.dart에서 이미 좌표 변환이 이루어졌을 것으로 가정
          _routeHasBeenSearched = false;
          Future.delayed(Duration(milliseconds: 300), () {
            _searchAndDisplayRoute();
          });
        }
      }
    }
  }

  // 출발지 마커 추가 - 캡션 없이
  void _addOriginMarker(NLatLng position) {
    final controller = widget.transitMapController.walkMapController.controller;
    if (controller == null) return;

    // 기존 마커 제거
    if (_startMarker != null) {
      controller.deleteOverlay(_startMarker!.info);
    }

    // 새 마커 생성 (캡션 없음)
    _startMarker = NMarker(id: 'walk_origin_marker', position: position);

    // 마커 색상 설정
    _startMarker!.setIconTintColor(const Color(0xFFFB233B));

    controller.addOverlay(_startMarker!);
  }

  // 도착지 마커 추가 - 캡션 없이
  void _addDestinationMarker(NLatLng position) {
    final controller = widget.transitMapController.walkMapController.controller;
    if (controller == null) return;

    // 기존 마커 제거
    if (_destinationMarker != null) {
      controller.deleteOverlay(_destinationMarker!.info);
    }

    // 새 마커 생성 (캡션 없음)
    _destinationMarker = NMarker(
      id: 'walk_destination_marker',
      position: position,
    );

    // 마커 색상 설정
    _destinationMarker!.setIconTintColor(const Color.fromARGB(255, 90, 16, 34));

    controller.addOverlay(_destinationMarker!);
  }

  Future<void> _searchAndDisplayRoute() async {
    if (widget.initialPosition == null) {
      print('출발지 위치 정보가 없습니다.');
      return;
    }

    if (widget.destinationPlace == '도착지 입력') {
      return;
    }

    // transit.dart로부터 좌표 전달 받기
    _destinationCoords =
        widget.transitMapController.getCurrentDestinationPosition();

    // 좌표가 없으면 경로 계산 불가
    if (_destinationCoords == null) {
      print('도착지 좌표가 없습니다. 경로를 계산할 수 없습니다.');
      return;
    }

    setState(() {
      _isRouteLoading = true;
    });

    try {
      final routeData = await _routeController.searchWalkRoute(
        widget.initialPosition!,
        _destinationCoords!,
      );

      setState(() {
        _estimatedTime = routeData['duration'] ?? 0;
        _totalDistance = routeData['distance'] ?? 0;
        _hasRoute = true;
      });

      _clearRouteAndMarkers();

      final List<NLatLng> pathCoordinates = [];
      if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
        final route = routeData['routes'][0];
        if (route['path'] != null) {
          pathCoordinates.addAll(List<NLatLng>.from(route['path']));
        }
      }

      final controller =
          widget.transitMapController.walkMapController.controller;
      if (controller == null) {
        print('맵 컨트롤러가 초기화되지 않았습니다.');
        return;
      }

      if (pathCoordinates.isNotEmpty) {
        // 경로 생성 및 추가
        _routePathOverlay = RouteRenderer.createPathOverlay(
          'walk_route',
          pathCoordinates,
          color: Colors.blue,
          width: 6.0,
        );
        controller.addOverlay(_routePathOverlay!);

        // 출발지 마커 추가 (캡션 없이)
        _addOriginMarker(widget.initialPosition!);

        // 도착지 마커 추가 (캡션 없이)
        _addDestinationMarker(_destinationCoords!);

        // 경로가 모두 보이도록 카메라 이동
        final bounds = _calculateBounds(pathCoordinates);
        controller.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(64)),
        );
      }
    } catch (e) {
      print('경로 검색 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('경로를 검색하는 중 오류가 발생했습니다.')));
    } finally {
      setState(() {
        _isRouteLoading = false;
      });
    }
  }

  // 좌표 목록의 경계 계산
  NLatLngBounds _calculateBounds(List<NLatLng> coordinates) {
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    return NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );
  }

  void _clearRouteAndMarkers() {
    final controller = widget.transitMapController.walkMapController.controller;
    if (controller != null) {
      if (_routePathOverlay != null) {
        controller.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
      }

      if (_startMarker != null) {
        controller.deleteOverlay(_startMarker!.info);
        _startMarker = null;
      }

      if (_destinationMarker != null) {
        controller.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
      }

      final markers = widget.transitMapController.getMarkersByMode(
        TransitMode.walk,
      );
      for (var marker in markers) {
        controller.deleteOverlay(marker.info);
      }
      markers.clear();
    }
  }

  void _startNavigation() {
    if (!_hasRoute || _destinationCoords == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NavigationPage(
              mode: TransitMode.walk,
              origin: widget.initialPosition!,
              destination: _destinationCoords!,
              originName: widget.originPlace,
              destinationName: widget.destinationPlace,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = EdgeInsets.fromLTRB(0, 0, 0, 160.0);

    return Stack(
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target:
                  widget.initialPosition ?? NLatLng(37.5666805, 126.9784147),
              zoom: widget.transitMapController.getDefaultZoomLevel(
                TransitMode.walk,
              ),
            ),
            mapType: NMapType.basic,
            contentPadding: contentPadding,
            locationButtonEnable: true,
          ),
          onMapReady: (controller) {
            print('도보 맵 컨트롤러 준비 완료');
            setState(() {
              _isLoading = false;
              widget.transitMapController.walkMapController.setMapController(
                controller,
              );
              widget.transitMapController.setMapInitialized(
                TransitMode.walk,
                true,
              );
            });

            if (widget.initialPosition != null) {
              // 출발지 마커 추가 (캡션 없이)
              _addOriginMarker(widget.initialPosition!);

              // 카메라 이동
              controller.updateCamera(
                NCameraUpdate.withParams(
                  target: widget.initialPosition!,
                  zoom: 15,
                ),
              );

              // 도착지가 설정된 경우 경로 검색
              if (!_routeHasBeenSearched &&
                  widget.destinationPlace != '도착지 입력') {
                _routeHasBeenSearched = true;
                Future.delayed(Duration(milliseconds: 500), () {
                  _searchAndDisplayRoute();
                });
              }
            }
          },
          onCameraIdle: () {
            if (widget.transitMapController.walkMapController.controller !=
                null) {
              widget.transitMapController.walkMapController
                  .getCurrentCameraPosition()
                  .then((cameraPosition) {
                    if (cameraPosition != null) {
                      double zoom = cameraPosition.zoom;
                      widget.transitMapController.walkMapController
                          .setZoomLevel(zoom);
                    }
                  });
            }
          },
          onMapTapped: (point, latLng) {
            // 지도 터치 이벤트를 전달하지만, transit.dart에서 처리하지 않음
            widget.onLocationUpdated(latLng);
          },
        ),

        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.blue)),

        if (_isRouteLoading)
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('경로 계산 중...'),
                  ],
                ),
              ),
            ),
          ),

        if (_hasRoute)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Color(0xFFFB233B),
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.originPlace,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 5),
                    height: 20,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.destinationPlace,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          RouteRenderer.getArrivalTime(_estimatedTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  '예상 시간',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDuration(_estimatedTime),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                const Text(
                                  '총 거리',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  RouteRenderer.formatDistance(_totalDistance),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '안내 시작',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

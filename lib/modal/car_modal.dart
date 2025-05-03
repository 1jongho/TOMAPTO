// car_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/utils/route_renderer.dart';
import 'package:tomapto/pages/map/navigation_page.dart';

class CarModal extends StatefulWidget {
  final NLatLng? initialPosition;
  final String originPlace;
  final String destinationPlace;
  final TransitMapController transitMapController;
  final Function(NLatLng) onLocationUpdated;

  const CarModal({
    super.key,
    required this.initialPosition,
    required this.originPlace,
    required this.destinationPlace,
    required this.transitMapController,
    required this.onLocationUpdated,
  });

  @override
  State<CarModal> createState() => _CarModalState();
}

class _CarModalState extends State<CarModal> {
  bool _isLoading = true;
  bool _isRouteLoading = false;
  bool _hasRoute = false;
  bool _routeHasBeenSearched = false;

  int _estimatedTime = 0;
  int _totalDistance = 0;
  int _tollFee = 0;
  final NLatLng _fixedDestination = NLatLng(37.2978858, 127.0692787);

  final String _fixedDestinationName = '안양시 동안구';

  NPathOverlay? _routePathOverlay;
  NMarker? _startMarker;
  NMarker? _destinationMarker;

  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _isLoading = !widget.transitMapController.isCarMapInitialized;

    _routeController.testApiConnection().then((_) {
      print('API 키 테스트 완료');
    });
  }

  Future<void> _searchAndDisplayRoute() async {
    if (widget.initialPosition == null) {
      print('출발지 위치 정보가 없습니다.');
      return;
    }

    setState(() {
      _isRouteLoading = true;
    });

    try {
      final routeData = await _routeController.searchCarRoute(
        widget.initialPosition!,
        _fixedDestination,
      );

      setState(() {
        _estimatedTime = routeData['duration'] ?? 0;
        _totalDistance = routeData['distance'] ?? 0;
        _tollFee = routeData['toll'] ?? 0;
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
          widget.transitMapController.carMapController.controller;
      if (controller == null) {
        print('맵 컨트롤러가 초기화되지 않았습니다.');
        return;
      }

      final markers = widget.transitMapController.getMarkersByMode(
        TransitMode.car,
      );
      for (var marker in markers) {
        controller.deleteOverlay(marker.info);
      }
      markers.clear();

      if (pathCoordinates.isNotEmpty) {
        _routePathOverlay = RouteRenderer.createPathOverlay(
          'car_route',
          pathCoordinates,
          color: Color(0xFFFB233B),
          width: 6.0,
        );

        _destinationMarker = RouteRenderer.createDestinationMarker(
          _fixedDestination,
          title: '도착',
          animated: true,
        );

        widget.transitMapController.updateMarkers(
          TransitMode.car,
          widget.initialPosition!,
          '출발',
        );

        controller.addOverlay(_routePathOverlay!);
        controller.addOverlay(_destinationMarker!);

        final minLat = pathCoordinates
            .map((p) => p.latitude)
            .reduce((a, b) => a < b ? a : b);
        final minLng = pathCoordinates
            .map((p) => p.longitude)
            .reduce((a, b) => a < b ? a : b);
        final maxLat = pathCoordinates
            .map((p) => p.latitude)
            .reduce((a, b) => a > b ? a : b);
        final maxLng = pathCoordinates
            .map((p) => p.longitude)
            .reduce((a, b) => a > b ? a : b);

        final bounds = NLatLngBounds(
          southWest: NLatLng(minLat, minLng),
          northEast: NLatLng(maxLat, maxLng),
        );

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

  void _clearRouteAndMarkers() {
    final controller = widget.transitMapController.carMapController.controller;
    if (controller != null) {
      if (_routePathOverlay != null) {
        controller.deleteOverlay(_routePathOverlay!.info);
        _routePathOverlay = null;
      }

      if (_destinationMarker != null) {
        controller.deleteOverlay(_destinationMarker!.info);
        _destinationMarker = null;
      }

      final markers = widget.transitMapController.getMarkersByMode(
        TransitMode.car,
      );
      for (var marker in markers) {
        controller.deleteOverlay(marker.info);
      }
      markers.clear();
    }
  }

  void _startNavigation() {
    if (!_hasRoute) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NavigationPage(
              mode: TransitMode.car,
              origin: widget.initialPosition!,
              destination: _fixedDestination,
              originName: widget.originPlace,
              destinationName: _fixedDestinationName,
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
                TransitMode.car,
              ),
            ),
            mapType: NMapType.basic,
            contentPadding: contentPadding,
            locationButtonEnable: true,
          ),
          onMapReady: (controller) {
            print('자동차 맵 컨트롤러 준비 완료');
            setState(() {
              _isLoading = false;
              widget.transitMapController.carMapController.setMapController(
                controller,
              );
              widget.transitMapController.setMapInitialized(
                TransitMode.car,
                true,
              );
            });

            if (widget.initialPosition != null) {
              widget.transitMapController.updateMarkers(
                TransitMode.car,
                widget.initialPosition!,
                widget.originPlace,
              );

              widget.transitMapController.moveCamera(
                TransitMode.car,
                widget.initialPosition!,
                widget.transitMapController.getDefaultZoomLevel(
                  TransitMode.car,
                ),
              );

              if (!_routeHasBeenSearched) {
                _routeHasBeenSearched = true;
                Future.delayed(Duration(milliseconds: 500), () {
                  _searchAndDisplayRoute();
                });
              }
            }
          },
          onCameraIdle: () {
            if (widget.transitMapController.carMapController.controller !=
                null) {
              widget.transitMapController.carMapController
                  .getCurrentCameraPosition()
                  .then((cameraPosition) {
                    if (cameraPosition != null) {
                      double zoom = cameraPosition.zoom;
                      widget.transitMapController.carMapController.setZoomLevel(
                        zoom,
                      );
                      print('자동차 탭 줌 레벨 업데이트됨: $zoom');
                    }
                  });
            }
          },
          onMapTapped: (point, latLng) {
            print('자동차 지도가 탭되었습니다: $latLng');
          },
        ),

        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFFB233B)),
          ),

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
                        color: Color(0xFFFB233B),
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
                          _fixedDestinationName,
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
                            color: Color(0xFFFB233B),
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

                        if (_tollFee > 0) ...[
                          const SizedBox(height: 12),
                          Text(
                            '통행료: ${RouteRenderer.formatFare(_tollFee)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFB233B),
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

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:tomapto/controllers/map/location_controller.dart';
import 'package:tomapto/controllers/map/address_controller.dart';
import 'package:tomapto/controllers/map/transit_map_controller.dart';
import 'package:tomapto/controllers/map/route_controller.dart';
import 'package:tomapto/widgets/search_bar_widget.dart';
import 'package:tomapto/widgets/transit_option_widget.dart';
import 'package:tomapto/modal/car_modal.dart';
import 'package:tomapto/modal/walk_modal.dart';

class TransitApp extends StatefulWidget {
  const TransitApp({super.key});

  @override
  State<TransitApp> createState() => _TransitAppState();
}

class _TransitAppState extends State<TransitApp> {
  int _selectedIndex = 0;

  String _originPlace = '위치 확인 중...';
  String _destinationPlace = '도착지 입력';

  final LocationController _locationController = LocationController();
  final AddressController _addressController = AddressController();
  final TransitMapController _transitMapController = TransitMapController();
  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _transitMapController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final hasPermission = await _locationController.checkLocationPermission(
      context,
    );
    if (!hasPermission) {
      setState(() {
        _originPlace = '위치 권한 없음';
      });
      return;
    }

    // 현재 위치 가져오기
    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      _transitMapController.setCurrentPosition(position);
      final address = await _addressController.getAddressFromLatLng(position);
      setState(() {
        _originPlace = address;
      });
      if (_transitMapController.isCarMapInitialized) {
        _transitMapController.moveCamera(
          TransitMode.car,
          position,
          _transitMapController.getDefaultZoomLevel(TransitMode.car),
        );
        _transitMapController.updateMarkers(
          TransitMode.car,
          position,
          _originPlace,
        );
      }

      if (_transitMapController.isWalkMapInitialized) {
        _transitMapController.moveCamera(
          TransitMode.walk,
          position,
          _transitMapController.getDefaultZoomLevel(TransitMode.walk),
        );
        _transitMapController.updateMarkers(
          TransitMode.walk,
          position,
          _originPlace,
        );
      }
    } else {
      setState(() {
        _originPlace = '위치 확인 실패';
      });
    }
  }

  void _handleNavIndexChanged(int index) {
    final isSameTab = _selectedIndex == index;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      if (_transitMapController.isCarMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.car,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.car),
          );

          if (isSameTab) {
            _refreshCurrentLocation(TransitMode.car);
          }
        }
      }
    } else if (index == 1) {
      if (_transitMapController.isWalkMapInitialized) {
        final position = _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.walk,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.walk),
          );

          if (isSameTab) {
            _refreshCurrentLocation(TransitMode.walk);
          }
        }
      }
    }

    print('네비게이션 탭 변경: $index, 같은 탭 다시 선택: $isSameTab');
  }

  void _refreshCurrentLocation(TransitMode mode) async {
    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      _transitMapController.setCurrentPosition(position);

      _transitMapController.moveCamera(
        mode,
        position,
        _transitMapController.getDefaultZoomLevel(mode),
      );

      _transitMapController.updateMarkers(mode, position, _originPlace);

      final address = await _addressController.getAddressFromLatLng(position);
      setState(() {
        _originPlace = address;
      });

      _routeController.invalidateCache();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 위치를 가져오는 데 실패했습니다.')));
    }
  }

  void _handleOriginChanged(String value) {
    setState(() {
      _originPlace = value;
    });
    _routeController.invalidateCache();
  }

  void _handleDestinationChanged(String value) {
    setState(() {
      _destinationPlace = value;
    });
    _routeController.invalidateCache();
  }

  void _handleSwapLocations() {
    setState(() {
      final temp = _originPlace;
      _originPlace = _destinationPlace;
      _destinationPlace = temp;
    });
    _routeController.invalidateCache();
  }

  void _handleLocationUpdated(NLatLng latLng) async {
    final address = await _addressController.getAddressFromLatLng(latLng);
    setState(() {
      _originPlace = address;
    });
    _routeController.invalidateCache();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final bool isSmallScreen = width < 360;
    final double iconSize = isSmallScreen ? 22.0 : 28.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SearchBarWidget(
            originPlace: _originPlace,
            destinationPlace: _destinationPlace,
            onOriginChanged: _handleOriginChanged,
            onDestinationChanged: _handleDestinationChanged,
            onSwapLocations: _handleSwapLocations,
            onClosePressed: () {
              Navigator.pop(context);
              print('이전 화면으로 돌아가기');
            },
          ),

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
                // 자동차 탭
                TransitOptionWidget(
                  index: 0,
                  selectedIndex: _selectedIndex,
                  icon: Icons.directions_car,
                  label: '자동차',
                  onTap: _handleNavIndexChanged,
                  iconSize: iconSize,
                ),

                // 도보 탭
                TransitOptionWidget(
                  index: 1,
                  selectedIndex: _selectedIndex,
                  icon: Icons.directions_walk,
                  label: '도보',
                  onTap: _handleNavIndexChanged,
                  iconSize: iconSize,
                ),
              ],
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                CarModal(
                  initialPosition: _transitMapController.getCurrentPosition(),
                  originPlace: _originPlace,
                  destinationPlace: _destinationPlace,
                  transitMapController: _transitMapController,
                  onLocationUpdated: _handleLocationUpdated,
                ),

                WalkModal(
                  initialPosition: _transitMapController.getCurrentPosition(),
                  originPlace: _originPlace,
                  destinationPlace: _destinationPlace,
                  transitMapController: _transitMapController,
                  onLocationUpdated: _handleLocationUpdated,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

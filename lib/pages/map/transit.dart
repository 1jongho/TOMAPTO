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
import 'package:tomapto/pages/map/naver_map.dart';

class TransitApp extends StatefulWidget {
  // 초기 출발지/도착지 설정을 위한 추가 속성
  final String? initialOriginPlace;
  final String? initialDestinationPlace;

  const TransitApp({
    super.key,
    this.initialOriginPlace,
    this.initialDestinationPlace,
  });

  @override
  State<TransitApp> createState() => _TransitAppState();
}

class _TransitAppState extends State<TransitApp> {
  int _selectedIndex = 0;

  String _originPlace = '위치 확인 중...';
  String _destinationPlace = '도착지 입력';

  // 출발지와 도착지의 좌표 저장
  NLatLng? _originCoords;
  NLatLng? _destinationCoords;

  final LocationController _locationController = LocationController();
  final AddressController _addressController = AddressController();
  final TransitMapController _transitMapController = TransitMapController();
  final RouteController _routeController = RouteController();

  @override
  void initState() {
    super.initState();
    _transitMapController.clearAllMarkersAndRoutes(); // 모든 마커 초기화
    _initializeLocation();

    // 초기 출발지/도착지 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialPlaces();
    });
  }

  // 초기 출발지/도착지 설정 메서드
  void _applyInitialPlaces() async {
    if (widget.initialOriginPlace != null) {
      setState(() {
        _originPlace = widget.initialOriginPlace!;
      });
      _routeController.invalidateCache();

      // 출발지 주소를 좌표로 변환
      await _getOriginCoordinates();
    }

    if (widget.initialDestinationPlace != null &&
        widget.initialDestinationPlace != '도착지 입력') {
      setState(() {
        _destinationPlace = widget.initialDestinationPlace!;
      });
      _routeController.invalidateCache();

      // 도착지 주소를 좌표로 변환
      await _getDestinationCoordinates();
    }
  }

  // 출발지 주소를 좌표로 변환하는 메서드
  Future<void> _getOriginCoordinates() async {
    if (_originPlace == '위치 확인 중...' ||
        _originPlace == '위치 권한 없음' ||
        _originPlace == '위치 확인 실패') {
      return;
    }

    try {
      print('출발지 주소 검색: $_originPlace');
      final results = await _addressController.searchAddressByKeyword(
        _originPlace,
      );
      if (results.isNotEmpty) {
        // 첫 번째 결과 사용
        final firstResult = results[0];
        if (firstResult['x'] != null && firstResult['y'] != null) {
          // mapx, mapy 좌표를 위경도로 변환
          final coords = _addressController.convertMapCoordinatesToLatLng(
            firstResult['x'],
            firstResult['y'],
          );

          setState(() {
            _originCoords = coords;
          });

          print('출발지 좌표 설정 완료: $_originCoords');

          // 현재 위치 업데이트 (TransitMapController에 좌표 설정)
          _transitMapController.setCurrentPosition(_originCoords!);
        }
      }
    } catch (e) {
      print('출발지 좌표 변환 오류: $e');
    }
  }

  // 도착지 주소를 좌표로 변환하는 메서드
  Future<void> _getDestinationCoordinates() async {
    if (_destinationPlace == '도착지 입력') {
      setState(() {
        _destinationCoords = null; // 도착지가 기본값이면 좌표 초기화
      });

      // TransitMapController에도 null 설정
      _transitMapController.setDestinationPosition(null);
      return;
    }

    try {
      print('도착지 주소 검색: $_destinationPlace');
      final results = await _addressController.searchAddressByKeyword(
        _destinationPlace,
      );
      if (results.isNotEmpty) {
        // 첫 번째 결과 사용
        final firstResult = results[0];
        if (firstResult['x'] != null && firstResult['y'] != null) {
          // mapx, mapy 좌표를 위경도로 변환
          final coords = _addressController.convertMapCoordinatesToLatLng(
            firstResult['x'],
            firstResult['y'],
          );

          setState(() {
            _destinationCoords = coords;
          });

          print('도착지 좌표 설정 완료: $_destinationCoords');

          // TransitMapController에 도착지 좌표 설정
          _transitMapController.setDestinationPosition(_destinationCoords!);
        }
      }
    } catch (e) {
      print('도착지 좌표 변환 오류: $e');
    }
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
      setState(() {
        _originCoords = position;
      });
      _transitMapController.setCurrentPosition(position);

      // 초기 출발지가 설정되지 않은 경우에만 현재 위치를 출발지로 설정
      if (widget.initialOriginPlace == null) {
        final address = await _addressController.getAddressFromLatLng(position);
        setState(() {
          _originPlace = address;
        });
      }
    } else {
      // 현재 위치를 가져올 수 없는 경우에도 초기 출발지 설정
      if (widget.initialOriginPlace == null) {
        setState(() {
          _originPlace = '위치 확인 실패';
        });
      }
    }
  }

  void _handleNavIndexChanged(int index) {
    final isSameTab = _selectedIndex == index;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      if (_transitMapController.isCarMapInitialized) {
        final position =
            _originCoords ?? _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.car,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.car),
          );

          if (isSameTab) {
            // 같은 탭을 다시 누른 경우 현재 위치 새로고침하지 않음
            // _refreshCurrentLocation(TransitMode.car); // 이 줄을 주석 처리
          }
        }
      }
    } else if (index == 1) {
      if (_transitMapController.isWalkMapInitialized) {
        final position =
            _originCoords ?? _transitMapController.getCurrentPosition();
        if (position != null) {
          _transitMapController.moveCamera(
            TransitMode.walk,
            position,
            _transitMapController.getDefaultZoomLevel(TransitMode.walk),
          );

          if (isSameTab) {
            // 같은 탭을 다시 누른 경우 현재 위치 새로고침하지 않음
            // _refreshCurrentLocation(TransitMode.walk); // 이 줄을 주석 처리
          }
        }
      }
    }

    print('네비게이션 탭 변경: $index, 같은 탭 다시 선택: $isSameTab');
  }

  void _refreshCurrentLocation(TransitMode mode) async {
    final position = await _locationController.getCurrentLocation();
    if (position != null) {
      setState(() {
        _originCoords = position;
      });
      _transitMapController.setCurrentPosition(position);

      _transitMapController.moveCamera(
        mode,
        position,
        _transitMapController.getDefaultZoomLevel(mode),
      );

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

  void _handleOriginChanged(String value) async {
    _transitMapController.clearAllMarkersAndRoutes(); // 모든 마커 초기화
    setState(() {
      _originPlace = value;
    });
    _routeController.invalidateCache();

    // 출발지 주소를 좌표로 변환
    await _getOriginCoordinates();

    // setState를 한 번 더 호출하여 모달 컴포넌트가 새로운 좌표를 받을 수 있도록 함
    setState(() {});
  }

  void _handleDestinationChanged(String value) async {
    _transitMapController.clearAllMarkersAndRoutes(); // 모든 마커 초기화
    setState(() {
      _destinationPlace = value;
    });
    _routeController.invalidateCache();

    // 도착지 주소를 좌표로 변환
    await _getDestinationCoordinates();

    // setState를 한 번 더 호출하여 모달 컴포넌트가 새로운 좌표를 받을 수 있도록 함
    setState(() {});
  }

  void _handleSwapLocations() async {
    _transitMapController.clearAllMarkersAndRoutes(); // 모든 마커 초기화
    final tempPlace = _originPlace;
    final tempCoords = _originCoords;

    setState(() {
      _originPlace = _destinationPlace;
      _originCoords = _destinationCoords;

      _destinationPlace = tempPlace;
      _destinationCoords = tempCoords;
    });

    _routeController.invalidateCache();

    // TransitMapController에 새 위치 설정
    if (_originCoords != null) {
      _transitMapController.setCurrentPosition(_originCoords!);
    }
    _transitMapController.setDestinationPosition(_destinationCoords);

    // setState를 한 번 더 호출하여 모달 컴포넌트가 새로운 좌표를 받을 수 있도록 함
    setState(() {});
  }

  // 지도 터치 핸들러 - 이제 아무 작업도 수행하지 않음
  void _handleLocationUpdated(NLatLng latLng) {
    // 지도 터치시 아무런 작업도 수행하지 않음
    // 출발지와 도착지는 검색을 통해서만 설정 가능
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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const NaverMapPage()),
                (route) => false, // 모든 이전 경로를 제거
              );
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
                  initialPosition: _originCoords,
                  originPlace: _originPlace,
                  destinationPlace: _destinationPlace,
                  transitMapController: _transitMapController,
                  onLocationUpdated: _handleLocationUpdated,
                ),

                WalkModal(
                  initialPosition: _originCoords,
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

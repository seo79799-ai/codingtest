import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단순 위치 확인 (지도 포함)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // 상태 변수
  String _selectedDevice = 'computer';
  String _address = '결과 대기 중...';
  String _zipcode = '결과 대기 중...';
  bool _isLoading = false;

  GoogleMapController? _mapController;
  LatLng _currentLatLng = const LatLng(37.5665, 126.9780); // 서울 시청
  Set<Marker> _markers = {};

  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  @override
  void initState() {
    super.initState();
    _markers.add(
      Marker(
        markerId: const MarkerId('selected'),
        position: _currentLatLng,
        draggable: true,
        onDragEnd: (newPosition) {
          _currentLatLng = newPosition;
        },
      ),
    );
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _currentLatLng = latLng;
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: latLng,
        ),
      };
    });
  }

  Future<void> _handleButtonClick() async {
    // 1. 현재 위치 버튼을 눌렀을 때, 사용자가 지도를 직접 클릭하지 않았다면 현재 GPS 수집
    if (_markers.isEmpty || _markers.first.position == const LatLng(37.5665, 126.9780)) {
       await _getCurrentGPSLocation();
    }

    // 2. 최종 결정된 좌표(_currentLatLng)로 주소 변환 수행
    await _reverseGeocode(_currentLatLng.latitude, _currentLatLng.longitude);
  }

  Future<void> _getCurrentGPSLocation() async {
    setState(() { _isLoading = true; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition();
      LatLng newLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = newLatLng;
        _markers = { Marker(markerId: const MarkerId('selected'), position: newLatLng) };
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));
    } catch (e) {
      print(e);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() {
      _address = '주소 변환 중...';
      _zipcode = '...';
    });

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        final formattedAddress = results[0]['formatted_address'];

        String postalCode = '정보 없음';
        final addressComponents = results[0]['address_components'] as List;
        for (var component in addressComponents) {
          final types = component['types'] as List;
          if (types.contains('postal_code')) {
            postalCode = component['long_name'];
            break;
          }
        }

        setState(() {
          _address = formattedAddress;
          _zipcode = postalCode;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 상단 UI 영역
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Radio<String>(
                        value: 'computer',
                        groupValue: _selectedDevice,
                        onChanged: (v) => setState(() => _selectedDevice = v!),
                      ),
                      const Text('컴퓨터 위치'),
                      const SizedBox(width: 20),
                      Radio<String>(
                        value: 'mobile',
                        groupValue: _selectedDevice,
                        onChanged: (v) => setState(() => _selectedDevice = v!),
                      ),
                      const Text('휴대폰 위치'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleButtonClick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('현재 위치 확인할까요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(child: Text('도로명 주소: $_address', style: const TextStyle(fontSize: 13))),
                      Text('우편번호: $_zipcode', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            // 하단 지도 영역
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentLatLng, zoom: 15),
                onMapCreated: (controller) => _mapController = controller,
                markers: _markers,
                onTap: _onMapTap,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
